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
    // v1.20.1 (VV-036): Future загрузки persist-флага СОХРАНЯЕМ (раньше
    // fire-and-forget): до его завершения shouldUseForRecognition ложно,
    // и первый микрофон мог уйти на системный STT вместо офлайн-движка.
    // Читается через ensurePrefsLoaded()/setEnabled().
    _enabledFuture = _loadEnabled();
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
  // v1.20.1 (VV-036): Future загрузки флага из prefs (присваивается в
  // конструкторе). Раньше bool _prefsLoaded нигде не читался, а гонка
  // «конструктор vs setEnabled» перезаписывала свежий флаг устаревшим.
  late final Future<void> _enabledFuture;
  // v1.20.1 (VV-036): мемоизация in-flight запуска — параллельные вызовы
  // initialize() (тумблер в настройках + кнопка «Загрузить» в карточке)
  // получают один и тот же Future, дубль нативной загрузки невозможен.
  final InFlightFuture<bool> _initializeInFlight = InFlightFuture<bool>();
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

  /// Дождаться загрузки persist-флага движка из SharedPreferences
  /// (запускается в конструкторе). Вызывается перед выбором движка в
  /// SpeechService.startListening — до загрузки флага
  /// shouldUseForRecognition ложно и первый микрофон ошибочно ушёл бы
  /// на системный STT (v1.20.1, VV-036).
  Future<void> ensurePrefsLoaded() => _enabledFuture;

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
    } catch (e) {
      debugPrint('⚠️ [Dart] GigaAM prefs load failed: $e');
    }
  }

  /// Включить/выключить GigaAM как движок распознавания (persist).
  Future<void> setEnabled(bool value) async {
    // v1.20.1 (VV-036): сначала ждём загрузку prefs — иначе поздно
    // завершившийся _loadEnabled мог перезаписать только что
    // выставленное значение устаревшим persisted-флагом.
    await _enabledFuture;
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
    // v1.20.1 (VV-070): после dispose контроллеры закрыты — ни одного
    // нативного события больше не публикуем (handler к тому же снят).
    if (_disposed) return null;
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
    if (_disposed) return; // v1.20.1 (VV-070): после dispose стримы закрыты
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
  ///
  /// v1.20.1 (VV-036): мемоизация in-flight Future — параллельные вызовы
  /// (setEnabled(true) + кнопка «Загрузить» в карточке настроек) получают
  /// один и тот же Future, и нативный initialize() не дёргается дважды
  /// (дубль загрузки модели невозможен). Параметр [maxRetries] берётся из
  /// ПЕРВОГО вызова в серии — последующие до его завершения игнорируются.
  Future<bool> initialize({int maxRetries = 3}) =>
      _initializeInFlight.run(() => _doInitialize(maxRetries));

  Future<bool> _doInitialize(int maxRetries) async {
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

  // v1.20.1 (VV-070): признак окончательного dispose
  bool _disposed = false;

  /// v1.20.1 (VV-070): раньше dispose() делал только fire-and-forget
  /// stopTranscribe() — четыре broadcast-контроллера и method call
  /// handler оставались жить (утечка подписчиков, гонка с колбэками,
  /// которые ещё пишут в стримы). Теперь: сразу снимаем handler (ни
  /// одного нативного события больше не придёт), останавливаем запись
  /// аккуратно (best-effort с разумным таймаутом, как в
  /// WakeWordService.dispose), затем закрываем контроллеры. Сигнатура
  /// осталась синхронной — вызовы dispose() никто не await-ит.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _channel.setMethodCallHandler(null);
    unawaited(_disposeImpl());
  }

  Future<void> _disposeImpl() async {
    try {
      await stopTranscribe().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('⚠️ [Dart] GigaAM dispose: stop не завершился за 2 с: $e');
    }
    _onStateChanged.close();
    _onResult.close();
    _onError.close();
    _onDownloadProgress.close();
    debugPrint('🔇 [Dart] GigaAmService disposed');
  }
}

/// v1.20.1 (VV-036): мемоизация in-flight Future. Параллельные вызовы
/// [run] пока задача выполняются получают ОДИН и тот же Future — задача
/// (например, нативная загрузка модели GigaAM) запускается ровно один
/// раз; после завершения следующий вызов запускает её заново.
@visibleForTesting
class InFlightFuture<T> {
  Future<T>? _inFlight;

  /// Запущена ли сейчас мемоизированная задача.
  @visibleForTesting
  bool get isRunning => _inFlight != null;

  Future<T> run(Future<T> Function() task) {
    final existing = _inFlight;
    if (existing != null) return existing;
    late final Future<T> future;
    future = task().whenComplete(() {
      // Сбрасываем только СВОЙ Future — чужой (новый) не трогаем.
      if (identical(_inFlight, future)) _inFlight = null;
    });
    _inFlight = future;
    return future;
  }
}
