import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис офлайн-распознавания речи GigaAM-v3-CTC (Сбер) через ONNX Runtime.
/// v1.20.0: качественная транскрипция высказывания (не стриминг) — движок
/// для голосового ввода дозировок после wake word или кнопки микрофона.
///
/// Разделение труда:
///   • Vosk (WakeWordService) — стриминговый wake word «ВетВойс» (44 МБ);
///   • GigaAM (этот сервис) — точное офлайн-распознавание команды (~216 МБ).
///
/// Паттерн тот же, что у WakeWordService (v1.16.2-уроки): initialize() НЕ
/// блокирует и НЕ ретраит ожиданием загрузки — статус приходит через стрим
/// onStateChanged; повторные вызовы не обрывают идущее скачивание.
class GigaAmService {
  static const MethodChannel _channel = MethodChannel('com.vetvoice.gigaam');

  // Синглтон
  static final GigaAmService _instance = GigaAmService._internal();
  static GigaAmService get instance => _instance;
  GigaAmService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _loadEnabled();
  }
  factory GigaAmService() => _instance;

  // Состояния зеркалят GigaAmSttService.State (Kotlin)
  static const String stateIdle = 'IDLE';
  static const String stateLoading = 'LOADING';
  static const String stateReady = 'READY';
  static const String stateRecording = 'RECORDING';
  static const String stateRecognizing = 'RECOGNIZING';
  static const String stateError = 'ERROR';

  String _state = stateIdle;
  bool _enabled = false; // использовать GigaAM как движок распознавания
  bool _prefsLoaded = false;
  String? _errorMessage;
  String _loadingMessage = '';

  // Прогресс скачивания
  double _downloadedMB = 0;
  double _totalMB = 0;

  // Геттеры
  String get state => _state;
  bool get isEnabled => _enabled;
  bool get isModelLoading => _state == stateLoading;
  bool get isReady => _state == stateReady || _state == stateRecording || _state == stateRecognizing;
  bool get isActive => _state == stateRecording || _state == stateRecognizing;
  String? get errorMessage => _errorMessage;
  String get loadingMessage => _loadingMessage;
  double get downloadedMB => _downloadedMB;
  double get totalMB => _totalMB;

  /// Офлайн-движок выбран пользователем и модель готова к работе.
  bool get shouldUseForRecognition => _enabled && isReady;

  // Контроллеры стримов
  final StreamController<String> _onStateChanged =
      StreamController<String>.broadcast();
  final StreamController<String> _onResult =
      StreamController<String>.broadcast();
  final StreamController<String> _onError =
      StreamController<String>.broadcast();
  final StreamController<void> _onDownloadProgress =
      StreamController<void>.broadcast();

  Stream<String> get onStateChanged => _onStateChanged.stream;
  Stream<String> get onResult => _onResult.stream;
  Stream<String> get onError => _onError.stream;
  Stream<void> get onDownloadProgress => _onDownloadProgress.stream;

  Future<void> _loadEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('use_gigaam_engine') ?? false;
      _prefsLoaded = true;
    } catch (e) {
      debugPrint('⚠️ [Dart] GigaAM prefs load failed: $e');
    }
  }

  /// Включить/выключить GigaAM как движок распознавания (persist).
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_gigaam_engine', value);
    } catch (e) {
      debugPrint('⚠️ [Dart] GigaAM prefs save failed: $e');
    }
    // Включили при уже скачанной модели — готовим сессии заранее
    if (value && _state == stateIdle) {
      initialize();
    }
  }

  /// Обработка коллбеков из Android-сервиса
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onGigaAmStateChanged':
        final args = call.arguments;
        if (args is Map) {
          final newState = (args['state'] as String?) ?? stateIdle;
          final message = (args['message'] as String?) ?? '';
          _handleStateChanged(newState, message);
        }
        break;

      case 'onGigaAmResult':
        final text = (call.arguments as String?) ?? '';
        debugPrint('🎤 [Dart] GigaAM result: $text');
        _onResult.add(text);
        break;

      case 'onGigaAmError':
        final error = (call.arguments as String?) ?? 'Неизвестная ошибка';
        _errorMessage = error;
        _onError.add(error);
        debugPrint('❌ [Dart] GigaAM error: $error');
        break;

      case 'onGigaAmDownloadProgress':
        final args = call.arguments;
        if (args is Map) {
          _downloadedMB = (args['downloadedMB'] as num?)?.toDouble() ?? 0;
          _totalMB = (args['totalMB'] as num?)?.toDouble() ?? 0;
          _onDownloadProgress.add(null);
        }
        break;
    }
    return null;
  }

  void _handleStateChanged(String newState, String message) {
    debugPrint('🎤 [Dart] GigaAM state: $newState — $message');
    _state = newState;
    if (newState == stateLoading) {
      _loadingMessage = message;
    }
    if (newState == stateReady || newState == stateRecording) {
      _errorMessage = null;
      _downloadedMB = 0;
      _totalMB = 0;
    }
    if (newState == stateError) {
      _errorMessage = message.isNotEmpty ? message : _errorMessage;
    }
    _onStateChanged.add(newState);
  }

  /// Проверить нативное состояние (при старте приложения).
  Future<void> refreshState() async {
    try {
      final s = await _channel.invokeMethod<String?>('getState');
      if (s != null && s != stateIdle) {
        _handleStateChanged(s, '');
      }
    } catch (e) {
      debugPrint('⚠️ [Dart] GigaAM getState failed: $e');
    }
  }

  /// Не блокирующий запуск подготовки: скачивание и/или загрузка сессий.
  /// Готовность приходит через onStateChanged (паттерн v1.16.2).
  Future<bool> initialize({int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final currentState =
            await _channel.invokeMethod<String?>('getState');
        if (currentState == stateReady || currentState == stateRecording) {
          _handleStateChanged(currentState!, '');
          return true;
        }
        if (currentState == stateLoading || _state == stateLoading) {
          // Уже качается/грузится — ждём событий
          _handleStateChanged(stateLoading, _loadingMessage);
          return false;
        }
        await _channel.invokeMethod('initialize');
        return false; // фон; READY/ERROR придут через стрим
      } catch (e) {
        debugPrint('⚠️ [Dart] GigaAM init attempt ${attempt + 1} failed: $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (1 << attempt)));
        }
      }
    }
    _errorMessage = 'Не удалось запустить загрузку модели GigaAM';
    _onError.add(_errorMessage!);
    return false;
  }

  /// Записать и распознать высказывание офлайн.
  /// Результат придёт через [onResult], ошибки — через [onError].
  Future<void> startTranscribe() async {
    try {
      await _channel.invokeMethod('startTranscribe');
    } catch (e) {
      debugPrint('❌ [Dart] GigaAM startTranscribe error: $e');
      _onError.add('Ошибка запуска распознавания: $e');
    }
  }

  /// Ручная остановка записи.
  Future<void> stopTranscribe() async {
    try {
      await _channel.invokeMethod('stopTranscribe');
    } catch (e) {
      debugPrint('❌ [Dart] GigaAM stopTranscribe error: $e');
    }
  }

  /// Модель скачана на диск (без загрузки в память).
  Future<bool> isModelDownloaded() async {
    try {
      return await _channel.invokeMethod<bool>('isModelDownloaded') ?? false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    stopTranscribe();
  }
}
