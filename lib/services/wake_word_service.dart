import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Сервис wake word detection через Vosk (офлайн, через MethodChannel).
/// Синглтон — живёт на протяжении всей жизни приложения,
/// не пересоздаётся при переключении экранов.
class WakeWordService {
  static const MethodChannel _channel = MethodChannel('com.vetvoice.vosk');

  // Синглтон
  static final WakeWordService _instance = WakeWordService._internal();
  static WakeWordService get instance => _instance;
  factory WakeWordService() => _instance;
  WakeWordService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Состояния зеркалят VoskWakeWordService.State (Kotlin)
  String _state = 'IDLE';
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isModelLoading = false;
  String? _errorMessage;
  String _lastHeard = '';

  // Прогресс загрузки
  double _downloadedMB = 0;
  double _totalMB = 0;
  bool _isExtracting = false;
  String _loadingMessage = '';

  // Флаг: пользователь включил wake word и ждёт когда модель загрузится
  bool _pendingStartWhenReady = false;

  // Callback: вызывается когда Vosk реально освободил микрофон
  VoidCallback? _onMicReleased;

  // Геттеры
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isModelLoading => _isModelLoading;
  String? get errorMessage => _errorMessage;
  String get lastHeard => _lastHeard;
  double get downloadedMB => _downloadedMB;
  double get totalMB => _totalMB;
  bool get isExtracting => _isExtracting;
  String get state => _state;
  String get loadingMessage => _loadingMessage;

  // Контроллеры стримов
  final StreamController<void> _onWakeWord = StreamController<void>.broadcast();
  final StreamController<String> _onError = StreamController<String>.broadcast();
  final StreamController<bool> _onListeningStateChanged = StreamController<bool>.broadcast();
  final StreamController<String> _onPartialResult = StreamController<String>.broadcast();
  final StreamController<void> _onDownloadProgress = StreamController<void>.broadcast();

  Stream<void> get onWakeWord => _onWakeWord.stream;
  Stream<String> get onError => _onError.stream;
  Stream<bool> get onListeningStateChanged => _onListeningStateChanged.stream;
  Stream<String> get onPartialResult => _onPartialResult.stream;
  Stream<void> get onDownloadProgress => _onDownloadProgress.stream;

  /// Обработка коллбеков из Android-сервиса
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStateChanged':
        final args = call.arguments;
        if (args is Map) {
          final newState = (args['state'] as String?) ?? 'IDLE';
          final message = (args['message'] as String?) ?? '';
          _handleStateChanged(newState, message);
        }
        break;

      case 'onWakeWordDetected':
        debugPrint('🎯 [Dart] Wake word received from native!');
        _onWakeWord.add(null);
        break;

      case 'onPartialResult':
        final text = (call.arguments as String?) ?? '';
        _lastHeard = text;
        _onPartialResult.add(text);
        break;

      case 'onError':
        final error = (call.arguments as String?) ?? 'Неизвестная ошибка';
        _errorMessage = error;
        _onError.add(error);
        debugPrint('❌ [Dart] Vosk error: $error');
        break;

      case 'onDownloadProgress':
        final args = call.arguments;
        if (args is Map) {
          _downloadedMB = (args['downloadedMB'] as num?)?.toDouble() ?? 0;
          _totalMB = (args['totalMB'] as num?)?.toDouble() ?? 0;
          _onDownloadProgress.add(null);
        }
        break;

      case 'onMicReleased':
        debugPrint('✅ [Dart] Microphone released by Vosk');
        _onMicReleased?.call();
        break;
    }
  }

  void _handleStateChanged(String newState, String message) {
    debugPrint('🎤 [Dart] Vosk state: $newState — $message');

    // Обновляем текст этапа загрузки
    if (newState == 'LOADING') {
      _loadingMessage = message;
      _isExtracting = message.contains('Распаковка') || message.contains('файл');
    }

    final wasListening = _isListening;

    _state = newState;

    switch (newState) {
      case 'IDLE':
        _isListening = false;
        _isInitialized = false;
        _isModelLoading = false;
        break;
      case 'LOADING':
        _isModelLoading = true;
        _isListening = false;
        _isInitialized = false;
        _errorMessage = null;
        break;
      case 'READY':
        _isModelLoading = false;
        _isInitialized = true;
        _isListening = false;
        _isExtracting = false;
        _errorMessage = null;
        _downloadedMB = 0;
        _totalMB = 0;
        // Если пользователь включил wake word пока модель грузилась — стартуем
        if (_pendingStartWhenReady) {
          _pendingStartWhenReady = false;
          debugPrint('🎤 [Dart] Model ready, auto-starting listening...');
          startListening();
        }
        break;
      case 'LISTENING':
        _isModelLoading = false;
        _isInitialized = true;
        _isListening = true;
        _isExtracting = false;
        _errorMessage = null;
        _downloadedMB = 0;
        _totalMB = 0;
        break;
      case 'ERROR':
        _isModelLoading = false;
        _errorMessage = message;
        _isListening = false;
        _pendingStartWhenReady = false;
        break;
    }

    if (wasListening != _isListening) {
      _onListeningStateChanged.add(_isListening);
    }
  }

  /// Установить callback для события освобождения микрофона.
  /// Вызывается после того как Vosk реально остановил AudioRecord.
  void setMicReleaseCallback(VoidCallback callback) {
    _onMicReleased = callback;
  }

  /// Снять callback освобождения микрофона.
  void clearMicReleaseCallback() {
    _onMicReleased = null;
  }

  /// Инициализация Vosk — проверяет/скачивает модель.
  /// Повторяет до [maxRetries] раз с exponential backoff при ошибке.
  Future<bool> initialize({int maxRetries = 3}) async {
    if (_isInitialized) return true;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint('🎤 [Dart] Initializing Vosk (attempt ${attempt + 1}/$maxRetries)...');

        final currentState = await _channel.invokeMethod<String?>('getState');
        if (currentState != null && (currentState == 'READY' || currentState == 'LISTENING')) {
          _handleStateChanged(currentState, '');
          return true;
        }

        // Если уже грузится — просто ждём
        if (currentState == 'LOADING') {
          _handleStateChanged('LOADING', '');
          return false;
        }

        await _channel.invokeMethod('initialize');

        // Ждём немного и проверяем состояние
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500));
          final checkState = await _channel.invokeMethod<String?>('getState');
          if (checkState == 'READY' || checkState == 'LISTENING' || _isInitialized) {
            return true;
          }
          // Exponential backoff: 2s, 4s, 8s
          final delaySeconds = 2 * (1 << attempt);
          debugPrint('⚠️ [Dart] Vosk not ready, retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          return _isInitialized;
        }
      } catch (e) {
        debugPrint('⚠️ [Dart] Vosk init attempt ${attempt + 1} failed: $e');
        if (attempt < maxRetries - 1) {
          final delaySeconds = 2 * (1 << attempt);
          debugPrint('⚠️ [Dart] Retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }

    _errorMessage = 'Не удалось загрузить модель. Попробуйте позже.';
    debugPrint('❌ [Dart] Vosk init failed after $maxRetries attempts');
    _onError.add(_errorMessage!);
    return false;
  }

  /// Начать прослушивание wake word.
  Future<void> startListening() async {
    if (!_isInitialized) {
      if (_isModelLoading) {
        // Модель грузится — запомним что надо стартануть когда будет готово
        _pendingStartWhenReady = true;
        debugPrint('🎤 [Dart] Model loading, will start listening when ready');
        return;
      }
      final initialized = await initialize();
      if (!initialized && _isModelLoading) {
        _pendingStartWhenReady = true;
        return;
      }
      if (!_isInitialized) return;
    }

    if (_isListening) {
      debugPrint('🎤 [Dart] Already listening');
      return;
    }

    try {
      debugPrint('🎤 [Dart] Starting Vosk listening...');
      await _channel.invokeMethod('startListening');
    } catch (e) {
      debugPrint('❌ [Dart] Start listening error: $e');
      _onError.add('Ошибка запуска: $e');
    }
  }

  /// Остановить прослушивание.
  /// Вызывает [_onMicReleased] callback после реального освобождения микрофона.
  Future<void> stopListening() async {
    _pendingStartWhenReady = false;
    if (!_isListening) {
      // Если не слушали — всё равно вызываем callback (микрофон свободен)
      _onMicReleased?.call();
      return;
    }

    try {
      await _channel.invokeMethod('stopListening');
      debugPrint('🔇 [Dart] Vosk listening stopped, mic release callback will be called from native');
      // Callback onMicReleased будет вызван из нативного слоя через MethodChannel
      // Событие 'onMicReleased' обрабатывается в _handleMethodCall
    } catch (e) {
      debugPrint('❌ [Dart] Stop error: $e');
      // Даже при ошибке вызываем callback чтобы не заблокировать STT
      _onMicReleased?.call();
    }
  }

  /// Останавливает прослушивание, но НЕ закрывает StreamController'ы,
  /// т.к. это синглтон — закрытые стримы больше нельзя использовать.
  /// Нативный VoskService живёт пока жива Activity.
  void dispose() {
    stopListening();
    clearMicReleaseCallback();
  }
}

/// Информация о wake word для UI
class WakeWordInfo {
  static const String wakeWordName = 'ВетВойс';

  static const String instructions = '''
Wake Word работает через Vosk — офлайн распознавание речи.

Скажите "ВетВойс" для активации голосового ввода.
Например: "ВетВойс, собака 15 кг амоксициллин"

Работает БЕЗ интернета.

Первый запуск: скачивается модель (~50 МБ).
Далее — модель кешируется и обновляется раз в неделю.

Советы:
- Говорите чётко: "ВЕТ-ВОЙС"
- Можно сказать "вет помощь" или просто "ветеринар"
- Работает даже без связи!
''';
}
