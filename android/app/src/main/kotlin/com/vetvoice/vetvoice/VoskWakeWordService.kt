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
        private const val MODEL_URL = "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip"
        private const val MODEL_VERSION = "0.22"
        // Ожидаемый SHA-256 модели — защита от подмены (фикс B-11).
        private const val EXPECTED_MODEL_SHA256 =
            "961d5ff98a17f4aa6de69864d0aa71fa5bac682301d2b5d17a3f24c5c99a46d4"
        // ===== /КОНФИГУРАЦИЯ =====

        private const val MODEL_VERSION_KEY = "vosk_model_version"
        private const val LAST_CHECK_KEY = "vosk_last_check"
        private const val MODEL_DIR_NAME = "vosk-model-ru"
        private const val SAMPLE_RATE = 16000f
        private const val CHECK_INTERVAL_MS = 7L * 24 * 60 * 60 * 1000
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
        setState(State.LOADING, "Проверка модели...")
        downloadJob?.cancel()
        downloadJob = scope.launch {
            try {
                val modelDir = File(context.filesDir, MODEL_DIR_NAME)
                if (isModelPresent(modelDir) && !needsUpdate()) {
                    mainHandler.post { setState(State.LOADING, "Загрузка в память...") }
                    withContext(Dispatchers.Main) { loadModelFromDir(modelDir) }
                } else {
                    withContext(Dispatchers.Main) {
                        setState(State.LOADING, "Загрузка модели (~50 МБ)...")
                    }
                    downloadAndExtractModel(modelDir)
                    mainHandler.post { setState(State.LOADING, "Загрузка в память...") }
                    withContext(Dispatchers.Main) { loadModelFromDir(modelDir) }
                }
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

    private fun isModelPresent(modelDir: File): Boolean {
        val amFile = File(modelDir, "model/am")
        if (amFile.exists() && amFile.isDirectory) return true
        // Fallback: если модель распакована с корневой папкой ZIP
        modelDir.listFiles()?.firstOrNull { it.isDirectory && it.name.contains("vosk-model") }?.let {
            return File(it, "model/am").exists() && File(it, "model/am").isDirectory
        }
        // Fallback: ищем model/am рекурсивно на один уровень
        modelDir.listFiles()?.forEach { dir ->
            if (dir.isDirectory) {
                val candidate = File(dir, "am")
                if (candidate.exists() && candidate.isDirectory) return true
            }
        }
        return false
    }

    private fun needsUpdate(): Boolean {
        val lastCheck = prefs.getLong(LAST_CHECK_KEY, 0)
        return prefs.getString(MODEL_VERSION_KEY, null) != MODEL_VERSION ||
            (System.currentTimeMillis() - lastCheck) > CHECK_INTERVAL_MS
    }

    private fun loadModelFromDir(modelDir: File) {
        try {
            // Ищем директорию модели — сначала стандартный путь, потом fallback
            var modelPath = File(modelDir, "model")
            if (!modelPath.exists()) {
                // Модель может быть внутри подпапки (vosk-model-small-ru-0.22/model/)
                modelDir.listFiles()?.firstOrNull { it.isDirectory && it.name.contains("vosk-model") }?.let {
                    val candidate = File(it, "model")
                    if (candidate.exists()) modelPath = candidate
                }
                // Последний шанс — ищем любую папку с model/conf
                if (!modelPath.exists()) {
                    modelDir.listFiles()?.forEach { dir ->
                        if (dir.isDirectory) {
                            val conf = File(dir, "conf")
                            if (conf.exists() && conf.isDirectory) {
                                modelPath = dir
                                return@forEach
                            }
                        }
                    }
                }
            }

            if (!modelPath.exists()) {
                setState(State.ERROR, "Директория модели не найдена")
                Log.e(TAG, "Model dir not found in: ${modelDir.absolutePath}")
                modelDir.listFiles()?.forEach { f -> Log.d(TAG, "  ${f.name} (${if (f.isDirectory) "dir" else "file"})") }
                return
            }

            Log.d(TAG, "Loading model from: ${modelPath.absolutePath}")
            voskModel = Model(modelPath.absolutePath)
            setState(State.READY, "Модель готова")
            onModelReady?.invoke()
            prefs.edit()
                .putLong(LAST_CHECK_KEY, System.currentTimeMillis())
                .putString(MODEL_VERSION_KEY, MODEL_VERSION)
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load model", e)
            setState(State.ERROR, "Ошибка загрузки модели: ${e.localizedMessage}")
        }
    }

    private suspend fun downloadAndExtractModel(targetDir: File) {
        Log.d(TAG, "Downloading model from $MODEL_URL")
        targetDir.mkdirs()
        val tempZip = File(context.cacheDir, "vosk-model.zip")
        if (tempZip.exists()) tempZip.delete()
        val url = URL(MODEL_URL)
        val connection = url.openConnection() as HttpURLConnection
        connection.connectTimeout = 30000
        connection.readTimeout = 120000
        connection.instanceFollowRedirects = true
        connection.connect()
        try {
            // === ФАЗА 1: Скачивание ===
            val contentLength = connection.contentLength.toLong()
            val totalMB = if (contentLength > 0) contentLength / (1024.0 * 1024.0) else 50.0
            mainHandler.post { onDownloadProgress?.invoke(0.0, totalMB) }
            mainHandler.post { setState(State.LOADING, "Скачивание модели...") }

            connection.inputStream.use { input ->
                FileOutputStream(tempZip).use { output ->
                    val buffer = ByteArray(16384) // 16 КБ буфер
                    var totalRead = 0L
                    var lastProgressMB = 0.0
                    while (true) {
                        coroutineContext.ensureActive()
                        val read = input.read(buffer)
                        if (read == -1) break
                        output.write(buffer, 0, read)
                        totalRead += read
                        val downloadedMB = totalRead / (1024.0 * 1024.0)
                        if (downloadedMB - lastProgressMB >= 0.5 || totalRead == contentLength) {
                            lastProgressMB = downloadedMB
                            val currentTotalMB = if (contentLength > 0) totalMB else downloadedMB
                            mainHandler.post { onDownloadProgress?.invoke(downloadedMB, currentTotalMB) }
                        }
                    }
                }
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
        } finally {
            connection.disconnect()
            if (tempZip.exists()) tempZip.delete()
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
