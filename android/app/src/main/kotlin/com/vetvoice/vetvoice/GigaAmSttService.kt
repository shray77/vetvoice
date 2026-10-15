package com.vetvoice.vetvoice

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.OrtSession.SessionOptions
import android.content.Context
import android.content.SharedPreferences
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

/**
 * GigaAmSttService — офлайн-распознавание речи движком GigaAM-v3-CTC (Сбер, MIT)
 * через ONNX Runtime Mobile. v1.20.0.
 *
 * Архитектура: Vosk остаётся wake word (стриминг), GigaAM — качественная
 * транскрипция ВЫСКАЗЫВАНИЯ после wake word или кнопки микрофона
 * (GigaAM — офлайн-модель батч-типа, не стриминговая).
 *
 * Пайплайн: AudioRecord 16к моно PCM16 → float32 → frontend.onnx (LogMel 64, hop 160,
 * win/n_fft 320, center=false) → model.onnx (Conformer 211M, int8-динамическая
 * квантизация MatMul/Gemm) → log_probs (T',34) → жадный CTC-декод (33 символа + blank).
 *
 * Модель качается из GitHub Releases (зеркало-паттерн v1.16.3): Range-докачка,
 * SHA-256 верификация, tempZip переживает попытки.
 */
class GigaAmSttService(private val context: Context) {

    companion object {
        private const val TAG = "GigaAmStt"

        // ===== КОНФИГУРАЦИЯ (менять тут при обновлении модели) =====
        // zip собран скриптом scripts/gigaam_package.py: model.onnx (int8),
        // frontend.onnx (fp32), labels.txt (33 строки), version.txt.
        private val MODEL_URLS = listOf(
            "https://github.com/shray77/vetvoice/releases/download/gigaam-v3-ctc-int8/gigaam-v3-ctc-int8.zip",
        )
        private const val MODEL_VERSION = "v3-ctc-int8-1"
        private const val EXPECTED_MODEL_SHA256 =
            "84f3f69bc68e19e6a8425bc82ddb7e15871bdf35559a43b721827009539942de"
        private const val FALLBACK_TOTAL_MB = 216.0
        // ===== /КОНФИГУРАЦИЯ =====

        private const val MODEL_VERSION_KEY = "gigaam_model_version"
        private const val MODEL_DIR_NAME = "gigaam-model"
        private const val SAMPLE_RATE = 16000
        private const val N_FFT = 320
        private const val HOP = 160
        private const val WIN = 320
        private const val N_MELS = 64
        private const val CHANNELS = 1 // словарь: 33 символа + blank(33) = 34 класса
        private const val CHANNELS_ACC = 34

        // Запись/эндпоинтинг
        private const val CHUNK_MS = 100L
        private const val MAX_RECORD_MS = 15000L
        private const val SILENCE_STOP_MS = 1300L
        private const val MIN_SPEECH_MS = 350L
        private const val RMS_SPEECH_THRESHOLD = 550.0

        // Скачивание (паттерн v1.16.3)
        private const val DOWNLOAD_ATTEMPTS_PER_URL = 3
        private const val DOWNLOAD_CONNECT_TIMEOUT_MS = 20000
        private const val DOWNLOAD_READ_TIMEOUT_MS = 180000
    }

    enum class State { IDLE, LOADING, READY, RECORDING, RECOGNIZING, ERROR }

    var onStateChanged: ((State, String) -> Unit)? = null
    var onResult: ((String) -> Unit)? = null
    var onPartialResult: ((String) -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    var onDownloadProgress: ((downloadedMB: Double, totalMB: Double) -> Unit)? = null

    private var state: State = State.IDLE
    private var frontendSession: OrtSession? = null
    private var encoderSession: OrtSession? = null
    private val ortEnv: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }
    private var labels: List<String> = emptyList()

    private val prefs: SharedPreferences =
        context.getSharedPreferences("gigaam_stt", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())
    private var downloadJob: Job? = null
    private var recordJob: Job? = null

    @Volatile
    private var stopRequested = false

    // ===== Состояние =====

    fun getState(): State = state

    private fun setState(newState: State, message: String = "") {
        state = newState
        mainHandler.post { onStateChanged?.invoke(newState, message) }
    }

    private fun reportError(message: String) {
        Log.e(TAG, message)
        setState(State.ERROR, message)
        mainHandler.post { onError?.invoke(message) }
    }

    /** Модель скачана и версия совпадает (без загрузки в память). */
    fun isModelDownloaded(): Boolean {
        val dir = File(context.filesDir, MODEL_DIR_NAME)
        return prefs.getString(MODEL_VERSION_KEY, null) == MODEL_VERSION &&
            File(dir, "model.onnx").isFile &&
            File(dir, "frontend.onnx").isFile &&
            File(dir, "labels.txt").isFile
    }

    // ===== Инициализация / скачивание =====

    /**
     * Не блокирующий запуск подготовки: если модель на месте — грузим сессии,
     * если нет — качаем. Готовность/ошибки приходят через onStateChanged.
     * v1.16.2-урок: НЕ ретраим наверху, НЕ отменяем идущее скачивание повторным вызовом.
     */
    fun initialize() {
        if (state == State.LOADING || state == State.RECORDING || state == State.RECOGNIZING) {
            Log.d(TAG, "initialize: already busy (${state.name}), ignore")
            return
        }
        if (isModelDownloaded() && frontendSession != null) {
            setState(State.READY)
            return
        }
        if (isModelDownloaded()) {
            setState(State.LOADING, "Подготовка модели")
            scope.launch {
                if (loadSessions()) setState(State.READY)
                // reportError внутри loadSessions выставит ERROR
            }
            return
        }
        startDownload()
    }

    private fun startDownload() {
        if (downloadJob?.isActive == true) {
            Log.d(TAG, "Download already running, ignore")
            return
        }
        setState(State.LOADING, "Скачивание модели")
        downloadJob = scope.launch {
            try {
                val dir = File(context.filesDir, MODEL_DIR_NAME)
                dir.mkdirs()
                val tempZip = File(context.filesDir, "gigaam-model.zip.tmp")
                downloadWithResume(tempZip)
                verifySha256(tempZip)
                setState(State.LOADING, "Распаковка модели")
                unzipStrip(tempZip, dir)
                if (!File(dir, "model.onnx").isFile ||
                    !File(dir, "frontend.onnx").isFile ||
                    !File(dir, "labels.txt").isFile
                ) {
                    throw IOException("После распаковки не хватает файлов модели")
                }
                tempZip.delete()
                prefs.edit().putString(MODEL_VERSION_KEY, MODEL_VERSION).apply()
                if (loadSessions()) {
                    setState(State.READY)
                }
            } catch (e: CancellationException) {
                Log.w(TAG, "Download cancelled")
            } catch (t: Throwable) {
                reportError("Ошибка загрузки модели GigaAM: ${t.message ?: t.javaClass.simpleName}")
            }
        }
    }

    /** Скачивание с Range-докачкой (206→append, 416→готово, 200→с нуля). Паттерн v1.16.3. */
    private fun downloadWithResume(dest: File) {
        var lastError: Exception? = null
        for (url in MODEL_URLS) {
            for (attempt in 1..DOWNLOAD_ATTEMPTS_PER_URL) {
                try {
                    val totalBytes = downloadSingleAttempt(url, dest)
                    if (totalBytes > 0) {
                        Log.i(TAG, "Downloaded ${dest.length()} / $totalBytes bytes")
                        return
                    }
                    throw IOException("Пустой ответ сервера")
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    lastError = e
                    Log.w(TAG, "Download attempt $attempt/$DOWNLOAD_ATTEMPTS_PER_URL failed: ${e.message}")
                    Thread.sleep(2000L * attempt)
                }
            }
        }
        throw lastError ?: IOException("Скачивание не удалось")
    }

    private fun downloadSingleAttempt(urlStr: String, dest: File): Long {
        val have = if (dest.exists()) dest.length() else 0L
        val conn = URL(urlStr).openConnection() as HttpURLConnection
        conn.connectTimeout = DOWNLOAD_CONNECT_TIMEOUT_MS
        conn.readTimeout = DOWNLOAD_READ_TIMEOUT_MS
        conn.instanceFollowRedirects = true
        if (have > 0) conn.setRequestProperty("Range", "bytes=$have-")
        conn.connect()

        val code = conn.responseCode
        val append: Boolean
        val start: Long
        val total: Long
        when {
            code == 206 -> { append = true; start = have; total = have + conn.contentLengthLong }
            code == 200 -> { append = false; start = 0; total = conn.contentLengthLong; dest.delete() }
            code == 416 && have > 0 -> {
                // файл уже докачан полностью — размер проверит SHA-256
                conn.disconnect()
                return have
            }
            else -> throw IOException("HTTP $code при скачивании модели")
        }
        Log.i(TAG, "Downloading: have=$have, code=$code, total=$total")

        conn.inputStream.use { input ->
            BufferedOutputStream(FileOutputStream(dest, append)).use { output ->
                val buf = ByteArray(256 * 1024)
                var downloaded = start
                var lastProgressAt = 0L
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    output.write(buf, 0, n)
                    downloaded += n
                    val now = System.currentTimeMillis()
                    if (now - lastProgressAt > 400) {
                        lastProgressAt = now
                        val totalMb = if (total > 0) total / 1048576.0 else FALLBACK_TOTAL_MB
                        val downloadedMb = downloaded / 1048576.0
                        mainHandler.post { onDownloadProgress?.invoke(downloadedMb, totalMb) }
                    }
                }
                output.flush()
            }
        }
        conn.disconnect()
        return total
    }

    private fun verifySha256(file: File) {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { fis ->
            val buf = ByteArray(256 * 1024)
            while (true) {
                val n = fis.read(buf)
                if (n < 0) break
                md.update(buf, 0, n)
            }
        }
        val hex = md.digest().joinToString("") { "%02x".format(it) }
        if (!hex.equals(EXPECTED_MODEL_SHA256, ignoreCase = true)) {
            file.delete()
            throw IOException("SHA-256 модели не совпал (файл удалён, будет скачан заново)")
        }
        Log.i(TAG, "SHA-256 OK")
    }

    /** Распаковка: файлы лежат в корне zip (без внутренней папки) — кладём прямо в dir. */
    private fun unzipStrip(zipFile: File, targetDir: File) {
        targetDir.mkdirs()
        ZipInputStream(zipFile.inputStream().buffered()).use { zis ->
            var entry: ZipEntry? = zis.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    val outFile = File(targetDir, File(entry.name).name)
                    FileOutputStream(outFile).use { fos -> zis.copyTo(fos) }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
    }

    // ===== ORT-сессии =====

    private fun loadSessions(): Boolean {
        try {
            val dir = File(context.filesDir, MODEL_DIR_NAME)
            labels = File(dir, "labels.txt").readLines().filter { it.isNotEmpty() }
            if (labels.size != CHANNELS) {
                throw IOException("labels.txt: ожидалось $CHANNELS меток, получено ${labels.size}")
            }
            val opts = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(4)
                setInterOpNumThreads(1)
            }
            frontendSession?.close()
            encoderSession?.close()
            frontendSession = ortEnv.createSession(File(dir, "frontend.onnx").absolutePath, opts)
            encoderSession = ortEnv.createSession(File(dir, "model.onnx").absolutePath, opts)
            Log.i(TAG, "ORT sessions loaded (labels=${labels.size})")
            return true
        } catch (t: Throwable) {
            reportError("Не удалось загрузить модель GigaAM: ${t.message ?: t.javaClass.simpleName}")
            return false
        }
    }

    fun dispose() {
        stopRequested = true
        recordJob?.cancel()
        downloadJob?.cancel()
        scope.cancel()
        try {
            frontendSession?.close()
            encoderSession?.close()
        } catch (t: Throwable) {
            Log.w(TAG, "ORT dispose: ${t.message}")
        }
        frontendSession = null
        encoderSession = null
        setState(State.IDLE)
    }

    // ===== Транскрипция =====

    /** Ручная остановка записи (кнопка). */
    fun stopTranscribe() {
        stopRequested = true
    }

    /**
     * Записать высказывание (VAD-эндпоинтинг) и распознать.
     * Вызывать ТОЛЬКО когда Vosk/другой STT освободил микрофон.
     * Результат — через onResult (или onError).
     */
    fun startTranscribe() {
        if (state == State.RECORDING || state == State.RECOGNIZING) {
            Log.d(TAG, "startTranscribe: already active")
            return
        }
        if (frontendSession == null || encoderSession == null) {
            // модель ещё не готова — запускаем подготовку, результат не придёт
            initialize()
            mainHandler.post {
                onError?.invoke("Модель GigaAM ещё не готова — подождите загрузки")
            }
            return
        }
        stopRequested = false
        recordJob = scope.launch {
            try {
                val pcm = withContext(Dispatchers.IO) { recordUtterance() }
                if (pcm == null || stopRequested) {
                    setState(State.READY)
                    return@launch
                }
                if (pcm.size < SAMPLE_RATE / 5) { // < 200 мс — пустая запись
                    setState(State.READY)
                    mainHandler.post { onError?.invoke("Речь не услышана") }
                    return@launch
                }
                setState(State.RECOGNIZING, "Распознаю")
                val text = withContext(Dispatchers.Default) { infer(pcm) }
                setState(State.READY)
                if (text.isNotBlank()) {
                    mainHandler.post { onResult?.invoke(text.trim()) }
                } else {
                    mainHandler.post { onError?.invoke("Не удалось распознать речь") }
                }
            } catch (e: CancellationException) {
                Log.w(TAG, "Transcribe cancelled")
            } catch (t: Throwable) {
                reportError("Ошибка распознавания GigaAM: ${t.message ?: t.javaClass.simpleName}")
            }
        }
    }

    /** Запись с VAD: стоп по тишине после речи, по ручному флагу или по максимуму. */
    private fun recordUtterance(): ShortArray? {
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) {
            reportError("AudioRecord: некорректный размер буфера ($minBuf)")
            return null
        }
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf, SAMPLE_RATE * 2) // ≥ 2 секунды буфера
            )
        } catch (t: Throwable) {
            reportError("AudioRecord создать не удалось: ${t.message}")
            return null
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            reportError("AudioRecord не инициализирован (нет разрешения?)")
            return null
        }

        val chunks = ArrayList<ShortArray>()
        var totalSamples = 0
        var hadSpeech = false
        var speechMs = 0L
        var silenceMs = 0L
        val chunkSamples = (SAMPLE_RATE * CHUNK_MS / 1000).toInt() // 1600
        val buf = ShortArray(chunkSamples)

        try {
            setState(State.RECORDING, "Говорите")
            record.startRecording()
            val startedAt = System.currentTimeMillis()
            while (!stopRequested) {
                val n = record.read(buf, 0, chunkSamples)
                if (n <= 0) continue
                chunks.add(buf.copyOf(n))
                totalSamples += n

                var acc = 0.0
                for (i in 0 until n) acc += buf[i].toDouble() * buf[i]
                val rms = kotlin.math.sqrt(acc / n)

                if (rms > RMS_SPEECH_THRESHOLD) {
                    hadSpeech = true
                    speechMs += CHUNK_MS
                    silenceMs = 0
                } else if (hadSpeech) {
                    silenceMs += CHUNK_MS
                }

                val elapsed = System.currentTimeMillis() - startedAt
                if (elapsed >= MAX_RECORD_MS) break
                if (hadSpeech && speechMs >= MIN_SPEECH_MS && silenceMs >= SILENCE_STOP_MS) break
                // Эхо-защита не нужна: Dart не запускает транскрипцию при говорящем TTS
            }
        } finally {
            try {
                record.stop()
            } catch (t: Throwable) {
                Log.w(TAG, "AudioRecord.stop: ${t.message}")
            }
            record.release()
        }

        if (totalSamples == 0) return null
        val pcm = ShortArray(totalSamples)
        var pos = 0
        for (c in chunks) {
            System.arraycopy(c, 0, pcm, pos, c.size)
            pos += c.size
        }
        return pcm
    }

    /** Полный пайплайн: PCM16 → float32 → frontend → encoder → CTC decode. */
    private fun infer(pcm: ShortArray): String {
        val session = encoderSession ?: throw IOException("Модель не загружена")
        val fe = frontendSession ?: throw IOException("Фронтенд не загружен")

        // нормализация в float32 [-1, 1]; минимум 320 сэмплов (n_fft)
        var n = pcm.size
        if (n < N_FFT) n = N_FFT
        val wav = FloatArray(n)
        for (i in pcm.indices) wav[i] = pcm[i] / 32768.0f

        // --- frontend: (1, N) → (1, 64, T) ---
        val wavTensor = OnnxTensor.createTensor(ortEnv, FloatBuffer.wrap(wav), longArrayOf(1, n.toLong()))
        val feOut = fe.run(mapOf("waveform" to wavTensor))
        val featTensor = feOut[0] as OnnxTensor
        val featShape = featTensor.shape // [1, 64, T]
        val frames = featShape[2].toInt()
        val fb = featTensor.floatBuffer
        val feats = FloatArray(fb.remaining())
        fb.get(feats)
        featTensor.close()
        wavTensor.close()
        feOut.close()

        val featLen = ((n - N_FFT) / HOP) + 1
        if (frames != featLen) {
            Log.w(TAG, "frontend T=$frames != expected $featLen (используем ONNX значение)")
        }

        // --- encoder: (1,64,T) + lengths → log_probs (1,T',34) ---
        val featInput = OnnxTensor.createTensor(
            ortEnv, FloatBuffer.wrap(feats), longArrayOf(1, N_MELS.toLong(), frames.toLong())
        )
        val lenInput = OnnxTensor.createTensor(
            ortEnv, LongBuffer.wrap(longArrayOf(frames.toLong())), longArrayOf(1)
        )
        val encOut = session.run(mapOf("features" to featInput, "feature_lengths" to lenInput))

        val logprobsTensor = encOut[0] as OnnxTensor
        val lpShape = logprobsTensor.shape // [1, T', 34]
        val tPrime = lpShape[1].toInt()
        val vocab = lpShape[2].toInt()
        val lp = logprobsTensor.floatBuffer
        val elenTensor = encOut[1] as OnnxTensor
        val encodedLen = elenTensor.intBuffer.get(0).toInt()
        logprobsTensor.close()
        elenTensor.close()
        encOut.close()
        featInput.close()
        lenInput.close()

        // --- жадный CTC-декод ---
        val sb = StringBuilder()
        var prev = CHANNELS_ACC // blank
        val limit = minOf(tPrime, encodedLen)
        for (t in 0 until limit) {
            val base = t * vocab
            var best = 0
            var bestVal = lp.get(base)
            for (c in 1 until vocab) {
                val v = lp.get(base + c)
                if (v > bestVal) {
                    bestVal = v
                    best = c
                }
            }
            if (best != prev && best != CHANNELS_ACC) {
                sb.append(labels[best])
            }
            prev = best
        }
        return sb.toString().trim()
    }
}
