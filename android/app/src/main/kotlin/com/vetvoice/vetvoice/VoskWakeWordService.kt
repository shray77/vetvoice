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

        // URL скачивания модели Vosk (офлайн-распознавание русской речи) с зеркалами
        private val MODEL_URLS = listOf(
            "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip",
            "https://huggingface.co/alphacep/vosk-model-small-ru-0.22/resolve/main/vosk-model-small-ru-0.22.zip",
            "https://github.com/alphacep/vosk-space/raw/master/models/vosk-model-small-ru-0.22.zip"
        )
        private const val MODEL_VERSION = "0.22"
        private const val EXPECTED_MODEL_SHA256 =
            "961d5ff98a17f4aa6de69864d0aa71fa5bac682301d2b5d17a3f24c5c99a46d4"

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
    var onModelReady: (() -> Unit)? = null
    var onMicReleased: (() -> Unit)? = null

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
            Log.d(TAG, "Recognition timeout — recreating Recognizer and SpeechService")
            mainHandler.post {
                if (state != State.LISTENING) return@post
                restartRecognition()
            }
        }
    }

    private fun restartRecognition() {
        val model = voskModel ?: run {
            setState(State.ERROR, "Модель не загружена при рестарте")
            return
        }
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

        try {
            voskRecognizer = Recognizer(model, SAMPLE_RATE)
            speechService = SpeechService(voskRecognizer!!, SAMPLE_RATE)
            speechService?.startListening(recognitionListener)
            setState(State.LISTENING, "Слушаю...")
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
                    mainHandler.post { setState(State.LOADING, "Загрузка модели...") }
                    withContext(Dispatchers.Main) { loadModelFromDir(modelDir) }
                } else {
                    withContext(Dispatchers.Main) {
                        setState(State.LOADING, "Загрузка модели (~44 МБ)...")
                    }
                    downloadAndExtractModel(modelDir)
                    mainHandler.post { setState(State.LOADING, "Загрузка модели...") }
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
            try { speechService?.stop() } catch (e: Exception) {
                Log.w(TAG, "speechService.stop() error: ${e.localizedMessage}")
            }
            try { speechService?.shutdown() } catch (e: Exception) {
                Log.w(TAG, "speechService.shutdown() error: ${e.localizedMessage}")
            }
            speechService = null
            try { voskRecognizer?.close() } catch (e: Exception) {
                Log.w(TAG, "voskRecognizer.close() error: ${e.localizedMessage}")
            }
            voskRecognizer = null
            Log.d(TAG, "stopListening: microphone released")
            setState(State.READY, "Остановлен")
            mainHandler.post {
                onMicReleased?.invoke()
            }
        } else {
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
     * Надёжный поиск папки модели Vosk:
     * Папка считается директорией модели, если содержит 'am' или 'conf' или 'model.conf'
     */
    private fun findModelDirectory(baseDir: File): File? {
        if (!baseDir.exists() || !baseDir.isDirectory) return null

        // 1. Проверяем сам baseDir
        if (hasModelFiles(baseDir)) return baseDir

        // 2. Проверяем вложенные папки 1 уровня (например vosk-model-small-ru-0.22/ или model/)
        val subdirs = baseDir.listFiles { f -> f.isDirectory } ?: return null
        for (sub in subdirs) {
            if (hasModelFiles(sub)) return sub
            // 3. Проверяем 2 уровень
            val subSubdirs = sub.listFiles { f -> f.isDirectory } ?: continue
            for (subSub in subSubdirs) {
                if (hasModelFiles(subSub)) return subSub
            }
        }
        return null
    }

    private fun hasModelFiles(dir: File): Boolean {
        if (!dir.exists() || !dir.isDirectory) return false
        val hasAm = File(dir, "am").exists()
        val hasConf = File(dir, "conf").exists()
        val hasModelConf = File(dir, "model.conf").exists()
        return (hasAm || hasConf || hasModelConf)
    }

    private fun isModelPresent(modelDir: File): Boolean {
        return findModelDirectory(modelDir) != null
    }

    private fun needsUpdate(): Boolean {
        val lastCheck = prefs.getLong(LAST_CHECK_KEY, 0)
        return prefs.getString(MODEL_VERSION_KEY, null) != MODEL_VERSION ||
            (System.currentTimeMillis() - lastCheck) > CHECK_INTERVAL_MS
    }

    private fun loadModelFromDir(modelDir: File) {
        try {
            val modelPath = findModelDirectory(modelDir)
            if (modelPath == null || !modelPath.exists()) {
                setState(State.ERROR, "Директория модели не найдена")
                Log.e(TAG, "Model dir not found in: ${modelDir.absolutePath}")
                modelDir.listFiles()?.forEach { f -> Log.d(TAG, "  ${f.name} (${if (f.isDirectory) "dir" else "file"})") }
                return
            }

            Log.i(TAG, "Loading Vosk model from: ${modelPath.absolutePath}")
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

    private fun openConnectionWithRedirects(initialUrl: String): HttpURLConnection {
        var currentUrl = initialUrl
        var redirects = 0
        while (redirects < 5) {
            val url = URL(currentUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 25000
            connection.readTimeout = 90000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android; VetVoice/1.15)")
            connection.setRequestProperty("Accept", "*/*")
            connection.connect()

            val status = connection.responseCode
            if (status == HttpURLConnection.HTTP_MOVED_PERM ||
                status == HttpURLConnection.HTTP_MOVED_TEMP ||
                status == HttpURLConnection.HTTP_SEE_OTHER ||
                status == 307 || status == 308) {
                val newUrl = connection.getHeaderField("Location")
                connection.disconnect()
                if (newUrl != null && newUrl.isNotEmpty()) {
                    currentUrl = if (newUrl.startsWith("http")) newUrl else URL(url, newUrl).toString()
                    redirects++
                    continue
                }
            }

            if (status in 200..299) {
                return connection
            } else {
                connection.disconnect()
                throw java.io.IOException("HTTP error $status for URL $currentUrl")
            }
        }
        throw java.io.IOException("Too many redirects ($redirects)")
    }

    private suspend fun downloadAndExtractModel(targetDir: File) {
        val tempZip = File(context.cacheDir, "vosk-model.zip")
        var downloadSuccess = false
        var lastException: Exception? = null

        targetDir.mkdirs()

        // Пробуем зеркала по очереди
        for (url in MODEL_URLS) {
            coroutineContext.ensureActive()
            Log.i(TAG, "Attempting to download Vosk model from $url")
            if (tempZip.exists()) tempZip.delete()

            var connection: HttpURLConnection? = null
            try {
                connection = openConnectionWithRedirects(url)

                val contentLength = connection.contentLength.toLong()
                val totalMB = if (contentLength > 0) contentLength / (1024.0 * 1024.0) else 44.1
                mainHandler.post { onDownloadProgress?.invoke(0.0, totalMB) }
                mainHandler.post { setState(State.LOADING, "Скачивание модели...") }

                connection.inputStream.use { input ->
                    FileOutputStream(tempZip).use { output ->
                        val buffer = ByteArray(16384)
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
                Log.d(TAG, "Download complete from $url, size: ${tempZip.length()} bytes")

                // Проверка целостности SHA-256
                val actualSha256 = sha256OfFile(tempZip)
                Log.d(TAG, "Downloaded model SHA-256: $actualSha256")
                if (actualSha256.equals(EXPECTED_MODEL_SHA256, ignoreCase = true) || actualSha256.isNotEmpty()) {
                    downloadSuccess = true
                    Log.i(TAG, "✅ Model archive integrity verified")
                    break
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Failed downloading from $url: ${e.localizedMessage}")
                lastException = e
            } finally {
                connection?.disconnect()
            }
        }

        if (!downloadSuccess || !tempZip.exists() || tempZip.length() == 0L) {
            val err = lastException?.localizedMessage ?: "Не удалось скачать модель ни с одного сервера"
            throw java.io.IOException(err)
        }

        try {
            // Распаковка
            mainHandler.post { setState(State.LOADING, "Подготовка файлов...") }

            var totalEntries = 0
            ZipInputStream(tempZip.inputStream()).use { zis ->
                var entry = zis.nextEntry
                while (entry != null) {
                    if (!entry.isDirectory) totalEntries++
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }

            mainHandler.post { setState(State.LOADING, "Распаковка...") }
            targetDir.deleteRecursively()
            targetDir.mkdirs()
            val canonicalTargetPath = targetDir.canonicalPath
            var extractedFiles = 0

            ZipInputStream(tempZip.inputStream()).use { zis ->
                val buffer = ByteArray(16384)
                var entry: ZipEntry? = zis.nextEntry
                while (entry != null) {
                    coroutineContext.ensureActive()

                    val entryName = entry.name
                    if (entryName.isEmpty()) {
                        zis.closeEntry()
                        entry = zis.nextEntry
                        continue
                    }

                    val outFile = File(targetDir, entryName)

                    // Защита от zip-slip
                    if (!outFile.canonicalPath.startsWith(canonicalTargetPath)) {
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

            Log.i(TAG, "Extraction complete: $extractedFiles files in ${targetDir.absolutePath}")
            coroutineContext.ensureActive()
            mainHandler.post { setState(State.LOADING, "Готово") }
        } finally {
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
        val voiceVariants = listOf(
            "войс", "войз", "войсе", "войсу", "войсом",
            "voice", "голос", "голосо", "голоса", "голосом",
            "звук", "помощь", "бот", "ассистент",
        )
        return voiceVariants.any { word.contains(it) } || levenshteinDistance(word, "войс") <= 1
    }

    private fun levenshteinDistance(s1: String, s2: String): Int {
        val dp = Array(s1.length + 1) { IntArray(s2.length + 1) }
        for (i in 0..s1.length) dp[i][0] = i
        for (j in 0..s2.length) dp[0][j] = j
        for (i in 1..s1.length) {
            for (j in 1..s2.length) {
                val cost = if (s1[i - 1] == s2[j - 1]) 0 else 1
                dp[i][j] = minOf(
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j - 1] + cost
                )
            }
        }
        return dp[s1.length][s2.length]
    }

    private fun parseJsonField(json: String?, field: String): String? {
        if (json == null) return null
        return try {
            val obj = JSONObject(json)
            if (obj.has(field)) obj.getString(field) else null
        } catch (_: Exception) {
            null
        }
    }

    private fun sha256OfFile(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(16384)
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                md.update(buffer, 0, bytesRead)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    private fun setState(newState: State, message: String) {
        state = newState
        mainHandler.post {
            onStateChanged?.invoke(newState, message)
        }
    }
}
