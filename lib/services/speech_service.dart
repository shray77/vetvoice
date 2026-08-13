import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Сервис для работы с голосом (Speech-to-Text и Text-to-Speech)
/// Оптимизирован для hands-free использования ветеринарами
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSTTReady = false;
  bool _isListening = false;
  bool _continuousMode = false; // Hands-free режим
  String _lastRecognizedWords = '';
  String _statusText = 'Голос не активен';
  String _currentLocaleId = 'ru_RU'; // Сохраняем выбранную локаль

  // Геттеры
  bool get isSTTReady => _isSTTReady;
  bool get isListening => _isListening;
  bool get continuousMode => _continuousMode;
  String get lastRecognizedWords => _lastRecognizedWords;
  String get statusText => _statusText;
  String get currentLocaleId => _currentLocaleId;

  // Контроллеры стримов
  final StreamController<String> _onWordsRecognized = StreamController<String>.broadcast();
  final StreamController<bool> _onListeningStateChanged = StreamController<bool>.broadcast();
  final StreamController<String> _onError = StreamController<String>.broadcast();
  final StreamController<VoiceCommand> _onCommand = StreamController<VoiceCommand>.broadcast();

  Stream<String> get onWordsRecognized => _onWordsRecognized.stream;
  Stream<bool> get onListeningStateChanged => _onListeningStateChanged.stream;
  Stream<String> get onError => _onError.stream;
  Stream<VoiceCommand> get onCommand => _onCommand.stream;

  /// Инициализация STT
  Future<bool> initializeSTT() async {
    try {
      _isSTTReady = await _stt.initialize(
        onError: _handleSTTError,
        onStatus: _handleSTTStatus,
        debugLogging: true,
      );

      if (_isSTTReady) {
        // Устанавливаем русский язык по умолчанию
        final locales = await _stt.locales();
        final russianLocale = locales.firstWhere(
          (l) => l.localeId.startsWith('ru'),
          orElse: () => locales.first,
        );
        _currentLocaleId = russianLocale.localeId;
        debugPrint('🎤 STT initialized, locale: $_currentLocaleId, available: ${locales.length}');
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

  /// Инициализация TTS с retry логикой
  /// При неудаче повторяет до [retries] раз с exponential backoff
  Future<bool> initializeTTS({int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        debugPrint('🔊 TTS init attempt ${attempt + 1}/$retries');

        // Сначала проверяем доступность TTS двигателя
        final engines = await _tts.getEngines;
        debugPrint('🔊 TTS Engines available: $engines');

        // Устанавливаем базовые параметры
        await _tts.setLanguage('ru-RU');
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);

        // Ждём завершения озвучивания (важно для hands-free режима)
        await _tts.awaitSpeakCompletion(true);

        // Получаем доступные голоса и выбираем русский
        final voices = await _tts.getVoices;
        debugPrint('🔊 Available voices: ${voices?.length ?? 0}');

        if (voices != null && voices is List) {
          Map? russianVoice;
          Map? englishVoice;
          Map? defaultVoice;

          for (final voice in voices) {
            if (voice is Map) {
              final locale = voice['locale']?.toString() ?? '';
              final name = voice['name']?.toString() ?? '';
              debugPrint('🔊 Voice: $name, locale: $locale');

              // Ищем русский голос
              if (locale.startsWith('ru') && russianVoice == null) {
                russianVoice = voice;
              }
              // Ищем английский как fallback
              else if (locale.startsWith('en') && englishVoice == null) {
                englishVoice = voice;
              }
              // Запоминаем первый голос как fallback
              if (defaultVoice == null) {
                defaultVoice = voice;
              }
            }
          }

          // Выбираем голос в порядке приоритета
          final selectedVoice = russianVoice ?? englishVoice ?? defaultVoice;
          if (selectedVoice != null) {
            await _tts.setVoice({
              'name': selectedVoice['name'],
              'locale': selectedVoice['locale']
            });
            debugPrint('🔊 Selected voice: ${selectedVoice['name']} (${selectedVoice['locale']})');
          }
        }

        // Слушаем завершение озвучивания для hands-free режима
        _tts.setCompletionHandler(() {
          debugPrint('🔊 TTS completed');
          if (_continuousMode && !_isListening) {
            // Автоматически продолжаем слушать после озвучивания
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_continuousMode) startListening();
            });
          }
        });

        // Обработчик ошибок TTS
        _tts.setErrorHandler((message) {
          debugPrint('❌ TTS Error: $message');
          _statusText = 'Ошибка озвучки: $message';
        });

        // Обработчик начала озвучивания
        _tts.setStartHandler(() {
          debugPrint('🔊 TTS started speaking');
        });

        _isTTSReady = true;
        debugPrint('✅ TTS initialized successfully');
        return true;

      } catch (e) {
        debugPrint('⚠️ TTS init attempt ${attempt + 1} failed: $e');
        _isTTSReady = false;
        if (attempt < retries - 1) {
          // Exponential backoff: 500ms, 1000ms, 2000ms
          final delayMs = 500 * (1 << attempt);
          debugPrint('⚠️ Retrying TTS init in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }
    // Все попытки провалились
    final errorMsg = 'Не удалось инициализировать озвучку. Проверьте настройки TTS.';
    debugPrint('❌ TTS init failed after $retries attempts');
    _onError.add(errorMsg);
    return false;
  }

  /// Начать прослушивание
  Future<void> startListening() async {
    if (!_isSTTReady) {
      final ready = await initializeSTT();
      if (!ready) {
        _onError.add('Распознавание голоса недоступно');
        return;
      }
    }

    if (_isListening) {
      debugPrint('🎤 Already listening, skipping');
      return;
    }

    _lastRecognizedWords = '';
    _statusText = 'Слушаю...';

    try {
      await _stt.listen(
        onResult: _handleSTTResult,
        localeId: _currentLocaleId, // КРИТИЧЕСКИ ВАЖНО — без этого слушает на системном языке!
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

      _isListening = true;
      _onListeningStateChanged.add(true);
      debugPrint('🎤 Started listening (locale=$_currentLocaleId)');
    } catch (e) {
      _statusText = 'Ошибка запуска: $e';
      _isListening = false;
      debugPrint('❌ STT listen error: $e');
      _onError.add('Не удалось запустить распознавание: $e');
    }
  }

  /// Остановить прослушивание
  Future<void> stopListening() async {
    if (!_isListening) return;

    await _stt.stop();
    _isListening = false;
    _statusText = 'Готово';
    _onListeningStateChanged.add(false);
  }

  /// Включить/выключить hands-free режим
  void setContinuousMode(bool enabled) {
    _continuousMode = enabled;
    if (!enabled && _isListening) {
      stopListening();
    }
    _statusText = enabled ? 'Hands-free режим активен' : 'Hands-free режим выключен';
  }

  /// Озвучить текст
  Future<void> speak(String text) async {
    if (text.isEmpty) {
      debugPrint('🔊 speak: empty text, skipping');
      return;
    }

    if (!_isTTSReady) {
      debugPrint('⚠️ TTS not ready, reinitializing...');
      await initializeTTS();
      if (!_isTTSReady) {
        debugPrint('❌ TTS reinitialization failed, cannot speak');
        return;
      }
    }

    try {
      // Убираем переносы строк - TTS их не озвучивает
      // Заменяем на паузу через точку или запятую
      final cleanText = text
          .replaceAll('\n\n', '. ')  // Двойной перенос = пауза
          .replaceAll('\n', ', ')     // Одиночный перенос = короткая пауза
          .replaceAll(RegExp(r'\s+'), ' ')  // Убираем лишние пробелы
          .trim();
      
      debugPrint('🔊 Speaking: $cleanText');
      final result = await _tts.speak(cleanText);
      debugPrint('🔊 speak result: $result');
    } catch (e) {
      debugPrint('❌ speak error: $e');
      // Пробуем переинициализировать при ошибке
      _isTTSReady = false;
    }
  }

  /// Остановить озвучивание
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  /// Обработка результата распознавания
  void _handleSTTResult(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;

    // Показываем partial results для визуальной обратной связи
    if (!result.finalResult && result.recognizedWords.isNotEmpty) {
      _statusText = result.recognizedWords;
      debugPrint('🎤 partial: ${result.recognizedWords}');
    }

    if (result.finalResult) {
      debugPrint('🎤 final: ${result.recognizedWords}');
      // Проверяем на голосовые команды
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

      // В hands-free режиме продолжаем слушать после обработки
      if (_continuousMode) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_continuousMode && !_isListening) {
            startListening();
          }
        });
      }
    }
  }

  /// Обработка ошибок STT
  void _handleSTTError(SpeechRecognitionError error) {
    debugPrint('❌ STT error: ${error.errorMsg} (permanent=${error.permanent})');
    _isListening = false;
    _statusText = 'Ошибка: ${error.errorMsg}';
    _onListeningStateChanged.add(false);
    
    // В hands-free режиме пробуем восстановиться
    if (_continuousMode && error.permanent != true) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_continuousMode && !_isListening) {
          startListening();
        }
      });
    } else if (error.permanent != true) {
      // Для не-permanent ошибок уведомляем подписчика — home_screen решит что делать
      // (например, перезапустить Vosk после STT сессии)
      _onError.add(error.errorMsg);
    } else {
      _onError.add(error.errorMsg);
    }
  }

  /// Обработка статуса STT
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

  /// Освобождение ресурсов. Безопасно вызывать несколько раз.
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

/// Голосовая команда
class VoiceCommand {
  final VoiceCommandType type;
  final String? parameter;

  const VoiceCommand(this.type, [this.parameter]);

  @override
  String toString() => 'VoiceCommand($type${parameter != null ? ', $parameter' : ''})';
}

/// Типы голосовых команд
enum VoiceCommandType {
  stop,        // "стоп", "хватит", "остановись"
  repeat,      // "повтори", "ещё раз"
  reset,       // "сброс", "новый расчёт", "заново"
  help,        // "помощь", "что умеешь"
  continuous,  // "hands-free", "режим без рук"
  animal,      // Выбор животного
  speakResult, // "озвучь результат", "скажи дозу"
  earMode,     // "ухо", "слушай", "включи ухо"
}

/// Парсер голосовых команд
class VoiceCommandParser {
  static final Map<VoiceCommandType, List<String>> _commands = {
    VoiceCommandType.stop: ['стоп', 'хватит', 'остановись', 'остановить', 'прекрати', 'выключи'],
    VoiceCommandType.repeat: ['повтори', 'ещё раз', 'повторить', 'скажи ещё'],
    VoiceCommandType.reset: ['сброс', 'новый расчёт', 'заново', 'очистить', 'сначала', 'новый'],
    VoiceCommandType.help: ['помощь', 'что умеешь', 'помоги', 'команды', 'инструкция'],
    VoiceCommandType.continuous: ['hands-free', 'без рук', 'режим без рук', 'свободные руки', 'автоматический режим'],
    VoiceCommandType.speakResult: ['скажи дозу', 'озвучь результат', 'сколько давать', 'напомни дозу', 'произнеси'],
    VoiceCommandType.earMode: ['ухо', 'слушай', 'включи ухо', 'слушать', 'начни слушать', 'голосовой режим'],
  };

  static VoiceCommand? parse(String input) {
    final lower = input.toLowerCase().trim();
    
    for (final entry in _commands.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return VoiceCommand(entry.key);
        }
      }
    }
    
    return null;
  }
}

/// Парсер голосового ввода - расширенная версия для ветеринаров
class VoiceInputParser {
  // ==========================================
  // ВСЕ ЖИВОТНЫЕ С ИХ АЛИАСАМИ
  // ==========================================
  static final Map<String, List<String>> _animalKeywords = {
    // КРС - крупный рогатый скот
    'cattle': [
      'крс', 'корова', 'коровы', 'корове', 'корову', 'коровой',
      'бык', 'быка', 'быку', 'быком',
      'теленок', 'телёнок', 'теленка', 'телёнка', 'теленку', 'телёнку',
      'телка', 'тёлка', 'телки', 'тёлки',
      'скот', 'скота', 'скоту',
      'бурёнка', 'буренка', 'бурёнки', 'буренки',
      'крупный рогатый', 'рогатый скот',
    ],
    // МРС - мелкий рогатый скот (овцы и козы)
    'sheep': [
      'овца', 'овцы', 'овце', 'овцу', 'овцой',
      'баран', 'барана', 'барану', 'бараном',
      'ягненок', 'ягнёнок', 'ягненка', 'ягнёнка', 'ягненку', 'ягнёнку',
      'коза', 'козы', 'козе', 'козу', 'козой',
      'козел', 'козёл', 'козла', 'козлу',
      'козленок', 'козлёнок', 'козленка', 'козлёнка',
      'мрс', 'мелкий рогатый', 'мелкий скот',
    ],
    // Лошади
    'horse': [
      'лошадь', 'лошади', 'лошадь', 'лошадью',
      'конь', 'коня', 'коню', 'конём',
      'пони',
      'жеребенок', 'жеребёнок', 'жеребенка', 'жеребёнка', 'жеребенку', 'жеребёнку',
      'мерин', 'мерина', 'мерину',
      'кобыла', 'кобылы', 'кобыле', 'кобылу',
      'жеребец', 'жеребца', 'жеребцу',
    ],
    // Свиньи
    'pig': [
      'свинья', 'свиньи', 'свинье', 'свинью', 'свиньей',
      'свин', 'свином',
      'хряк', 'хряка', 'хряку', 'хряком',
      'поросенок', 'поросёнок', 'поросенка', 'поросёнка', 'поросенку', 'поросёнку',
      'кабан', 'кабана', 'кабану',
    ],
    // Птицы
    'poultry': [
      'птица', 'птицы', 'птице', 'птицу', 'птицей',
      'птиц', 'птичий', 'птичья',
      'курица', 'курицы', 'курице', 'курицу', 'курицей',
      'куры', 'кур', 'курам', 'курами',
      'петух', 'петуха', 'петуху', 'петухом',
      'цыплёнок', 'цыпленок', 'цыпленка', 'цыплёнка', 'цыпленку', 'цыплёнку',
      'утка', 'утки', 'утке', 'утку', 'уткой',
      'гусь', 'гуся', 'гусям', 'гусем',
      'индейка', 'индейки', 'индейке', 'индейку',
      'индюк', 'индюка', 'индюку',
      'индюшонок', 'индюшонка', 'индюшат',
    ],
    // Собаки
    'dog': [
      'собака', 'собаки', 'собаке', 'собаку', 'собакой',
      'пёс', 'пес', 'пса', 'псу', 'псом',
      'щенок', 'щенка', 'щенку', 'щенком',
      'собачий', 'собачья',
      'кобель', 'кобеля', 'кобелю',  // это и пол
      'сука', 'суки', 'сук', 'суке',  // это и пол
    ],
    // Кошки
    'cat': [
      'кошка', 'кошки', 'кошке', 'кошку', 'кошкой',
      'кот', 'кота', 'коту', 'котом',
      'котёнок', 'котенок', 'котенка', 'котёнка', 'котенку', 'котёнку',
      'кис', 'киса', 'кисы', 'кису',
      'мурка', 'мурки', 'мурке', 'мурку',
      'кошачий', 'кошачья',
    ],
    // Кролики (и пушные звери — это одно и то же для голосового ввода,
    // препараты в базе после фикса тоже пересекаются)
    'rabbit': [
      'кролик', 'кролика', 'кролику', 'кроликом', 'кролики', 'кроликов',
      'крольчиха', 'крольчихи', 'крольчиху',
      'крольчонок', 'крольчонка', 'крольчата',
      'пушной', 'пушного', 'пушные', 'пушных', 'пушным',
      'пушной зверь', 'пушные звери', 'пушных зверей',
      'нутрия', 'нутрии', 'нутрию',
      'песец', 'песца', 'песцу',
      'лиса', 'лисы', 'лису', 'лисой',
      'лисица', 'лисицы', 'лисицу',
      'соболь', 'соболя', 'соболю',
      'хорек', 'хорь', 'хорька', 'хорьку',
      'норка', 'норки', 'норку',
      'шиншилла', 'шиншиллы', 'шиншиллу',
    ],
  };

  // ==========================================
  // ПОЛ - БЕЗ КОНФЛИКТОВ С ЖИВОТНЫМИ
  // ==========================================
  static final List<String> _maleKeywords = [
    // Общие термины для самца
    'самец', 'самца', 'самцу', 'самцом',
    'мужской', 'мужского', 'мужская', 'мужской пол',
    'мальчик', 'мальчика',
    // Видоспецифичные термины (те, что НЕ являются названием животного)
    'жеребец', 'жеребца', 'жеребцу',
    'селезень', 'селезня',
    // Производные
    'он', 'его', 'нему',
  ];
  
  static final List<String> _femaleKeywords = [
    // Общие термины для самки
    'самка', 'самки', 'самке', 'самку', 'самкой',
    'женский', 'женского', 'женская', 'женский пол',
    'девочка', 'девочки',
    // Беременность (только самки)
    'беремен', 'беременная', 'беременность', 'сукотность', 'сукотная',
    'стельн', 'стельная', 'стельность',
    'яжереб', 'жеребая', 'жеребость',
    'супорос', 'супоросная', 'суягность', 'суягная',
    // Производные
    'она', 'её', 'ее', 'ней',
  ];

  // ==========================================
  // ВОЗРАСТ - КЛЮЧЕВЫЕ СЛОВА
  // ==========================================
  static final List<String> _ageKeywords = [
    'возраст', 'возраста', 'возрасту',
    'лет', 'год', 'года', 'году',
    'месяц', 'месяца', 'месяцев', 'месяцу',
    'неделя', 'недели', 'недель', 'неделю',
    'день', 'дня', 'дней',
    'старый', 'старая', 'старое', 'возраст',
    'молодой', 'молодая', 'молодое', 'молод',
    'щенок', 'щенка', 'котенок', 'котенка', 'теленок', 'теленка',
    'поросенок', 'поросенка', 'жеребенок', 'жеребенка',
    'ягненок', 'ягненка', 'цыпленок', 'цыпленка',
  ];

  // ==========================================
  // ВЕС - КЛЮЧЕВЫЕ СЛОВА  
  // ==========================================
  static final List<String> _weightKeywords = [
    'вес', 'веса', 'весу', 'весит', 'весят',
    'килограмм', 'килограмма', 'килограммов', 'кило', 'кг', 'kg',
    'грамм', 'грамма', 'граммов', 'гр', 'г',
    'тонна', 'тонны', 'тонн', 'т',
    'масса', 'массой', 'весом',
    'тяжесть', 'тяжелый', 'тяжелая',
  ];

  // ==========================================
  // ПРЕПАРАТЫ С ИХ АЛИАСАМИ
  // ==========================================
  static final Map<String, List<String>> _drugKeywords = {
    // Антибиотики фторхинолоны
    'энрофлоксацин': ['энрофлоксацин', 'энрофлокс', 'энрофлон', 'байтрил', 'энромаг', 'энроксол', 'энрофлок'],
    'марбофлоксацин': ['марбофлоксацин', 'марбоцил', 'марбокил', 'марбофлок'],
    'данофлоксацин': ['данофлоксацин', 'адвоквайл', 'данофлок'],
    'орбитофлоксацин': ['орбитофлоксацин', 'орбит'],
    
    // Пенициллины
    'амоксициллин': ['амоксициллин', 'амоксил', 'амоксиклав', 'синулокс', 'кламоксил', 'амоксогард', 'амоксицилин', 'амокс'],
    'ампициллин': ['ампициллин', 'ампицил', 'ампиокс', 'ампицилин'],
    'бензилпенициллин': ['бензилпенициллин', 'пенициллин', 'бициллин'],
    
    // Цефалоспорины
    'цефтиофур': ['цефтиофур', 'экзенел', 'наксель', 'цефтиофур'],
    'цефазолин': ['цефазолин', 'кефзол', 'цезолин', 'цефазолин'],
    'цефтриаксон': ['цефтриаксон', 'лендацин', 'роцефин', 'цефтриаксон'],
    'цефалексин': ['цефалексин', 'кефлекс', 'цефалекс'],
    'цефапирин': ['цефапирин', 'цефапирин'],
    
    // Макролиды и линкозамиды
    'тилозин': ['тилозин', 'тилан', 'тилозинол', 'фармазин', 'тилозин'],
    'тилмикозин': ['тилмикозин', 'микотил', 'тилмикозин'],
    'линкомицин': ['линкомицин', 'линкоцин', 'линкомицин'],
    'клиндамицин': ['клиндамицин', 'клиндамицин', 'антироб'],
    'эритромицин': ['эритромицин', 'эритромицин'],
    'спирамицин': ['спирамицин', 'ровамицин', 'спирамицин'],
    'тиамулин': ['тиамулин', 'тиамутин', 'тиамулин'],
    
    // Тетрациклины
    'окситетрациклин': ['окситетрациклин', 'террамицин', 'окситетран', 'тетрациклин'],
    'доксициклин': ['доксициклин', 'вибрамицин', 'доксивет', 'доксициклин'],
    'тетрациклин': ['тетрациклин', 'тетрациклин', 'биомицин'],
    
    // Аминогликозиды
    'гентамицин': ['гентамицин', 'гентам', 'гарамицин', 'гентамицин'],
    'стрептомицин': ['стрептомицин', 'стрептомицин'],
    'канамицин': ['канамицин', 'канамицин'],
    'неомицин': ['неомицин', 'неомицин'],
    'амикацин': ['амикацин', 'амикацин'],
    
    // Амфениколы
    'флорфеникол': ['флорфеникол', 'флуникол', 'нуфлор', 'флорфеникол'],
    'хлорамфеникол': ['хлорамфеникол', 'левомицетин', 'хлорамфеникол'],
    
    // Сульфаниламиды
    'сульфадиметоксин': ['сульфадиметоксин', 'сульфадиметоксин'],
    'сульфадимидин': ['сульфадимидин', 'сульфадин', 'сульфадимидин'],
    'триметоприм': ['триметоприм', 'бисептол', 'триметоприм', 'сульфатон'],
    
    // Противопаразитарные - эндопаразиты
    'ивермектин': ['ивермектин', 'ивермек', 'баймек', 'новомек', 'ивермектин'],
    'дорамектин': ['дорамектин', 'дектомакс', 'дорамектин'],
    'моксидектин': ['моксидектин', 'адвокейт', 'cydectin', 'моксидектин'],
    'празиквантел': ['празиквантел', 'празицид', 'дронцит', 'цензин', 'празиквантел'],
    'толтразурил': ['толтразурил', 'байкокс', 'стоп-кокцид', 'толтразурил'],
    'диклазурил': ['диклазурил', 'клинакокс', 'диклазурил'],
    'фенбендазол': ['фенбендазол', 'панакур', 'фенбендазол'],
    'альбендазол': ['альбендазол', 'альбендазол', 'немозол'],
    'мебендазол': ['мебендазол', 'вермокс', 'мебендазол'],
    'пирантел': ['пирантел', 'пирантел', 'гельминтокс'],
    'левамизол': ['левамизол', 'декарис', 'левамизол'],
    
    // Наружные от паразитов
    'фипронил': ['фипронил', 'барс', 'фронтлайн', 'фиприст', 'фипронил'],
    'имидаклоприд': ['имидаклоприд', 'адвантикс', 'имидаклоприд'],
    'селамектин': ['селамектин', 'революшн', 'стронгхолд', 'селамектин'],
    'перметрин': ['перметрин', 'перметрин', 'эктомер'],
    'циперметрин': ['циперметрин', 'циперметрин'],
    
    // НПВС - нестероидные противовоспалительные
    'мелоксикам': ['мелоксикам', 'меклокс', 'мелоксидил', 'метакам', 'локсиком', 'мелоксикам'],
    'кетопрофен': ['кетопрофен', 'кетонал', 'кетофен', 'кетопрофен'],
    'карпрофен': ['карпрофен', 'римадил', 'норокарп', 'карпрофен'],
    'робенакоксиб': ['робенакоксиб', 'онсариор', 'робенакоксиб'],
    'фенилбутазон': ['фенилбутазон', 'бутадион', 'фенилбутазон'],
    'флуниксин': ['флуниксин', 'флуниксин', 'флунекс'],
    'толфенамовая кислота': ['толфенамовая', 'толфенамик', 'толфен'],
    'ведапрофен': ['ведапрофен', 'квадрисол', 'ведапрофен'],
    'марококсиб': ['марококсиб', 'превикокс', 'марококсиб'],
    
    // Глюкокортикоиды
    'дексаметазон': ['дексаметазон', 'дексамет', 'дексафорт', 'дексаметазон'],
    'преднизолон': ['преднизолон', 'преднизолон', 'преднизон'],
    'преднизон': ['преднизон', 'преднизон'],
    'метилпреднизолон': ['метилпреднизолон', 'медрол', 'метилпред'],
    'триамцинолон': ['триамцинолон', 'кеналог', 'триамцинолон'],
    
    // Анестетики и седативные
    'кетамин': ['кетамин', 'калипсол', 'кетанест', 'кетамин'],
    'ксилазин': ['ксилазин', 'ромпун', 'ксиланит', 'рометар', 'ксилазин'],
    'золетил': ['золетил', 'тилетамин', 'золазепам', 'золетил'],
    'пропофол': ['пропофол', 'пропофол', 'диприван'],
    'тиопентал': ['тиопентал', 'тиопентал'],
    'атропин': ['атропин', 'атропина сульфат', 'атропин'],
    'лидокаин': ['лидокаин', 'ксикаин', 'лигнокаин', 'лидокаин', 'новокаин'],
    'бупивакаин': ['бупивакаин', 'маркаин', 'бупивакаин'],
    'мидазолам': ['мидазолам', 'дормикум', 'мидазолам'],
    'диазепам': ['диазепам', 'валиум', 'реланиум', 'диазепам', 'седуксен'],
    'ацепромазин': ['ацепромазин', 'промасед', 'ацепромазин'],
    'детомидин': ['детомидин', 'домоседан', 'детомидин'],
    'медетомидин': ['медетомидин', 'домитор', 'медетомидин'],
    
    // Противорвотные
    'маропитант': ['маропитант', 'серения', 'церенния', 'маропитант'],
    'метоклопрамид': ['метоклопрамид', 'церукал', 'реглан', 'метоклопрамид'],
    'ондансетрон': ['ондансетрон', 'зофран', 'латран', 'ондансетрон'],
    
    // Диуретики
    'фуросемид': ['фуросемид', 'лазикс', 'фуросемид'],
    'спиронолактон': ['спиронолактон', 'верошпирон', 'спиронолактон'],
    'маннитол': ['маннитол', 'маннит', 'маннитол'],
    
    // Гемостатики (кровоостанавливающие)
    'транексам': ['транексам', 'транексамовая кислота', 'транексам'],
    'этамзилат': ['этамзилат', 'дицинон', 'этамзилат'],
    'фитоменадион': ['фитоменадион', 'викасол', 'витамин к', 'витамин к1', 'фитоменадион'],
    'аминокапроновая кислота': ['аминокапроновая', 'аминокапронка', 'акк'],
    
    // Антигистаминные
    'дифенгидрамин': ['дифенгидрамин', 'димедрол', 'дифенгидрамин'],
    'диметинден': ['диметинден', 'фенистил', 'диметинден'],
    'хлоропирамин': ['хлоропирамин', 'супрастин', 'хлоропирамин'],
    'цетиризин': ['цетиризин', 'зиртек', 'цетиризин'],
    'левоцетиризин': ['левоцетиризин', 'ксизал', 'левоцетиризин'],
    
    // Иммуномодуляторы и витамины
    'гамавит': ['гамавит'],
    'катозал': ['катозал', 'бутофан', 'катозал'],
    'травматин': ['травматин', 'траумель', 'травматин'],
    'рибофлавин': ['рибофлавин', 'витамин в2', 'рибофлавин'],
    'тиамин': ['тиамин', 'витамин в1', 'тиамин'],
    'пиридоксин': ['пиридоксин', 'витамин в6', 'пиридоксин'],
    'цианокобаламин': ['цианокобаламин', 'витамин в12', 'цианокобаламин'],
    'аскорбиновая кислота': ['аскорбинка', 'витамин с', 'аскорбиновая'],
    'токоферол': ['токоферол', 'витамин е', 'токоферол'],
    
    // Сердечные
    'дигоксин': ['дигоксин', 'дигоксин'],
    'пимобендан': ['пимобендан', 'ветмедин', 'пимобендан'],
    'эналаприл': ['эналаприл', 'эналаприл', 'энап'],
    'рамиприл': ['рамиприл', 'рамиприл'],
    'атенолол': ['атенолол', 'атенолол'],
    
    // Противодиабетические
    'инсулин': ['инсулин', 'инсулин', 'лантус', 'протафан'],
    
    // Противосудорожные
    'фенобарбитал': ['фенобарбитал', 'фенобарбитал'],
    'бромид калия': ['бромид калия', 'бромид', 'бром'],
    'габапентин': ['габапентин', 'габапентин', 'нейронтин'],
    'леветирацетам': ['леветирацетам', 'кеппра', 'леветирацетам'],
    
    // Гормональные
    'окситоцин': ['окситоцин', 'окситоцин'],
    'простагландины': ['простагландин', 'эстуфалан', 'простин'],
    'гонадотропин': ['гонадотропин', 'хгч', 'прегнил'],
    
    // Местные антисептики
    'хлоргексидин': ['хлоргексидин', 'хлоргексидин'],
    'мирамистин': ['мирамистин', 'мирамистин'],
    'йод': ['йод', 'йод', 'повидон-йод'],
    'перекись водорода': ['перекись', 'перекись водорода'],
  };

  // Концентрации препаратов (для понимания "5 процентов", "10%")
  static final RegExp _concentrationPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:процент|%|пр|процентов)'
  );

  /// Парсит концентрацию из ввода
  static double? parseConcentration(String input) {
    final match = _concentrationPattern.firstMatch(input.toLowerCase());
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '.'));
    }
    return null;
  }

  /// Ищет название препарата в голосовом вводе
  static DrugMatch? findDrug(String input, List<String>? availableDrugs) {
    final lower = input.toLowerCase();

    // Сначала ищем по алиасам (точное совпадение подстроки)
    for (final entry in _drugKeywords.entries) {
      for (final alias in entry.value) {
        if (lower.contains(alias)) {
          // Проверяем концентрацию
          final concentration = parseConcentration(input);
          return DrugMatch(
            inn: entry.key,
            matchedAlias: alias,
            concentration: concentration,
          );
        }
      }
    }

    // Если передан список доступных препаратов, ищем прямое совпадение
    if (availableDrugs != null) {
      for (final drug in availableDrugs) {
        if (lower.contains(drug.toLowerCase())) {
          return DrugMatch(
            inn: drug,
            matchedAlias: drug,
          );
        }
      }

      // ⚠️ Fuzzy-поиск через Levenshtein distance.
      // Google STT на русском часто искажает латинские названия препаратов:
      // "Амоксиклав" → "Амоксилав", "Энрофлоксацин" → "Энрофлаксацин" и т.д.
      // Простой contains() такое не найдёт. Ищем препарат, у которого расстояние
      // Левенштейна до любого слова во вводе <= 2 (1-2 замены/вставки/удаления).
      final words = lower
          .replaceAll(RegExp(r'[^\w\sа-яё-]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 4)  // короткие слова (предлоги) пропускаем
          .toList();

      String? bestDrug;
      int bestDistance = 999;
      for (final drug in availableDrugs) {
        final drugLower = drug.toLowerCase();
        // Берём первое слово из названия препарата (без ®, цифр, скобок)
        final drugWords = drugLower
            .replaceAll(RegExp(r'[®(),\d.]'), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 4)
            .toList();
        if (drugWords.isEmpty) continue;

        for (final drugWord in drugWords) {
          for (final inputWord in words) {
            final dist = _levenshtein(drugWord, inputWord);
            // Допускаем 1-2 опечатки для коротких, 2-3 для длинных
            final threshold = drugWord.length >= 8 ? 3 : 2;
            if (dist <= threshold && dist < bestDistance) {
              bestDistance = dist;
              bestDrug = drug;
            }
          }
        }
      }

      if (bestDrug != null) {
        debugPrint('🎤 Fuzzy match: "$bestDrug" (distance=$bestDistance) для ввода "$input"');
        return DrugMatch(
          inn: bestDrug,
          matchedAlias: bestDrug,
        );
      }
    }

    return null;
  }

  /// Вычисляет расстояние Левенштейна между двумя строками.
  /// Минимальное число вставок/удалений/замен, чтобы превратить [a] в [b].
  /// Используется для fuzzy-поиска препаратов, когда STT исказил латинское название.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if (a.length < b.length) {
      final tmp = a; a = b; b = tmp;
    }
    var prevRow = List<int>.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      var curRow = List<int>.filled(b.length + 1, 0);
      curRow[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curRow[j + 1] = [
          prevRow[j + 1] + 1,    // удаление
          curRow[j] + 1,         // вставка
          prevRow[j] + cost,     // замена
        ].reduce((x, y) => x < y ? x : y);
      }
      prevRow = curRow;
    }
    return prevRow[b.length];
  }

  /// Ищет животное в голосовом вводе
  static AnimalMatch? findAnimal(String input) {
    final lower = input.toLowerCase();
    
    for (final entry in _animalKeywords.entries) {
      for (final alias in entry.value) {
        if (lower.contains(alias)) {
          return AnimalMatch(
            id: entry.key,
            matchedAlias: alias,
          );
        }
      }
    }
    
    return null;
  }

  /// Парсит пол из голосового ввода
  static GenderMatch? findGender(String input) {
    final lower = input.toLowerCase();
    
    // Сначала проверяем женский пол (включая признаки беременности)
    for (final keyword in _femaleKeywords) {
      if (lower.contains(keyword)) {
        return GenderMatch(
          gender: VoiceGender.female,
          matchedAlias: keyword,
        );
      }
    }
    
    // Потом мужской
    for (final keyword in _maleKeywords) {
      if (lower.contains(keyword)) {
        return GenderMatch(
          gender: VoiceGender.male,
          matchedAlias: keyword,
        );
      }
    }
    
    return null;
  }
  
  /// Парсит возраст из голосового ввода
  /// Возвращает возраст в месяцах
  static AgeMatch? findAge(String input) {
    final lower = input.toLowerCase();
    
    // Паттерны для возраста - годы
    final yearPatterns = [
      RegExp(r'(\d+)\s*(?:лет|год|года|году)'),
      RegExp(r'(?:возраст|лет|год|года)\s*(\d+)'),
      RegExp(r'(\d+)\s*(?:г|год)(?:\s|$)'),
    ];
    
    // Ищем годы
    for (final pattern in yearPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final yearsStr = match.group(1);
        if (yearsStr != null) {
          final years = int.tryParse(yearsStr);
          if (years != null && years > 0 && years < 50) {
            return AgeMatch(
              months: years * 12,
              matchedText: '$years ${_getYearsWord(years)}',
            );
          }
        }
      }
    }
    
    // Паттерны для возраста - месяцы
    final monthPatterns = [
      RegExp(r'(\d+)\s*(?:месяц|месяца|месяцев|мес)'),
      RegExp(r'(?:возраст|месяц|месяца|месяцев)\s*(\d+)'),
      RegExp(r'(\d+)\s*мес(?:\.|яц|яца|яцев)?(?:\s|$)'),
    ];
    
    // Ищем месяцы
    for (final pattern in monthPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final monthsStr = match.group(1);
        if (monthsStr != null) {
          final months = int.tryParse(monthsStr);
          if (months != null && months > 0 && months < 600) {
            return AgeMatch(
              months: months,
              matchedText: '$months ${_getMonthsWord(months)}',
            );
          }
        }
      }
    }
    
    // Паттерны для возраста - недели
    final weekPatterns = [
      RegExp(r'(\d+)\s*(?:неделя|недели|недель|нед|н\.)'),
      RegExp(r'(?:возраст|неделя|недели)\s*(\d+)'),
    ];
    
    // Ищем недели
    for (final pattern in weekPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final weeksStr = match.group(1);
        if (weeksStr != null) {
          final weeks = int.tryParse(weeksStr);
          if (weeks != null && weeks > 0 && weeks < 200) {
            return AgeMatch(
              months: (weeks / 4.33).round(), // Примерно 4.33 недели в месяце
              matchedText: '$weeks ${_getWeeksWord(weeks)}',
            );
          }
        }
      }
    }
    
    // Паттерны для возраста - дни (для очень молодых)
    final dayPatterns = [
      RegExp(r'(\d+)\s*(?:день|дня|дней|дн|д\.)(?:\s|$)'),
    ];
    
    // Ищем дни
    for (final pattern in dayPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final daysStr = match.group(1);
        if (daysStr != null) {
          final days = int.tryParse(daysStr);
          if (days != null && days > 0 && days < 365) {
            return AgeMatch(
              months: (days / 30.0).round(), // Примерно 30 дней в месяце
              matchedText: '$days ${_getDaysWord(days)}',
            );
          }
        }
      }
    }
    
    // Специальные случаи - "щенок", "котенок" и т.д. означают молодой возраст
    if (lower.contains('щенок') || lower.contains('щенку') || lower.contains('щенка')) {
      return AgeMatch(months: 6, matchedText: 'щенок (до года)');
    }
    if (lower.contains('котёнок') || lower.contains('котенок') || lower.contains('котенку')) {
      return AgeMatch(months: 6, matchedText: 'котёнок (до года)');
    }
    if (lower.contains('теленок') || lower.contains('телёнок') || lower.contains('телёнку')) {
      return AgeMatch(months: 6, matchedText: 'телёнок (до года)');
    }
    if (lower.contains('поросенок') || lower.contains('поросёнок') || lower.contains('поросенку')) {
      return AgeMatch(months: 4, matchedText: 'поросёнок (до года)');
    }
    if (lower.contains('жеребенок') || lower.contains('жеребёнок') || lower.contains('жеребёнку')) {
      return AgeMatch(months: 6, matchedText: 'жеребёнок (до года)');
    }
    
    return null;
  }
  
  /// Склонение слова "год"
  static String _getYearsWord(int years) {
    if (years == 1) return 'год';
    if (years >= 2 && years <= 4) return 'года';
    if (years >= 5 && years <= 20) return 'лет';
    final lastDigit = years % 10;
    if (lastDigit == 1) return 'год';
    if (lastDigit >= 2 && lastDigit <= 4) return 'года';
    return 'лет';
  }
  
  /// Склонение слова "месяц"
  static String _getMonthsWord(int months) {
    if (months == 1) return 'месяц';
    if (months >= 2 && months <= 4) return 'месяца';
    if (months >= 5 && months <= 20) return 'месяцев';
    final lastDigit = months % 10;
    if (lastDigit == 1) return 'месяц';
    if (lastDigit >= 2 && lastDigit <= 4) return 'месяца';
    return 'месяцев';
  }
  
  /// Склонение слова "неделя"
  static String _getWeeksWord(int weeks) {
    if (weeks == 1) return 'неделя';
    if (weeks >= 2 && weeks <= 4) return 'недели';
    if (weeks >= 5 && weeks <= 20) return 'недель';
    final lastDigit = weeks % 10;
    if (lastDigit == 1) return 'неделя';
    if (lastDigit >= 2 && lastDigit <= 4) return 'недели';
    return 'недель';
  }
  
  /// Склонение слова "день"
  static String _getDaysWord(int days) {
    if (days == 1) return 'день';
    if (days >= 2 && days <= 4) return 'дня';
    if (days >= 5 && days <= 20) return 'дней';
    final lastDigit = days % 10;
    if (lastDigit == 1) return 'день';
    if (lastDigit >= 2 && lastDigit <= 4) return 'дня';
    return 'дней';
  }

  /// Проверяет, содержит ли текст ключевые слова возраста
  static bool _hasAgeKeywords(String input) {
    final lower = input.toLowerCase();
    for (final keyword in _ageKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }
    // Дополнительные проверки через регекспы
    if (RegExp(r'\d+\s*(?:лет|год|года|месяц|месяца|месяцев|неделя|недели|недель)').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  /// Проверяет, содержит ли текст ключевые слова веса
  static bool _hasWeightKeywords(String input) {
    final lower = input.toLowerCase();
    for (final keyword in _weightKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  // 🆕 Sprint 3: Распознавание чисел прописью для голосового ввода веса.
  // Поддерживает «двадцать пять», «пятнадцать целых пять», «двести».
  static final Map<String, int> _numberWords = {
    'ноль': 0, 'один': 1, 'одна': 1, 'два': 2, 'две': 2,
    'три': 3, 'четыре': 4, 'пять': 5, 'шесть': 6, 'семь': 7,
    'восемь': 8, 'девять': 9, 'десять': 10,
    'одиннадцать': 11, 'двенадцать': 12, 'тринадцать': 13,
    'четырнадцать': 14, 'пятнадцать': 15, 'шестнадцать': 16,
    'семнадцать': 17, 'восемнадцать': 18, 'девятнадцать': 19,
    'двадцать': 20, 'тридцать': 30, 'сорок': 40, 'пятьдесят': 50,
    'шестьдесят': 60, 'семьдесят': 70, 'восемьдесят': 80, 'девяносто': 90,
    'сто': 100, 'двести': 200, 'триста': 300, 'четыреста': 400,
    'пятьсот': 500, 'шестьсот': 600, 'семьсот': 700,
    'восемьсот': 800, 'девятьсот': 900,
    'тысяча': 1000, 'тысяч': 1000, 'тысячи': 1000,
  };

  /// 🆕 Преобразует текстовое число в double.
  /// «двадцать пять» → 25.0, «пятнадцать целых пять» → 15.5
  static double? _parseSpelledNumber(String text) {
    final words = text.toLowerCase().split(RegExp(r'[\s,]+'));
    int total = 0;
    int current = 0;
    bool foundAny = false;

    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^а-яё]'), '');
      if (cleanWord.isEmpty) continue;
      if (cleanWord == 'целых' || cleanWord == 'целая' || cleanWord == 'запятая') {
        // Разделитель — дальше идут десятые
        total = current;
        current = 0;
        continue;
      }
      final value = _numberWords[cleanWord];
      if (value == null) continue;
      foundAny = true;
      if (value == 1000) {
        current = (current == 0 ? 1 : current) * 1000;
      } else if (value >= 100) {
        current += value;
      } else if (value >= 20 && value < 100) {
        current += value;
      } else {
        current += value;
      }
    }
    if (!foundAny) return null;
    if (total > 0) {
      // Была «целых» — total = целая часть, current = десятые
      return total + current / 10.0;
    }
    return current.toDouble();
  }

  /// Парсит вес из голосового ввода
  static double? parseWeight(String input) {
    final lower = input.toLowerCase();
    
    // Сначала ищем явное указание веса с ключевыми словами
    final explicitWeightPatterns = [
      RegExp(r'(?:вес|весит|масса|весом)\s*(\d+(?:[.,]\d+)?)'),
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:килограмм|кило|кг|kg)(?:\s|$)'),
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:грамм|гр|г)(?:\s|$)'), // для мелких животных
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:тонн|тонны|т)(?:\s|$)'), // для крупных
    ];
    
    for (final pattern in explicitWeightPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        var weightStr = match.group(1)!.replaceAll(',', '.');
        weightStr = weightStr.replaceFirst(RegExp(r'^0+(?=\d)'), '');
        final weight = double.tryParse(weightStr);
        if (weight != null && weight > 0) {
          // Конвертируем в килограммы если нужно
          if (lower.contains('грамм') || lower.contains(' гр') || lower.contains(' г ')) {
            return weight / 1000; // граммы в кг
          }
          if (lower.contains('тонн') || lower.contains(' тонны') || lower.contains(' т')) {
            return weight * 1000; // тонны в кг
          }
          if (weight < 2000) { // разумный предел для кг
            return weight;
          }
        }
      }
    }
    
    // Если есть ключевые слова возраста, но нет ключевых слов веса - 
    // пытаемся отделить число возраста от числа веса
    final hasAgeContext = _hasAgeKeywords(lower);
    final hasWeightContext = _hasWeightKeywords(lower);
    
    // Ищем все числа в тексте
    final numberPattern = RegExp(r'(\d+(?:[.,]\d+)?)');
    final allNumbers = numberPattern.allMatches(lower);
    
    for (final match in allNumbers) {
      final numberStr = match.group(1)!.replaceAll(',', '.');
      final number = double.tryParse(numberStr);
      if (number == null || number <= 0) continue;
      
      // Проверяем контекст вокруг числа
      final startPos = match.start > 20 ? match.start - 20 : 0;
      final endPos = match.end + 20 < lower.length ? match.end + 20 : lower.length;
      final context = lower.substring(startPos, endPos);
      
      // Если в контексте есть ключевые слова веса - это вес
      if (_hasWeightKeywords(context)) {
        if (number < 2000) return number;
      }
      
      // Если в контексте есть ключевые слова возраста - пропускаем
      if (_hasAgeKeywords(context)) {
        continue;
      }
      
      // Если нет явных маркеров и число похоже на вес
      if (!hasAgeContext && !hasWeightContext) {
        // Если число > 500 - скорее всего вес крупного животного
        // Если число < 500 и нет контекста возраста - может быть весом
        if (number > 500 && number < 2000) {
          return number;
        }
        // Если число в диапазоне веса мелких/средних животных
        if (number >= 0.1 && number <= 500) {
          return number;
        }
      }
    }

    // 🆕 Sprint 3: Если числа не найдены, пробуем числа прописью
    // «двадцать пять килограмм» → 25.0
    if (_hasWeightKeywords(lower)) {
      final spelled = _parseSpelledNumber(lower);
      if (spelled != null && spelled > 0 && spelled < 5000) {
        // Конвертация единиц
        if (lower.contains('грамм') || lower.contains(' гр') || lower.contains(' г ')) {
          return spelled / 1000;
        }
        if (lower.contains('тонн') || lower.contains(' тонны') || lower.contains(' т')) {
          return spelled * 1000;
        }
        return spelled;
      }
    }

    return null;
  }

  /// Полный парсинг голосового ввода
  static VoiceInputResult parse(String input, {List<String>? availableDrugs}) {
    final weight = parseWeight(input);
    final drug = findDrug(input, availableDrugs);
    final animal = findAnimal(input);
    final gender = findGender(input);
    final age = findAge(input);
    
    return VoiceInputResult(
      weight: weight,
      drugMatch: drug,
      animalMatch: animal,
      genderMatch: gender,
      ageMatch: age,
      rawText: input,
    );
  }
}

/// Результат поиска препарата
class DrugMatch {
  final String inn; // Международное непатентованное название
  final String matchedAlias; // То, что совпало в голосовом вводе
  final double? concentration; // Концентрация если указана

  const DrugMatch({
    required this.inn,
    required this.matchedAlias,
    this.concentration,
  });

  @override
  String toString() => 'DrugMatch($inn, conc: $concentration)';
}

/// Результат поиска животного
class AnimalMatch {
  final String id;
  final String matchedAlias;

  const AnimalMatch({
    required this.id,
    required this.matchedAlias,
  });

  @override
  String toString() => 'AnimalMatch($id)';
}

/// Результат парсинга пола
enum VoiceGender {
  male,
  female,
}

class GenderMatch {
  final VoiceGender gender;
  final String matchedAlias;

  const GenderMatch({
    required this.gender,
    required this.matchedAlias,
  });

  @override
  String toString() => 'GenderMatch($gender)';
}

/// Результат парсинга возраста
class AgeMatch {
  final int months;
  final String matchedText;

  const AgeMatch({
    required this.months,
    required this.matchedText,
  });

  @override
  String toString() => 'AgeMatch($months months)';
}

/// Результат парсинга голосового ввода
class VoiceInputResult {
  final double? weight;
  final DrugMatch? drugMatch;
  final AnimalMatch? animalMatch;
  final GenderMatch? genderMatch;
  final AgeMatch? ageMatch;
  final String rawText;

  const VoiceInputResult({
    this.weight,
    this.drugMatch,
    this.animalMatch,
    this.genderMatch,
    this.ageMatch,
    required this.rawText,
  });

  bool get hasWeight => weight != null && weight! > 0;
  bool get hasDrug => drugMatch != null;
  bool get hasAnimal => animalMatch != null;
  bool get hasGender => genderMatch != null;
  bool get hasAge => ageMatch != null;

  /// Генерирует текст подсказки для пользователя
  String getHint() {
    final parts = <String>[];
    
    if (!hasAnimal) parts.add('назовите животное');
    if (!hasWeight) parts.add('укажите вес');
    if (!hasDrug) parts.add('назовите препарат');
    
    if (parts.isEmpty) return 'Всё распознано';
    return 'Не хватает: ${parts.join(', ')}';
  }

  @override
  String toString() => 'VoiceInputResult(weight: $weight, drug: $drugMatch, animal: $animalMatch)';
}
