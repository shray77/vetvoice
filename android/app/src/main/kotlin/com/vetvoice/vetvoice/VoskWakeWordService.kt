package com.vetvoice.vetvoice

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.*
import kotlin.coroutines.coroutineContext
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream
import java.io.BufferedOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.zip.ZipInputStream
import java.util.zip.ZipEntry

class VoskWakeWordService(private val context: Context) {

    companion object {
        private const val TAG = "VoskWakeWord"

        // ===== КОНФИГУРАЦИЯ (менять тут при обновлении модели) =====
        // ⚠️ Фикс Q-5: все настройки модели собраны в одном месте —
        // было разбросано по коду, теперь меняешь версию → правишь 3 строки тут.
        // URL скачивания модели Vosk (офлайн-распознавание русской речи).
        // v1.16.3: список источников, первый доступный побеждает. alphacephei.com
        // из мобильных сетей РФ часто тянет 46 МБ часами и рвёт соединение —
        // поэтому добавлено зеркало на GitHub CDN (тот же файл, тот же SHA-256,
        // целостность всё равно проверяется ниже перед распаковкой).
        private val MODEL_URLS = listOf(
            "https://github.com/shray77/vetvoice/releases/download/vosk-model-ru-0.22/vosk-model-small-ru-0.22.zip",
            "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip",
        )
        private const val MODEL_VERSION = "0.22"
        // Ожидаемый SHA-256 модели — защита от подмены (фикс B-11).
        private const val EXPECTED_MODEL_SHA256 =
            "961d5ff98a17f4aa6de69864d0aa71fa5bac682301d2b5d17a3f24c5c99a46d4"
        // ===== /КОНФИГУРАЦИЯ =====

        private const val MODEL_VERSION_KEY = "vosk_model_version"
        private const val LAST_CHECK_KEY = "vosk_last_check"
        private const val MODEL_DIR_NAME = "vosk-model-ru"
        private const val SAMPLE_RATE = 16000f
        // v1.16.3: параметры скачивания. readTimeout — таймаут ОДНОГО блока чтения
        // (не всего файла), поэтому можно смело ставить большой: соединение,
        // отдающее хоть байт в 3 минуты, считается живым.
        private const val DOWNLOAD_ATTEMPTS_PER_URL = 3
        private const val DOWNLOAD_CONNECT_TIMEOUT_MS = 20000
        private const val DOWNLOAD_READ_TIMEOUT_MS = 180000
        private const val FALLBACK_TOTAL_MB = 44.0
        // v1.16.4: CHECK_INTERVAL_MS удалён вместе с 7-дневным перекачиванием
        // модели (см. initialize, случай A).
    }

    enum class State { IDLE, LOADING, READY, LISTENING, ERROR }

    var onStateChanged: ((State, String) -> Unit)? = null
    var onWakeWordDetected: (() -> Unit)? = null
    var onPartialResult: ((String) -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    var onDownloadProgress: ((downloadedMB: Double, totalMB: Double) -> Unit)? = null
    var onModelReady: (() -> Unit)? = null  // Автозапуск прослушивания после загрузки
    var onMicReleased: (() -> Unit)? = null  // Вызывается после реального освобождения микрофона

    private var state: State = State.IDLE
    private var voskModel: Model? = null
    private var voskRecognizer: Recognizer? = null
    private var speechService: SpeechService? = null
    private val prefs: SharedPreferences = context.getSharedPreferences("vosk_wakeword", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())
    private var downloadJob: Job? = null

    private val wakeWordPatterns = listOf(
        "ветвойс", "вет войс", "вет-войс", "ветвойз", "вет войз",
        "вета войс", "вета войз", "вита войс", "вита войз",
        "вет голос", "вета голос", "вэт войс", "вэт войз",
        "ветпомощь", "вет помощь", "ветеринар",
    )

    private val recognitionListener = object : RecognitionListener {
        override fun onPartialResult(hypothesis: String?) {
            val text = parseJsonField(hypothesis, "text") ?: hypothesis ?: ""
            if (text.isNotBlank()) {
                mainHandler.post { onPartialResult?.invoke(text) }
            }
            if (hypothesis != null && containsWakeWord(hypothesis)) {
                mainHandler.post {
                    Log.i(TAG, "Wake word detected in partial: $hypothesis")
                    onWakeWordDetected?.invoke()
                }
            }
        }

        override fun onResult(hypothesis: String?) {
            if (hypothesis != null && containsWakeWord(hypothesis)) {
                mainHandler.post {
                    Log.i(TAG, "Wake word detected in result: $hypothesis")
                    onWakeWordDetected?.invoke()
                }
            }
        }

        override fun onFinalResult(hypothesis: String?) {
            if (hypothesis != null && containsWakeWord(hypothesis)) {
                mainHandler.post {
                    Log.i(TAG, "Wake word detected in final: $hypothesis")
                    onWakeWordDetected?.invoke()
                }
            }
        }

        override fun onError(exception: Exception?) {
            val msg = exception?.localizedMessage ?: "Ошибка распознавания"
            Log.e(TAG, "Recognition error: $msg", exception)
            mainHandler.post {
                setState(State.ERROR, msg)
                onError?.invoke(msg)
            }
        }

        override fun onTimeout() {
            // ⚠️ Фикс B-7: ранее вызывали speechService?.stop() затем
            // speechService?.startListening(this) на ТОМ ЖЕ экземпляре SpeechService.
            // Vosk Android library не гарантирует корректность такого паттерна —
            // recognizer может остаться в некорректном состоянии.
            // Теперь полностью пересоздаём Recognizer и SpeechService на каждом таймауте.
            Log.d(TAG, "Recognition timeout — recreating Recognizer and SpeechService")
            mainHandler.post {
                if (state != State.LISTENING) return@post
                restartRecognition()
            }
        }
    }

    /**
     * Полностью пересоздаёт Recognizer и SpeechService для повторного запуска прослушивания.
     * Безопаснее, чем stop()+startListening() на том же экземпляре.
     */
    private fun restartRecognition() {
        val model = voskModel ?: run {
            setState(State.ERROR, "Модель не загружена при рестарте")
            return
        }
        // Останавливаем текущие ресурсы
        try { speechService?.stop() } catch (e: Exception) {
            Log.w(TAG, "restartRecognition: speechService.stop() error: ${e.localizedMessage}")
        }
        try { speechService?.shutdown() } catch (e: Exception) {
            Log.w(TAG, "restartRecognition: speechService.shutdown() error: ${e.localizedMessage}")
        }
        try { voskRecognizer?.close() } catch (e: Exception) {
            Log.w(TAG, "restartRecognition: recognizer.close() error: ${e.localizedMessage}")
        }
        speechService = null
        voskRecognizer = null
        // Создаём новые экземпляры и стартуем
        try {
            voskRecognizer = Recognizer(model, SAMPLE_RATE)
            speechService = SpeechService(voskRecognizer!!, SAMPLE_RATE)
            speechService?.startListening(recognitionListener)
            setState(State.LISTENING, "Слушаю... (рестарт)")
        } catch (e: Exception) {
            Log.e(TAG, "restartRecognition: failed to recreate", e)
            setState(State.ERROR, "Ошибка рестарта: ${e.localizedMessage}")
        }
    }

    fun getState(): State = state

    fun initialize(): Boolean {
        if (state == State.READY || state == State.LISTENING) return true
        // ⚠️ Фикс v1.16.2: если загрузка УЖЕ идёт — НЕ отменяем и не перезапускаем её.
        // Раньше каждый повторный вызов initialize() делал downloadJob?.cancel()
        // и запускал скачивание заново: Dart-ретраи и кнопка «Загрузить» в
        // настройках раз за разом обрывали 46-МБ файл на полпути — модель
        // фактически не могла докачаться («воск по итогу не скачался»).
        if (state == State.LOADING) return false
        setState(State.LOADING, "Проверка модели...")
        downloadJob?.cancel()
        downloadJob = scope.launch {
            try {
                val modelDir = File(context.filesDir, MODEL_DIR_NAME)
                // v1.16.4: трёхуровневая логика вместо «isModelPresent && !needsUpdate()»:
                //  A) модель на месте и версия совпадает → грузим сразу, ноль сети;
                //  B) модель на месте, версия НЕИЗВЕСТНА (грязное состояние после
                //     бага «директория не найдена»: файлы распакованы, а prefs
                //     записываются только после успешной загрузки) → сначала
                //     пробуем загрузить существующую копию, и только если она
                //     битая — качаем. Убирает лишние 46 МБ при первом запуске
                //     после обновления;
                //  C) модели нет ИЛИ версия сменилась (MODEL_VERSION бампнут
                //     намеренно) ИЛИ существующая копия не загрузилась → качаем.
                //  Еженедельный перекачивающий чек (needsUpdate/CHECK_INTERVAL_MS)
                //  убран: 46 МБ каждые 7 дней в поле — это не «обновление», а вред.
                val savedVersion = prefs.getString(MODEL_VERSION_KEY, null)
                val present = isModelPresent(modelDir)
                if (present && savedVersion == MODEL_VERSION) {
                    // Случай A
                    mainHandler.post { setState(State.LOADING, "Загрузка в память...") }
                    withContext(Dispatchers.Main) { loadModelFromDir(modelDir) }
                    return@launch
                }
                if (present && savedVersion == null &&
                    loadModelFromDir(modelDir, silent = true)) {
                    // Случай B: существующая копия жива — prefs уже записаны
                    return@launch
                }
                // Случай C
                withContext(Dispatchers.Main) {
                    setState(State.LOADING, "Загрузка модели (~46 МБ)...")
                }
                downloadAndExtractModel(modelDir)
                mainHandler.post { setState(State.LOADING, "Загрузка в память...") }
                withContext(Dispatchers.Main) { loadModelFromDir(modelDir) }
            } catch (e: CancellationException) {
                withContext(Dispatchers.Main) { setState(State.IDLE, "Загрузка отменена") }
            } catch (e: Exception) {
                Log.e(TAG, "Initialization error", e)
                withContext(Dispatchers.Main) {
                    setState(State.ERROR, "Ошибка: ${e.localizedMessage}")
                    onError?.invoke("Ошибка: ${e.localizedMessage}")
                }
            }
        }
        return false
    }

    fun startListening() {
        if (state == State.LOADING) return
        if (state != State.READY) { initialize(); return }
        val model = voskModel ?: run {
            setState(State.ERROR, "Модель не загружена")
            return
        }
        try {
            voskRecognizer = Recognizer(model, SAMPLE_RATE)
            speechService = SpeechService(voskRecognizer!!, SAMPLE_RATE)
            speechService?.startListening(recognitionListener)
            setState(State.LISTENING, "Слушаю...")
        } catch (e: Exception) {
            setState(State.ERROR, "Ошибка запуска: ${e.localizedMessage}")
        }
    }

    fun stopListening() {
        if (state == State.LISTENING) {
            Log.d(TAG, "stopListening: releasing microphone resources...")
            try {
                speechService?.stop()
            } catch (e: Exception) {
                Log.w(TAG, "speechService.stop() error: ${e.localizedMessage}")
            }
            try {
                speechService?.shutdown()
            } catch (e: Exception) {
                Log.w(TAG, "speechService.shutdown() error: ${e.localizedMessage}")
            }
            speechService = null
            try {
                voskRecognizer?.close()
            } catch (e: Exception) {
                Log.w(TAG, "voskRecognizer.close() error: ${e.localizedMessage}")
            }
            voskRecognizer = null
            Log.d(TAG, "stopListening: microphone released")
            setState(State.READY, "Остановлен")
            // Уведомляем об освобождении микрофона через callback
            mainHandler.post {
                Log.d(TAG, "stopListening: calling onMicReleased callback")
                onMicReleased?.invoke()
            }
        } else {
            // Если не слушали — всё равно вызываем callback (микрофон свободен)
            mainHandler.post {
                onMicReleased?.invoke()
            }
        }
    }

    fun dispose() {
        stopListening()
        downloadJob?.cancel()
        try {
            voskModel?.close()
        } catch (_: Exception) {}
        voskModel = null
        scope.cancel()
        setState(State.IDLE, "")
    }

    /**
     * v1.16.4: единый резолвер корня модели. Официальный ZIP
     * vosk-model-small-ru-0.22.zip НЕ содержит папки model/ — внутри сразу
     * vosk-model-small-ru-0.22/[am,conf,graph]. После strip-распаковки
     * (v1.16.3) файлы ложатся ПРЯМО в modelDir, а старые проверки искали
     * только File(modelDir, "model"): модель распаковывалась, но не
     * загружалась («директория не найдена»), prefs о готовности не
     * записывались, и при следующем запуске isModelPresent был false →
     * 46 МБ качались ЗАНОВО при каждом старте. Поддерживаем все раскладки:
     *   1) modelDir/model/[am,conf]              — классическая
     *   2) modelDir/vosk-model-xxx/[am,conf]     — ZIP-корень без strip
     *   3) modelDir/[am,conf]                    — наша strip-распаковка
     */
    private fun looksLikeModel(dir: File): Boolean =
        File(dir, "am").isDirectory &&
            (File(dir, "conf").isDirectory || File(dir, "graph").isDirectory)

    private fun resolveModelPath(modelDir: File): File? {
        // 1) Классическая раскладка
        val classic = File(modelDir, "model")
        if (classic.isDirectory && looksLikeModel(classic)) return classic
        // 2) Вложенный корень ZIP (старые распаковки, обновление поверх)
        modelDir.listFiles()?.forEach { child ->
            if (child.isDirectory) {
                if (looksLikeModel(child)) return child
                val nested = File(child, "model")
                if (nested.isDirectory && looksLikeModel(nested)) return nested
            }
        }
        // 3) Strip-распаковка: сам modelDir и есть корень модели
        if (looksLikeModel(modelDir)) return modelDir
        return null
    }

    private fun isModelPresent(modelDir: File): Boolean = resolveModelPath(modelDir) != null

    // v1.16.4: needsUpdate() удалён вместе с 7-дневным чеком — решение о
    // скачивании теперь принимает initialize (случаи A/B/C, см. комментарий там).

    private fun loadModelFromDir(modelDir: File, silent: Boolean = false): Boolean {
        // v1.16.4: возвращает успех; silent=true не показывает ERROR-состояния
        // (используется для пробной загрузки существующей копии в initialize).
        try {
            // v1.16.4: все раскладки через единый резолвер (см. resolveModelPath)
            val modelPath = resolveModelPath(modelDir)

            if (modelPath == null) {
                Log.e(TAG, "Model dir not found in: ${modelDir.absolutePath}")
                modelDir.listFiles()?.forEach { f -> Log.d(TAG, "  ${f.name} (${if (f.isDirectory) "dir" else "file"})") }
                if (!silent) {
                    setState(State.ERROR, "Директория модели не найдена")
                }
                return false
            }

            Log.d(TAG, "Loading model from: ${modelPath.absolutePath}")
            voskModel = Model(modelPath.absolutePath)
            setState(State.READY, "Модель готова")
            onModelReady?.invoke()
            prefs.edit()
                .putLong(LAST_CHECK_KEY, System.currentTimeMillis())
                .putString(MODEL_VERSION_KEY, MODEL_VERSION)
                .apply()
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load model", e)
            if (!silent) {
                setState(State.ERROR, "Ошибка загрузки модели: ${e.localizedMessage}")
            }
            return false
        }
    }

    private suspend fun downloadAndExtractModel(targetDir: File) {
        targetDir.mkdirs()
        // v1.16.3: tempZip НЕ удаляем перед стартом — если предыдущая попытка
        // оборвалась, докачиваем с места обрыва через Range-запрос. Раньше файл
        // стирался и 46 МБ качались с нуля на каждой попытке; на медленной сети
        // это означало «модель никогда не докачается» (полевой репорт: «таймаут»).
        val tempZip = File(context.cacheDir, "vosk-model.zip")

        var lastError: Exception? = null
        var downloaded = false
        urlLoop@ for (modelUrl in MODEL_URLS) {
            for (attempt in 1..DOWNLOAD_ATTEMPTS_PER_URL) {
                try {
                    coroutineContext.ensureActive()
                    downloadToFile(modelUrl, tempZip)
                    downloaded = true
                    break@urlLoop
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    lastError = e
                    Log.w(TAG, "Download failed (url=${modelUrl.substringBefore("/vosk-model")}..., attempt=$attempt): ${e.message}; partial=${tempZip.length()} bytes")
                    // Недокачанный файл ОСТАЁТСЯ — следующая попытка/URL докачает
                    // (Range). Перед сменой URL-источника файл оставляем тоже:
                    // серверы отдают идентичный файл (SHA-256 проверяется после).
                    if (attempt < DOWNLOAD_ATTEMPTS_PER_URL) delay(2000L * attempt)
                }
            }
        }
        if (!downloaded) {
            throw IOException("Не удалось скачать модель: ${lastError?.message ?: "нет доступа ко всем источникам"}. Частичный файл сохранён (${tempZip.length() / (1024 * 1024)} МБ) — при следующей попытке докачаем.")
        }

        coroutineContext.ensureActive()
        Log.d(TAG, "Download complete, file size: ${tempZip.length()} bytes")

            // ⚠️ Фикс B-11: проверка SHA-256 модели — supply-chain protection.
            // Если файл подменён в transit (MITM, скомпрометированный CDN) — не используем его.
            val actualSha256 = sha256OfFile(tempZip)
            Log.d(TAG, "Downloaded model SHA-256: $actualSha256")
            if (!actualSha256.equals(EXPECTED_MODEL_SHA256, ignoreCase = true)) {
                tempZip.delete()
                val msg = "Ошибка проверки целостности модели. Ожидался SHA-256 «$EXPECTED_MODEL_SHA256», получен «$actualSha256». Возможна подмена файла."
                Log.e(TAG, msg)
                withContext(Dispatchers.Main) {
                    setState(State.ERROR, msg)
                    onError?.invoke(msg)
                }
                throw SecurityException(msg)
            }
            Log.i(TAG, "✅ Model SHA-256 verified, integrity OK")

            // === ФАЗА 2: Распаковка с прогрессом по файлам ===
            mainHandler.post { setState(State.LOADING, "Подсчёт файлов...") }

            // Сначала быстро считаем общее число файлов в архиве
            var totalEntries = 0
            ZipInputStream(tempZip.inputStream()).use { zis ->
                var entry = zis.nextEntry
                while (entry != null) {
                    if (!entry.isDirectory) totalEntries++
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }
            Log.d(TAG, "ZIP contains $totalEntries files")

            // Определяем корневую папку в ZIP (напр. "vosk-model-small-ru-0.22/")
            // чтобы strip-нуть её при распаковке
            val commonPrefix = ZipInputStream(tempZip.inputStream()).use { zis ->
                val firstEntry = zis.nextEntry
                if (firstEntry != null && firstEntry.isDirectory) {
                    firstEntry.name // например "vosk-model-small-ru-0.22/"
                } else {
                    ""
                }
            }
            val stripPrefix = if (commonPrefix.endsWith("/")) commonPrefix.length else 0
            Log.d(TAG, "Strip prefix from ZIP entries: '$commonPrefix' ($stripPrefix chars)")

            // Теперь распаковываем с прогрессом
            mainHandler.post { setState(State.LOADING, "Распаковка: 0 / $totalEntries") }

            targetDir.deleteRecursively()
            targetDir.mkdirs()
            val canonicalTargetPath = targetDir.canonicalPath
            var extractedFiles = 0

            ZipInputStream(tempZip.inputStream()).use { zis ->
                val buffer = ByteArray(16384) // 16 КБ буфер
                var entry: ZipEntry? = zis.nextEntry
                while (entry != null) {
                    coroutineContext.ensureActive()

                    // Strip корневую папку из пути
                    val entryPath = if (stripPrefix > 0 && entry.name.startsWith(commonPrefix)) {
                        entry.name.substring(stripPrefix)
                    } else {
                        entry.name
                    }
                    // Пропускаем пустые пути после strip
                    if (entryPath.isEmpty() || entryPath == "/") {
                        zis.closeEntry()
                        entry = zis.nextEntry
                        continue
                    }

                    val outFile = File(targetDir, entryPath)

                    // Защита от zip-slip
                    if (!outFile.canonicalPath.startsWith("$canonicalTargetPath/")) {
                        zis.closeEntry()
                        entry = zis.nextEntry
                        continue
                    }

                    if (entry.isDirectory) {
                        outFile.mkdirs()
                    } else {
                        outFile.parentFile?.mkdirs()
                        BufferedOutputStream(FileOutputStream(outFile), buffer.size).use { out ->
                            var len: Int
                            while (zis.read(buffer).also { len = it } != -1) {
                                out.write(buffer, 0, len)
                            }
                        }
                        extractedFiles++
                        // Обновляем прогресс каждые 10 файлов
                        if (extractedFiles % 10 == 0 || extractedFiles == totalEntries) {
                            val current = extractedFiles
                            mainHandler.post {
                                setState(State.LOADING, "Распаковка: $current / $totalEntries")
                                onDownloadProgress?.invoke(current.toDouble(), totalEntries.toDouble())
                            }
                        }
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }

            Log.d(TAG, "Extraction complete: $extractedFiles files")
            coroutineContext.ensureActive()
            mainHandler.post { setState(State.LOADING, "Распаковка завершена") }
        // v1.16.3: tempZip удаляем только после УСПЕШНОЙ распаковки — иначе
        // следующий запуск сможет докачать/переиспользовать его.
        if (tempZip.exists()) tempZip.delete()
        Log.i(TAG, "Model zip cleaned up")
    }

    /**
     * v1.16.3: скачивание одного URL с докачкой через Range.
     * - Уже скачанный префикс tempZip НЕ перезаписывается: шлём
     *   Range: bytes=<size>-; 206 → append, 200 → начинаем заново.
     * - 416 Range Not Satisfiable → файл уже скачан целиком ранее.
     * - Прогресс в UI — в АБСОЛЮТНЫХ МБ (с учётом ранее скачанного).
     * - Ошибка чтения/обрыв → исключение вверх (наружный цикл делает ретраи).
     */
    private suspend fun downloadToFile(modelUrl: String, tempZip: File) {
        val already = if (tempZip.exists()) tempZip.length() else 0L
        val connection = (URL(modelUrl).openConnection() as HttpURLConnection).apply {
            connectTimeout = DOWNLOAD_CONNECT_TIMEOUT_MS
            readTimeout = DOWNLOAD_READ_TIMEOUT_MS
            instanceFollowRedirects = true
            if (already > 0L) setRequestProperty("Range", "bytes=$already-")
        }
        connection.connect()
        try {
            val code = connection.responseCode
            if (code == 416) {
                // Уже скачан весь файл в прошлой сессии — считаем успехом.
                Log.i(TAG, "HTTP 416 — file already fully downloaded (${tempZip.length()} bytes)")
                return
            }
            if (code != 200 && code != 206) {
                throw IOException("HTTP $code")
            }
            val resuming = code == 206 && already > 0L
            val contentLength = connection.getHeaderField("Content-Length")?.toLongOrNull() ?: -1L
            val base = if (resuming) already else 0L
            val totalBytes = if (contentLength > 0) base + contentLength else -1L
            val totalMB = if (totalBytes > 0) totalBytes / (1024.0 * 1024.0) else FALLBACK_TOTAL_MB

            mainHandler.post {
                setState(State.LOADING, if (resuming)
                    "Продолжаем скачивание (${base / (1024.0 * 1024.0)} МБ из ~${totalMB.toInt()})..."
                else "Скачивание модели...")
                onDownloadProgress?.invoke(base / (1024.0 * 1024.0), totalMB)
            }

            FileOutputStream(tempZip, resuming).use { output ->
                connection.inputStream.use { input ->
                    val buffer = ByteArray(32768) // 32 КБ буфер
                    var totalRead = base
                    var lastProgressMB = base / (1024.0 * 1024.0)
                    while (true) {
                        coroutineContext.ensureActive()
                        val read = input.read(buffer)
                        if (read == -1) break
                        output.write(buffer, 0, read)
                        totalRead += read
                        val downloadedMB = totalRead / (1024.0 * 1024.0)
                        if (downloadedMB - lastProgressMB >= 0.5 || (totalBytes > 0 && totalRead == totalBytes)) {
                            lastProgressMB = downloadedMB
                            mainHandler.post { onDownloadProgress?.invoke(downloadedMB, totalMB) }
                        }
                    }
                }
            }
            if (totalBytes > 0 && tempZip.length() < totalBytes) {
                throw IOException("Соединение оборвалось: ${tempZip.length()} из $totalBytes байт (докачаем при следующей попытке)")
            }
            Log.i(TAG, "Download OK: ${tempZip.length()} bytes (resumed=$resuming)")
        } finally {
            connection.disconnect()
        }
    }

    private fun containsWakeWord(text: String): Boolean {
        val normalized = text.lowercase()
            .replace(Regex("[^\\w\\sа-яА-ЯёЁ]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
        for (pattern in wakeWordPatterns) {
            if (normalized.contains(pattern)) return true
        }
        if (normalized.contains("вет")) {
            val words = normalized.split(" ")
            for (i in words.indices) {
                if (words[i].startsWith("вет")) {
                    if (i + 1 < words.size && isSimilarToVoice(words[i + 1])) return true
                    if (words[i].length > 3 && isSimilarToVoice(words[i].substring(3))) return true
                }
            }
        }
        return false
    }

    private fun isSimilarToVoice(word: String): Boolean {
        return listOf("войс", "войз", "воис", "воиз", "голос", "волос").any {
            word.contains(it) || levenshtein(word, it) <= 2
        }
    }

    private fun levenshtein(s1: String, s2: String): Int {
        if (s1.length < s2.length) return levenshtein(s2, s1)
        if (s2.isEmpty()) return s1.length
        var previousRow = 0
        val row = IntArray(s2.length + 1) { it }
        for (i in s1.indices) {
            previousRow = i + 1
            for (j in s2.indices) {
                val cost = if (s1[i] == s2[j]) 0 else 1
                val newValue = minOf(row[j + 1] + 1, previousRow + 1, row[j] + cost)
                row[j] = previousRow
                previousRow = newValue
            }
            row[s2.length] = previousRow
        }
        return row[s2.length]
    }

    private fun parseJsonField(json: String?, field: String): String? {
        // ⚠️ Фикс B-8: ранее использовался regex `"""$field"\s*:\s*"([^"]*)"""`,
        // который ломался на экранированных кавычках, вложенных объектах или числах.
        // Любое изменение формата вывода Vosk молча ломало wake-word detection.
        // Теперь используем полноценный JSONObject — это стандартная и надёжная практика.
        if (json.isNullOrBlank()) return null
        return try {
            val obj = JSONObject(json)
            obj.optString(field, "")
        } catch (e: Exception) {
            Log.w(TAG, "parseJsonField: not valid JSON, fallback to raw: ${e.localizedMessage}")
            null
        }
    }

    private fun setState(newState: State, message: String) {
        state = newState
        onStateChanged?.invoke(newState, message)
    }

    /**
     * Вычисляет SHA-256 файла потоково (для больших файлов).
     * ⚠️ Фикс B-11: используется для проверки целостности скачанной Vosk-модели.
     */
    private fun sha256OfFile(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            var read: Int
            while (input.read(buffer).also { read = it } != -1) {
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
