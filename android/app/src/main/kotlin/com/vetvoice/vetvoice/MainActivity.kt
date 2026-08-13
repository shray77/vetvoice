package com.vetvoice.vetvoice

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.vetvoice.vosk"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private var voskService: VoskWakeWordService? = null
    private var methodChannel: MethodChannel? = null
    private var pendingStartAfterPermission = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        // ⚠️ Фикс B-15: раньше было flutterEngine!!.dartExecutor... — если engine
        // вдруг окажется null (теоретически возможно в нестандартных сценариях),
        // приложение упадёт с NPE. Теперь используем безопасный вызов и логируем,
        // если что-то пошло не так.
        val engine = flutterEngine
        if (engine == null) {
            Log.e(TAG, "flutterEngine is null in onCreate — Vosk bridge disabled")
            return
        }
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        voskService = VoskWakeWordService(this)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    voskService?.initialize()
                    result.success(null)
                }
                "startListening" -> {
                    val currentState = voskService?.getState()
                    if (currentState == VoskWakeWordService.State.LOADING) {
                        // Модель ещё грузится — запишем что надо стартануть после
                        pendingStartAfterPermission = true
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    if (hasRecordPermission()) {
                        voskService?.startListening()
                    } else {
                        pendingStartAfterPermission = true
                        requestRecordPermission()
                    }
                    result.success(null)
                }
                "stopListening" -> {
                    voskService?.stopListening()
                    result.success(null)
                }
                "getState" -> {
                    result.success(voskService?.getState()?.name ?: "IDLE")
                }
                "dispose" -> {
                    voskService?.dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        voskService?.onStateChanged = { state, message ->
            runOnUiThread {
                methodChannel?.invokeMethod("onStateChanged", mapOf("state" to state.name, "message" to message))
            }
        }
        voskService?.onWakeWordDetected = {
            runOnUiThread {
                Log.i(TAG, "🎯 Wake word detected! Sending to Flutter...")
                methodChannel?.invokeMethod("onWakeWordDetected", null)
            }
        }
        voskService?.onPartialResult = { text ->
            runOnUiThread { methodChannel?.invokeMethod("onPartialResult", text) }
        }
        voskService?.onError = { error ->
            runOnUiThread { methodChannel?.invokeMethod("onError", error) }
        }
        voskService?.onDownloadProgress = { downloadedMB, totalMB ->
            runOnUiThread {
                methodChannel?.invokeMethod("onDownloadProgress", mapOf(
                    "downloadedMB" to downloadedMB,
                    "totalMB" to totalMB
                ))
            }
        }
        voskService?.onModelReady = {
            // Если есть отложенный старт после загрузки — запускаем
            if (pendingStartAfterPermission) {
                pendingStartAfterPermission = false
                if (hasRecordPermission()) {
                    voskService?.startListening()
                } else {
                    // Снова запрашиваем микрофон
                    pendingStartAfterPermission = true
                    requestRecordPermission()
                }
            }
        }
        voskService?.onMicReleased = {
            // Пробрасываем событие освобождения микрофона в Dart через MethodChannel
            runOnUiThread {
                Log.d(TAG, "Mic released, sending onMicReleased to Flutter")
                methodChannel?.invokeMethod("onMicReleased", null)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                if (pendingStartAfterPermission) {
                    pendingStartAfterPermission = false
                    voskService?.startListening()
                }
            } else {
                runOnUiThread { methodChannel?.invokeMethod("onError", "Разрешение на запись микрофона не получено") }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // ⚠️ Фикс B-1: полный dispose нативного Vosk-сервиса.
        // Раньше вызывался только stopListening(), что не закрывало Model (~50 МБ в RAM)
        // и не отменяло CoroutineScope — утечка через пересоздание Activity.
        // VoskWakeWordService.dispose() вызывает voskModel?.close() + scope.cancel().
        try {
            voskService?.dispose()
        } catch (e: Exception) {
            Log.w(TAG, "Vosk dispose failed: ${e.message}")
        }
        methodChannel?.setMethodCallHandler(null)
    }

    private fun hasRecordPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestRecordPermission() {
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST_CODE)
    }
}
