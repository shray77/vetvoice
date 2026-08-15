import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'voice_command_parser.dart';

// Реэкспорт моделей для обратной совместимости
export 'voice_command_parser.dart';

/// Сервис для работы с голосом (Speech-to-Text и Text-to-Speech)
/// Оптимизирован для hands-free использования ветеринарами
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSTTReady = false;
  bool _isListening = false;
  bool _continuousMode = false;
  String _lastRecognizedWords = '';
  String _statusText = 'Голос не активен';
  String _currentLocaleId = 'ru_RU';

  bool get isSTTReady => _isSTTReady;
  bool get isListening => _isListening;
  bool get continuousMode => _continuousMode;
  String get lastRecognizedWords => _lastRecognizedWords;
  String get statusText => _statusText;
  String get currentLocaleId => _currentLocaleId;

  final StreamController<String> _onWordsRecognized = StreamController<String>.broadcast();
  final StreamController<bool> _onListeningStateChanged = StreamController<bool>.broadcast();
  final StreamController<String> _onError = StreamController<String>.broadcast();
  final StreamController<VoiceCommand> _onCommand = StreamController<VoiceCommand>.broadcast();

  Stream<String> get onWordsRecognized => _onWordsRecognized.stream;
  Stream<bool> get onListeningStateChanged => _onListeningStateChanged.stream;
  Stream<String> get onError => _onError.stream;
  Stream<VoiceCommand> get onCommand => _onCommand.stream;

  Future<bool> initializeSTT() async {
    try {
      _isSTTReady = await _stt.initialize(
        onError: _handleSTTError,
        onStatus: _handleSTTStatus,
        debugLogging: false,
      );

      if (_isSTTReady) {
        final locales = await _stt.locales();
        final russianLocale = locales.firstWhere(
          (l) => l.localeId.startsWith('ru'),
          orElse: () => locales.first,
        );
        _currentLocaleId = russianLocale.localeId;
        debugPrint('🎤 STT initialized, locale: $_currentLocaleId');
      }

      return _isSTTReady;
    } catch (e) {
      _statusText = 'Ошибка STT: $e';
      debugPrint('❌ STT init error: $e');
      return false;
    }
  }

  bool _isTTSReady = false;
  bool get isTTSReady => _isTTSReady;

  Future<bool> initializeTTS({int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        await _tts.setLanguage('ru-RU');
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
        await _tts.awaitSpeakCompletion(true);

        final voices = await _tts.getVoices;
        if (voices != null && voices is List) {
          Map? russianVoice;
          Map? defaultVoice;
          for (final voice in voices) {
            if (voice is Map) {
              final locale = voice['locale']?.toString() ?? '';
              if (locale.startsWith('ru') && russianVoice == null) {
                russianVoice = voice;
              }
              defaultVoice ??= voice;
            }
          }
          final selected = russianVoice ?? defaultVoice;
          if (selected != null) {
            await _tts.setVoice({
              'name': selected['name'],
              'locale': selected['locale'],
            });
          }
        }

        _tts.setCompletionHandler(() {
          if (_continuousMode && !_isListening) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_continuousMode) startListening();
            });
          }
        });

        _tts.setErrorHandler((message) {
          _statusText = 'Ошибка озвучки: $message';
        });

        _isTTSReady = true;
        return true;
      } catch (e) {
        _isTTSReady = false;
        if (attempt < retries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
        }
      }
    }
    _onError.add('Не удалось инициализировать озвучку');
    return false;
  }

  Future<void> startListening() async {
    if (!_isSTTReady) {
      final ready = await initializeSTT();
      if (!ready) {
        _onError.add('Распознавание голоса недоступно');
        return;
      }
    }

    if (_isListening) return;

    _lastRecognizedWords = '';
    _statusText = 'Слушаю...';

    try {
      // Тактильный отклик и звуковой сигнал при старте
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      await _stt.listen(
        onResult: _handleSTTResult,
        localeId: _currentLocaleId,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

      _isListening = true;
      _onListeningStateChanged.add(true);
    } catch (e) {
      _statusText = 'Ошибка запуска: $e';
      _isListening = false;
      _onError.add('Не удалось запустить распознавание: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    await _stt.stop();
    _isListening = false;
    _statusText = 'Готово';
    _onListeningStateChanged.add(false);
    HapticFeedback.lightImpact();
  }

  void setContinuousMode(bool enabled) {
    _continuousMode = enabled;
    if (!enabled && _isListening) {
      stopListening();
    }
    _statusText = enabled ? 'Hands-free режим активен' : 'Hands-free режим выключен';
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (!_isTTSReady) {
      await initializeTTS();
      if (!_isTTSReady) return;
    }

    try {
      final cleanText = text
          .replaceAll('\n\n', '. ')
          .replaceAll('\n', ', ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      await _tts.speak(cleanText);
    } catch (_) {
      _isTTSReady = false;
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  void _handleSTTResult(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;

    if (!result.finalResult && result.recognizedWords.isNotEmpty) {
      _statusText = result.recognizedWords;
    }

    if (result.finalResult) {
      HapticFeedback.lightImpact();
      final command = VoiceCommandParser.parse(result.recognizedWords);
      if (command != null) {
        _onCommand.add(command);
        _statusText = 'Команда: ${command.type}';
      } else {
        _onWordsRecognized.add(result.recognizedWords);
        _statusText = 'Распознано';
      }

      _isListening = false;
      _onListeningStateChanged.add(false);

      if (_continuousMode) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_continuousMode && !_isListening) {
            startListening();
          }
        });
      }
    }
  }

  void _handleSTTError(SpeechRecognitionError error) {
    _isListening = false;
    _statusText = 'Ошибка: ${error.errorMsg}';
    _onListeningStateChanged.add(false);

    if (_continuousMode && error.permanent != true) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_continuousMode && !_isListening) {
          startListening();
        }
      });
    } else {
      _onError.add(error.errorMsg);
    }
  }

  void _handleSTTStatus(String status) {
    switch (status) {
      case 'listening':
        _statusText = 'Слушаю...';
        break;
      case 'notListening':
        _statusText = 'Не слушаю';
        _isListening = false;
        _onListeningStateChanged.add(false);
        break;
      case 'done':
        _statusText = 'Готово';
        _isListening = false;
        _onListeningStateChanged.add(false);
        break;
    }
  }

  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stt.cancel();
    _tts.stop();
    if (!_onWordsRecognized.isClosed) _onWordsRecognized.close();
    if (!_onListeningStateChanged.isClosed) _onListeningStateChanged.close();
    if (!_onError.isClosed) _onError.close();
    if (!_onCommand.isClosed) _onCommand.close();
  }
}
