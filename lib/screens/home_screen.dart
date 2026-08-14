import 'dart:async';
import 'package:flutter/material.dart';
import '../models/drug.dart';
import '../models/drug_registry.dart';
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';
import '../services/speech_service.dart';
import '../services/wake_word_service.dart';
import '../utils/app_theme.dart';
import '../widgets/animal_card.dart';
import '../widgets/drug_dropdown.dart';
import '../widgets/mic_button.dart';
import '../widgets/result_card.dart';
import '../widgets/animal_params_selector.dart';
import '../widgets/method_selector.dart';
import '../widgets/compatibility_checker.dart';
import 'diseases_screen.dart';
import 'fluid_therapy_screen.dart';
import 'unofficial_protocols_screen.dart';
import 'favorites_screen.dart';  // 🆕
import 'history_screen.dart';    // 🆕
import 'settings_screen.dart';   // 🆕
import 'symptom_search_screen.dart';  // 🆕 Sprint 2
import 'treatment_protocols_screen.dart';  // 🆕 Sprint 2
import 'interactions_checker_screen.dart';  // 🆕 Sprint 2
import 'withdrawal_calculator_screen.dart';  // 🆕 Sprint 2
import 'infusion_calculator_screen.dart';  // 🆕 Sprint 3
import '../services/favorites_service.dart';  // 🆕
import '../services/history_service.dart';    // 🆕
import '../services/theme_service.dart';      // 🆕
import '../services/symptom_search_service.dart';  // 🆕 Sprint 2

// Экспорт VoiceGender для использования в парсинге
export '../services/speech_service.dart' show VoiceGender;

/// Главный экран приложения VetVoice AI с голосовым управлением
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final VetProvider _vetProvider = VetProvider();
  final SpeechService _speechService = SpeechService();
  final WakeWordService _wakeWordService = WakeWordService.instance;

  final TextEditingController _weightController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isListening = false;
  String _voiceStatusText = '';
  String _voiceHint = '';
  WeightValidationResult? _weightValidation;
  
  // Hands-free режим
  bool _handsFreeMode = false;
  
  // Режим wake word (замена "уху") - слушает "ВетВойс" как Ok Google
  bool _wakeWordEnabled = false;
  bool _wasWakeWordManuallyEnabled = false; // Пользователь вручную включил wake word
  String _wakeWordHeard = ''; // Что услышал wake word сервис
  
  // Автоозвучивание результатов
  bool _autoSpeakResult = true;
  
  // Mutex для предотвращения race condition при переключении режимов
  bool _isTransitioning = false;

  // Отслеживаем отложенные Future для отмены в dispose()
  Timer? _wakeWordRestartTimer;
  
  // Анимация для hands-free индикатора
  late AnimationController _handsFreeController;
  
  // Анимация для wake word индикатора (пульсация когда слушает)
  late AnimationController _wakeWordAnimationController;

  // StreamSubscription — сохраняем для корректной отмены в dispose()
  StreamSubscription<String>? _onWordsRecognizedSub;
  StreamSubscription<bool>? _onSTTStateChangedSub;
  StreamSubscription<VoiceCommand>? _onCommandSub;
  StreamSubscription<String>? _onSTTErrorSub;
  StreamSubscription<void>? _onWakeWordSub;
  StreamSubscription<bool>? _onWakeWordStateChangedSub;
  StreamSubscription<String>? _onWakeWordErrorSub;
  StreamSubscription<String>? _onWakeWordPartialSub;
  StreamSubscription<void>? _onDownloadProgressSub;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // Сохраняем подписки для отмены в dispose()
    _onWordsRecognizedSub = _speechService.onWordsRecognized.listen(_handleVoiceInput);
    _onSTTStateChangedSub = _speechService.onListeningStateChanged.listen((isListening) {
      final wasListening = _isListening;
      // ⚠️ Фикс B-5: mounted-проверка перед setState — singleton speechService
      // может выстрелить событием уже после dispose виджета.
      if (!mounted) return;
      setState(() => _isListening = isListening);
      // Когда STT остановился — перезапускаем Vosk если нужно
      if (wasListening && !isListening) {
        _restartWakeWordIfNeeded();
      }
    });
    _onCommandSub = _speechService.onCommand.listen((command) {
      _handleVoiceCommand(command);
      // После обработки команды тоже перезапускаем Vosk
      _restartWakeWordIfNeeded();
    });
    _onSTTErrorSub = _speechService.onError.listen(_handleVoiceError);
    
    // Wake word detection
    _onWakeWordSub = _wakeWordService.onWakeWord.listen(_handleWakeWord);
    _onWakeWordStateChangedSub = _wakeWordService.onListeningStateChanged.listen((isListening) {
      // ⚠️ Фикс B-5: WakeWordService — singleton, событие может прилететь
      // после dispose виджета.
      if (!mounted) return;
      setState(() {});
    });
    _onWakeWordErrorSub = _wakeWordService.onError.listen(_handleWakeWordError);
    _onWakeWordPartialSub = _wakeWordService.onPartialResult.listen(_handleWakeWordPartial);
    _onDownloadProgressSub = _wakeWordService.onDownloadProgress.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    
    _handsFreeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Анимация для wake word (пульсация)
    _wakeWordAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  Future<void> _initializeApp() async {
    await _vetProvider.initialize();
    await _speechService.initializeSTT();
    await _speechService.initializeTTS();
    
    // Инициализируем wake word service (Vosk)
    await _wakeWordService.initialize();
    
    debugPrint('✅ App initialized — STT: ${_speechService.isSTTReady}, TTS: ${_speechService.isTTSReady}, locale: ${_speechService.currentLocaleId}');
    // ⚠️ Фикс B-6: mounted-проверка после async-гэпа в _initializeApp.
    // Пользователь может закрыть экран до окончания инициализации.
    if (!mounted) return;
    setState(() {});
  }
  
  /// Обработка wake word - когда пользователь сказал "ВетВойс"
  void _handleWakeWord(_) {
    debugPrint('🎯 Wake word detected!');
    
    // КРИТИЧЕСКИ ВАЖНО: сначала останавливаем Vosk чтобы освободить микрофон!
    // Без этого STT (speech_to_text) не сможет получить доступ к аудио
    setState(() {
      _voiceStatusText = 'Скажите команду...';
      _wakeWordEnabled = false; // Временно приостанавливаем Vosk
      _wakeWordAnimationController.stop();
      _wakeWordAnimationController.reset();
    });
    // НЕ сбрасываем _wasWakeWordManuallyEnabled — он нужен для перезапуска
    
    // Используем callback вместо hardcoded delay — ждём реального освобождения микрофона
    _wakeWordService.setMicReleaseCallback(() async {
      _wakeWordService.clearMicReleaseCallback();
      // ⚠️ Фикс B-2: ранее использовался Future.delayed(500мс), которого
      // недостаточно для произнесения слова «Слушаю». TTS с awaitSpeakCompletion(true)
      // разрешает дождаться окончания речи — STT стартует ТОЛЬКО после завершения TTS,
      // иначе STT услышит собственное TTS («voice input not recognizing words»).
      if (!mounted) return;
      await _speechService.speak('Слушаю');
      if (!mounted) return;
      await _speechService.startListening();
    });
    _wakeWordService.stopListening();
  }
  
  /// Ошибка wake word detection
  void _handleWakeWordError(String error) {
    setState(() {
      _voiceStatusText = 'Ошибка wake word: $error';
    });
    debugPrint('❌ Wake word error: $error');
  }
  
  /// Частичный результат wake word - показывает что услышал
  void _handleWakeWordPartial(String text) {
    setState(() {
      _wakeWordHeard = text;
    });
    debugPrint('🎤 Wake word partial: $text');
  }
  
  /// Включить/выключить wake word режим
  Future<void> _toggleWakeWord() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      _wakeWordEnabled = !_wakeWordEnabled;
      _wasWakeWordManuallyEnabled = _wakeWordEnabled; // Запоминаем ручное включение
      
      if (_wakeWordEnabled) {
        _wakeWordAnimationController.repeat();
        
        // КРИТИЧЕСКИ: останавливаем STT перед Vosk — микрофон — shared resource
        if (_speechService.isListening) {
          await _speechService.stopListening();
        }
        // Останавливаем hands-free если был включён (конфликт микрофона)
        if (_handsFreeMode) {
          _handsFreeMode = false;
          _handsFreeController.stop();
          _speechService.setContinuousMode(false);
        }
        
        await _wakeWordService.startListening();
        
        if (_wakeWordService.isInitialized) {
          _speechService.speak('Скажите ВетВойс для активации');
          setState(() {
            _wakeWordHeard = '';
          });
        } else if (_wakeWordService.isModelLoading) {
          _speechService.speak('Загружается модель голоса');
        } else {
          _speechService.speak('Ошибка инициализации голоса');
        }
      } else {
        _wasWakeWordManuallyEnabled = false;
        _wakeWordAnimationController.stop();
        _wakeWordAnimationController.reset();
        await _wakeWordService.stopListening();
        setState(() {
          _wakeWordHeard = '';
        });
      }
      
      setState(() {});
    } finally {
      _isTransitioning = false;
    }
  }

  void _handleVoiceError(String error) {
    setState(() {
      _voiceStatusText = 'Ошибка: $error';
      _voiceHint = 'Нажмите микрофон для повторной попытки';
    });
  }

  void _handleVoiceCommand(VoiceCommand command) {
    switch (command.type) {
      case VoiceCommandType.stop:
        _speechService.stopSpeaking();
        _speechService.stopListening();
        _speechService.setContinuousMode(false);
        _wakeWordService.stopListening();
        setState(() {
          _handsFreeMode = false;
          _wakeWordEnabled = false;
          _handsFreeController.stop();
          _wakeWordAnimationController.stop();
          _voiceStatusText = 'Остановлено';
        });
        break;
        
      case VoiceCommandType.repeat:
        _speakResult();
        break;
        
      case VoiceCommandType.reset:
        _resetForm();
        _speechService.speak('Сброс выполнен. Начните заново.');
        break;
        
      case VoiceCommandType.help:
        _speakHelp();
        break;
        
      case VoiceCommandType.continuous:
        _toggleHandsFree();
        break;
        
      case VoiceCommandType.speakResult:
        _speakResult();
        break;
        
      case VoiceCommandType.animal:
        // Обрабатывается в основном парсере
        break;
        
      case VoiceCommandType.earMode:
        _toggleWakeWord();
        break;
    }
  }

  void _speakHelp() {
    const helpText = '''
      Говорите естественно. Например: "собака 15 килограмм энрофлоксацин".
      Или по очереди: сначала животное, потом вес, потом препарат.
      Команды: стоп, повтори, сброс, помощь.
      Скажите "без рук" для автоматического режима.
    ''';
    _speechService.speak(helpText);
  }

  Future<void> _toggleHandsFree() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      _handsFreeMode = !_handsFreeMode;
      _speechService.setContinuousMode(_handsFreeMode);
      
      if (_handsFreeMode) {
        _handsFreeController.repeat();
        // КРИТИЧЕСКИ: останавливаем Vosk — он забирает микрофон и STT не работает
        if (_wakeWordEnabled) {
          _wakeWordEnabled = false;
          _wasWakeWordManuallyEnabled = false;
          _wakeWordAnimationController.stop();
          _wakeWordAnimationController.reset();
          await _wakeWordService.stopListening();
        }
        // Ждём завершения TTS перед стартом STT,
        // чтобы STT не слышал собственное TTS.
        _startHandsFreeListening();
      } else {
        _handsFreeController.stop();
        _speechService.stopListening();
        _speechService.speak('Режим без рук выключен.');
        // Перезапускаем wake word если был включён
        // (здесь не перезапускаем т.к. пользователь явно выключил hands-free)
      }
      
      setState(() {});
    } finally {
      _isTransitioning = false;
    }
  }

  /// Запускает STT после завершения TTS-анонса в hands-free режиме.
  /// Отдельный метод чтобы избежать race condition fire-and-forget async.
  Future<void> _startHandsFreeListening() async {
    try {
      await _speechService.speak('Режим без рук включён. Говорите после сигнала.');
    } catch (e) {
      debugPrint('⚠️ TTS error in hands-free: $e');
    }
    if (_handsFreeMode && mounted) {
      try {
        await _speechService.startListening();
      } catch (e) {
        debugPrint('⚠️ STT start error in hands-free: $e');
      }
    }
  }

  void _handleVoiceInput(String text) {
    setState(() {
      _voiceStatusText = '"$text"';
    });

    // Получаем список названий доступных препаратов
    final drugNames = _vetProvider.availableDrugs.map((d) {
      if (d is CalcDrug) return d.name;
      if (d is RegistryDrug) return d.tradeName;
      return '';
    }).toList();

    final result = VoiceInputParser.parse(text, availableDrugs: drugNames);
    
    bool somethingChanged = false;

    // Обрабатываем животное
    if (result.hasAnimal && result.animalMatch != null) {
      final animalId = result.animalMatch!.id;
      if (_vetProvider.selectedAnimalId != animalId) {
        _vetProvider.selectAnimal(animalId);
        somethingChanged = true;
        setState(() {
          _voiceHint = 'Животное: ${_vetProvider.selectedAnimal?.name ?? animalId}';
        });
      }
    }

    // Обрабатываем пол
    if (result.hasGender && result.genderMatch != null) {
      final gender = result.genderMatch!.gender == VoiceGender.male 
          ? Gender.male 
          : Gender.female;
      if (_vetProvider.gender != gender) {
        _vetProvider.setGender(gender);
        somethingChanged = true;
        setState(() {
          _voiceHint = _voiceHint.isEmpty 
              ? 'Пол: ${gender == Gender.male ? "самец" : "самка"}'
              : '$_voiceHint, пол: ${gender == Gender.male ? "самец" : "самка"}';
        });
      }
    }

    // Обрабатываем возраст
    if (result.hasAge && result.ageMatch != null) {
      final ageMonths = result.ageMatch!.months;
      if (_vetProvider.ageMonths != ageMonths) {
        _vetProvider.setAgeMonths(ageMonths);
        somethingChanged = true;
        setState(() {
          _voiceHint = _voiceHint.isEmpty 
              ? 'Возраст: ${result.ageMatch!.matchedText}'
              : '$_voiceHint, возраст: ${result.ageMatch!.matchedText}';
        });
      }
    }

    // Обрабатываем вес
    if (result.hasWeight) {
      _weightController.text = result.weight!.toInt().toString();
      _vetProvider.setWeight(result.weight!);
      _validateWeight(result.weight!);
      somethingChanged = true;
    }

    // Обрабатываем препарат
    if (result.hasDrug && result.drugMatch != null) {
      final found = _vetProvider.findDrugByName(result.drugMatch!.inn);
      if (found) {
        somethingChanged = true;
        setState(() {
          _voiceHint = _voiceHint.isEmpty 
              ? 'Препарат найден: ${result.drugMatch!.matchedAlias}'
              : '$_voiceHint, препарат: ${result.drugMatch!.matchedAlias}';
        });
      } else {
        setState(() {
          _voiceStatusText = 'Препарат "${result.drugMatch!.matchedAlias}" не найден';
        });
      }
    }

    // Обновляем подсказку
    if (!result.hasAnimal && !result.hasWeight && !result.hasDrug && !result.hasGender && !result.hasAge) {
      setState(() {
        _voiceHint = 'Не распознано. Попробуйте: "крс самка 2 года 400 кг энрофлоксацин"';
      });
    }

    setState(() {});

    // Если что-то изменилось и есть результат - озвучиваем
    if (somethingChanged && _vetProvider.result.hasResult && _autoSpeakResult) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_vetProvider.result.hasResult) {
          _speakResult();
        }
      });
    }

    // ПЕРЕЗАПУСК: После завершения STT перезапускаем Vosk если wake word был включен
    // Это критично для микрофонного менеджмента — Vosk и STT не могут работать одновременно
    _restartWakeWordIfNeeded();
  }

  /// Перезапускает wake word (Vosk) если пользователь ранее его включил
  /// Вызывается после завершения STT сессии
  void _restartWakeWordIfNeeded() {
    if (!_wasWakeWordManuallyEnabled) return;
    if (_isListening) return; // STT ещё слушает
    if (_handsFreeMode) return; // Hands-free режим активен
    
    // Отменяем предыдущий таймер если был
    _wakeWordRestartTimer?.cancel();
    
    // Даём время STT полностью освободить микрофон
    _wakeWordRestartTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (!_wasWakeWordManuallyEnabled || _isListening || _handsFreeMode) return;
      
      debugPrint('🔄 Restarting Vosk wake word after STT session');
      _wakeWordService.startListening().then((_) {
        if (mounted) {
          setState(() {
            _wakeWordEnabled = true;
            _wakeWordAnimationController.repeat();
          });
        }
      });
    });
  }

  void _onMicTap() {
    if (_isTransitioning) return;
    if (_isListening) {
      _speechService.stopListening();
      // Если wake word был активен — перезапускаем его после остановки STT
      if (_wakeWordEnabled) {
        _wakeWordRestartTimer?.cancel();
        _wakeWordRestartTimer = Timer(const Duration(milliseconds: 500), () {
          if (_wakeWordEnabled && !_isListening && mounted) {
            _wakeWordService.startListening();
          }
        });
      }
    } else {
      // КРИТИЧЕСКИ: останавливаем Vosk перед STT — микрофон не может быть занят двумя сервисами
      if (_wakeWordEnabled) {
        // Используем callback для ожидания освобождения микрофона
        _wakeWordService.setMicReleaseCallback(() {
          _wakeWordService.clearMicReleaseCallback();
          if (mounted) {
            _speechService.startListening();
          }
        });
        _wakeWordService.stopListening();
      } else {
        _speechService.startListening();
      }
    }
  }

  void _onAnimalSelected(String animalId) {
    _vetProvider.selectAnimal(animalId);
    if (_vetProvider.weight > 0) {
      _validateWeight(_vetProvider.weight);
    }
    setState(() {});
  }

  void _onDrugSelected(dynamic drug) {
    debugPrint('🔍 _onDrugSelected: ${drug.runtimeType}');
    if (drug is CalcDrug) {
      debugPrint('✅ Выбран CalcDrug: ${drug.name}');
      _vetProvider.selectDrug(drug);
    } else if (drug is Drug) {
      debugPrint('✅ Выбран Drug: ${drug.name}');
      _vetProvider.selectDrug(drug);
    } else if (drug is RegistryDrug) {
      debugPrint('✅ Выбран RegistryDrug: ${drug.tradeName}');
      _vetProvider.selectRegistryDrug(drug);
    } else {
      debugPrint('❌ Неизвестный тип препарата: ${drug.runtimeType}');
    }
    _dismissKeyboard();
    setState(() {});
    // Автоскролл к результату если он есть
    if (_vetProvider.result.hasResult) _scrollToResult();
  }

  void _onWeightChanged(String value) {
    final weight = double.tryParse(value);
    if (weight != null) {
      _vetProvider.setWeight(weight);
      _validateWeight(weight);
    } else {
      _vetProvider.setWeight(0);
      _weightValidation = null;
    }
    setState(() {});
  }

  void _validateWeight(double weight) {
    final animal = _vetProvider.selectedAnimal;
    if (animal != null) {
      _weightValidation = animal.validateWeight(weight);
    } else {
      _weightValidation = null;
    }
  }

  void _speakResult() {
    final text = _vetProvider.getResultSpeechText();
    if (text.isNotEmpty) {
      _speechService.speak(text);
    } else if (!_vetProvider.result.hasResult) {
      _speechService.speak('Результат пока не рассчитан. Укажите животное, вес и препарат.');
    }
  }

  void _resetForm() {
    _weightController.clear();
    _vetProvider.reset();
    _weightValidation = null;
    _voiceStatusText = '';
    _voiceHint = '';
    setState(() {});
  }

  Widget _buildNavButton({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMedium), boxShadow: AppTheme.softShadow),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          ])),
          const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    // Отменяем все StreamSubscription чтобы не было утечек
    _onWordsRecognizedSub?.cancel();
    _onSTTStateChangedSub?.cancel();
    _onCommandSub?.cancel();
    _onSTTErrorSub?.cancel();
    _onWakeWordSub?.cancel();
    _onWakeWordStateChangedSub?.cancel();
    _onWakeWordErrorSub?.cancel();
    _onWakeWordPartialSub?.cancel();
    _onDownloadProgressSub?.cancel();

    // Снимаем mic release callback
    _wakeWordService.clearMicReleaseCallback();

    // Отменяем отложенные таймеры
    _wakeWordRestartTimer?.cancel();

    _weightController.dispose();
    _weightFocusNode.dispose();
    _scrollController.dispose();
    _speechService.dispose();
    _wakeWordService.dispose(); // Не убивает — только стопит
    _handsFreeController.dispose();
    _wakeWordAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _vetProvider.isLoading
            ? _buildLoadingScreen()
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.safeGreen,
          ),
          const SizedBox(height: 24),
          Text(
            _vetProvider.statusMessage,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Закрыть клавиатуру при тапе вне поля
  void _dismissKeyboard() {
    _weightFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Widget _buildMainContent() {
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          
          // Hands-free режим переключатель
          _buildHandsFreeToggle(),
          
          const SizedBox(height: 24),
          _buildAnimalSelector(),
          
          if (_vetProvider.selectedAnimalId != null) ...[
            const SizedBox(height: 20),
            AnimalParamsSelector(
              gender: _vetProvider.gender,
              pregnancyPeriod: _vetProvider.pregnancyPeriod,
              ageMonths: _vetProvider.ageMonths,
              ageCategory: _vetProvider.ageCategory,
              pregnancyTerm: _vetProvider.selectedAnimal?.pregnancyTerm ?? 'Беременность',
              showGender: _vetProvider.selectedAnimal?.hasGender ?? true,
              onGenderChanged: (g) => setState(() => _vetProvider.setGender(g)),
              onPregnancyChanged: (p) => setState(() => _vetProvider.setPregnancyPeriod(p)),
              onAgeChanged: (a) => setState(() => _vetProvider.setAgeMonths(a)),
            ),
          ],
          
          const SizedBox(height: 24),
          _buildInputBlock(),
          
          const SizedBox(height: 24),
          _buildMicButton(),
          
          if (_voiceStatusText.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildVoiceStatus(),
          ],
          
          if (_voiceHint.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildVoiceHint(),
          ],
          
          const SizedBox(height: 24),
          ResultCard(
            result: _vetProvider.result,
            onSpeak: _speakResult,
          ),
          
          const SizedBox(height: 24),
          _buildQuickActions(),
          
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  Widget _buildHandsFreeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _handsFreeMode 
            ? AppTheme.safeGreen.withOpacity(0.1)
            : AppTheme.backgroundFor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _handsFreeMode 
              ? AppTheme.safeGreen.withOpacity(0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // Анимированный индикатор hands-free
          AnimatedBuilder(
            animation: _handsFreeController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _handsFreeMode
                      ? AppTheme.safeGreen.withOpacity(0.5 + _handsFreeController.value * 0.5)
                      : AppTheme.textTertiary,
                  boxShadow: _handsFreeMode
                      ? [
                          BoxShadow(
                            color: AppTheme.safeGreen.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Режим без рук',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _handsFreeMode ? AppTheme.safeGreen : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _handsFreeMode 
                      ? 'Автоматическое распознавание'
                      : 'Скажите "без рук" для активации',
                  style: TextStyle(
                    fontSize: 12,
                    color: _handsFreeMode ? AppTheme.safeGreen : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: _handsFreeMode,
            onChanged: (_) => _toggleHandsFree(),
            activeColor: AppTheme.safeGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'VetVoice AI',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            // Компактный AppBar: 3 главные + меню
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Поиск по симптомам
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SymptomSearchScreen(
                        onDrugSelected: (drug) => _vetProvider.selectDrug(drug),
                      ),
                    ));
                  },
                  icon: const Icon(Icons.search),
                  color: AppTheme.safeGreen,
                  tooltip: 'Поиск по симптомам',
                ),
                // Избранное
                IconButton(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                  icon: const Icon(Icons.star_border),
                  color: AppTheme.warningOrange,
                  tooltip: 'Избранное',
                ),
                // История
                IconButton(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  icon: const Icon(Icons.history),
                  color: AppTheme.textSecondaryFor(context),
                  tooltip: 'История',
                ),
                // Wake word
                _buildWakeWordButton(),
                // Автоозвучивание
                IconButton(
                  onPressed: () => setState(() => _autoSpeakResult = !_autoSpeakResult),
                  icon: Icon(_autoSpeakResult ? Icons.volume_up : Icons.volume_off,
                    color: _autoSpeakResult ? AppTheme.safeGreen : AppTheme.textTertiary),
                  tooltip: _autoSpeakResult ? 'Автоозвучивание вкл' : 'Автоозвучивание выкл',
                ),
                // Меню с остальными инструментами
                PopupMenuButton<String>(
                  icon: Icon(Icons.apps, color: AppTheme.textSecondaryFor(context)),
                  tooltip: 'Инструменты',
                  onSelected: (value) {
                    switch (value) {
                      case 'protocols':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TreatmentProtocolsScreen(
                            vetProvider: _vetProvider,
                            onDrugSelected: (drug) => _vetProvider.selectDrug(drug),
                          ),
                        ));
                        break;
                      case 'interactions':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => InteractionsCheckerScreen(vetProvider: _vetProvider),
                        ));
                        break;
                      case 'withdrawal':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => WithdrawalCalculatorScreen(vetProvider: _vetProvider),
                        ));
                        break;
                      case 'infusion':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const InfusionCalculatorScreen(),
                        ));
                        break;
                      case 'diseases':
                        _openDiseasesScreen();
                        break;
                      case 'fluid':
                        if (_vetProvider.fluidTherapyDatabase != null) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FluidTherapyScreen(db: _vetProvider.fluidTherapyDatabase!),
                          ));
                        }
                        break;
                      case 'settings':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ));
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'protocols', child: ListTile(
                      leading: Icon(Icons.medical_information_outlined), title: Text('Протоколы'),
                      dense: true,
                    )),
                    const PopupMenuItem(value: 'interactions', child: ListTile(
                      leading: Icon(Icons.compare_arrows), title: Text('Совместимость'),
                      dense: true,
                    )),
                    const PopupMenuItem(value: 'withdrawal', child: ListTile(
                      leading: Icon(Icons.schedule), title: Text('Каренция'),
                      dense: true,
                    )),
                    const PopupMenuItem(value: 'infusion', child: ListTile(
                      leading: Icon(Icons.calculate), title: Text('Инфузия'),
                      dense: true,
                    )),
                    if (_vetProvider.diseasesCount > 0)
                      const PopupMenuItem(value: 'diseases', child: ListTile(
                        leading: Icon(Icons.coronavirus_outlined), title: Text('Болезни'),
                        dense: true,
                      )),
                    if (_vetProvider.fluidTherapyDatabase != null)
                      const PopupMenuItem(value: 'fluid', child: ListTile(
                        leading: Icon(Icons.water_drop), title: Text('Инфуз. терапия'),
                        dense: true,
                      )),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'settings', child: ListTile(
                      leading: Icon(Icons.settings_outlined), title: Text('Настройки'),
                      dense: true,
                    )),
                  ],
                ),
              ],
            ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _vetProvider.isOnline ? AppTheme.safeGreen : AppTheme.warningOrange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _wakeWordService.isModelLoading
                    ? '🎤 ${_wakeWordService.loadingMessage}'
                    : (_wakeWordService.errorMessage != null
                        ? '⚠️ ${_wakeWordService.errorMessage}'
                        : (_wakeWordEnabled
                            ? '🎤 Скажите "ВетВойс"...'
                            : _vetProvider.statusMessage)),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSmall,
                  color: _wakeWordService.errorMessage != null
                      ? AppTheme.errorRed
                      : AppTheme.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Показываем что услышал wake word сервис
        if (_wakeWordEnabled && _wakeWordHeard.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Слышу: "$_wakeWordHeard"',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.safeGreen,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  /// Индикатор загрузки модели wake word — показывает конкретный этап и прогресс
  Widget _buildWakeWordLoadingIndicator() {
    final dl = _wakeWordService.downloadedMB;
    final total = _wakeWordService.totalMB;
    final message = _wakeWordService.loadingMessage;
    final isExtracting = _wakeWordService.isExtracting;

    // Определяем что показываем: МБ при скачивании, файлы при распаковке, текст при остальном
    String label;
    double? progress;

    if (isExtracting) {
      // "Распаковка: 45 / 210"
      label = message.isNotEmpty ? message : 'Распаковка...';
      // Прогресс по файлам: downloadedMB=текущие файлы, totalMB=всего файлов
      if (total > 0 && dl > 0) {
        progress = (dl / total).clamp(0.0, 1.0);
      }
    } else if (dl > 0 && total > 0 && total <= 100) {
      // Скачивание в МБ (total обычно ~44)
      label = '${dl.toStringAsFixed(dl >= 10 ? 0 : 1)} / ${total.toStringAsFixed(0)} МБ';
      progress = (dl / total).clamp(0.0, 1.0);
    } else {
      label = message.isNotEmpty ? message : 'Загрузка...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Круговой прогресс с процентами
          SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: AppTheme.safeGreen,
                  backgroundColor: AppTheme.safeGreen.withOpacity(0.12),
                ),
                if (progress != null && progress > 0.05)
                  Center(
                    child: Text(
                      '${(progress * 100).toInt()}',
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.safeGreen,
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.safeGreen,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Текст этапа
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.safeGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Виджет кнопки wake word - слушает "ВетВойс" как Ok Google
  Widget _buildWakeWordButton() {
    final isReady = _wakeWordService.isInitialized;
    final isLoading = _wakeWordService.isModelLoading;
    final isActive = _wakeWordEnabled && _wakeWordService.isListening;
    
    // Если модель загружается - показываем прогресс по этапам
    if (isLoading) {
      return _buildWakeWordLoadingIndicator();
    }
    
    // Кнопка ошибки
    if (_wakeWordService.errorMessage != null) {
      return GestureDetector(
        onTap: _toggleWakeWord,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.errorRed.withOpacity(0.1),
            border: Border.all(color: AppTheme.errorRed.withOpacity(0.5), width: 1),
          ),
          child: const Icon(Icons.spatial_audio_off_outlined, size: 22, color: AppTheme.errorRed),
        ),
      );
    }
    
    return GestureDetector(
      onTap: _toggleWakeWord,
      child: AnimatedBuilder(
        animation: _wakeWordAnimationController,
        builder: (context, child) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _wakeWordEnabled 
                  ? AppTheme.safeGreen.withOpacity(0.1 + _wakeWordAnimationController.value * 0.15)
                  : AppTheme.backgroundFor(context),
              border: Border.all(
                color: _wakeWordEnabled 
                    ? AppTheme.safeGreen.withOpacity(0.5 + _wakeWordAnimationController.value * 0.5)
                    : (isReady ? AppTheme.dividerGray : AppTheme.warningOrange),
                width: _wakeWordEnabled ? 2 : 1,
              ),
              boxShadow: _wakeWordEnabled
                  ? [
                      BoxShadow(
                        color: AppTheme.safeGreen.withOpacity(0.2 + _wakeWordAnimationController.value * 0.3),
                        blurRadius: 8 + _wakeWordAnimationController.value * 8,
                        spreadRadius: 2 + _wakeWordAnimationController.value * 4,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Иконка
                Icon(
                  _wakeWordEnabled ? Icons.spatial_audio_off : Icons.spatial_audio_off_outlined,
                  size: 22,
                  color: _wakeWordEnabled 
                      ? AppTheme.safeGreen 
                      : (isReady ? AppTheme.textTertiary : AppTheme.warningOrange),
                ),
                // Индикатор "слушает"
                if (isActive)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.safeGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimalSelector() {
    final animals = _vetProvider.animals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Выберите животное',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Можно выбрать голосом: "собака", "корова", "кошка"...',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: animals.length,
          itemBuilder: (context, index) {
            final animal = animals[index];
            return AnimalCard(
              animal: animal,
              isSelected: _vetProvider.selectedAnimalId == animal.id,
              onTap: () => _onAnimalSelected(animal.id),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInputBlock() {
    final animal = _vetProvider.selectedAnimal;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Вес животного',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (animal != null)
              Text(
                '${animal.minWeight}-${animal.maxWeight > 100 ? "${animal.maxWeight.toStringAsFixed(0)}" : animal.maxWeight} кг',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
          ],
        ),
        
        if (animal != null && animal.weightHint.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            animal.weightHint,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        
        const SizedBox(height: 8),
        
        TextField(
          controller: _weightController,
          focusNode: _weightFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: _weightValidation?.hasError == true 
                ? AppTheme.errorRed 
                : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Введите вес или скажите',
            suffixText: 'кг',
            suffixStyle: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          onChanged: _onWeightChanged,
          onSubmitted: (_) => _dismissKeyboard(),
        ),
        
        // Быстрые кнопки веса для животного
        if (animal != null) ...[
          const SizedBox(height: 8),
          _buildWeightPresets(animal),
        ],
        
        if (_weightValidation != null && 
            (_weightValidation!.hasError || _weightValidation!.hasWarning)) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _weightValidation!.hasError 
                  ? AppTheme.errorRed.withOpacity(0.1)
                  : AppTheme.warningOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: _weightValidation!.hasError 
                    ? AppTheme.errorRed.withOpacity(0.3)
                    : AppTheme.warningOrange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _weightValidation!.hasError ? Icons.error_outline : Icons.warning_amber_outlined,
                  size: 20,
                  color: _weightValidation!.hasError 
                      ? AppTheme.errorRed 
                      : AppTheme.warningOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _weightValidation!.hasError 
                        ? _weightValidation!.error 
                        : _weightValidation!.warning,
                    style: TextStyle(
                      fontSize: 13,
                      color: _weightValidation!.hasError 
                          ? AppTheme.errorRed 
                          : AppTheme.warningOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Препарат',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '${_vetProvider.totalDrugs} препаратов',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Назовите препарат: "энрофлоксацин", "амоксициллин"...',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        DrugDropdown(
          drugs: _vetProvider.availableDrugs,
          selectedDrug: _vetProvider.selectedDrug ?? _vetProvider.selectedRegistryDrug,
          onDrugSelected: _onDrugSelected,
          hintText: 'Поиск по названию или МНН...',
        ),
        
        // Селектор способа введения (показываем только если препарат выбран)
        if (_vetProvider.selectedDrug != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Способ введения',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          MethodSelector(
            availableMethodsString: _vetProvider.selectedDrug?.method ?? '',
            selectedMethod: _vetProvider.selectedMethod,
            onMethodChanged: (method) {
              setState(() {
                _vetProvider.setMethod(method);
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMicButton() {
    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Большая кнопка микрофона
              GestureDetector(
                onTap: _onMicTap,
                onLongPress: _toggleHandsFree,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _handsFreeMode 
                        ? AppTheme.safeGreen
                        : (_isListening ? AppTheme.safeGreen : AppTheme.textPrimary),
                    boxShadow: [
                      BoxShadow(
                        color: (_handsFreeMode || _isListening)
                            ? AppTheme.safeGreen.withOpacity(0.5)
                            : AppTheme.textPrimary.withOpacity(0.3),
                        blurRadius: _isListening ? 30 : 20,
                        spreadRadius: _isListening ? 5 : 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Статус
        Text(
          _isListening 
              ? 'Слушаю...' 
              : (_handsFreeMode 
                  ? 'Режим без рук активен' 
                  : 'Нажмите для голосового ввода'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _isListening 
                ? AppTheme.safeGreen 
                : (_handsFreeMode ? AppTheme.safeGreen : AppTheme.textSecondary),
          ),
        ),
        
        if (_isListening) ...[
          const SizedBox(height: 8),
          SoundWaveVisualizer(isActive: true),
        ],
        
        const SizedBox(height: 8),
        Text(
          'Удерживайте для режима без рук',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.safeGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.record_voice_over,
            color: AppTheme.safeGreen,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _voiceStatusText,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundFor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        _voiceHint,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _openDiseasesScreen() {
    if (_vetProvider.diseaseDatabase != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiseasesScreen(
            database: _vetProvider.diseaseDatabase!,
            treatmentDatabase: _vetProvider.treatmentProtocolDatabase,
            selectedAnimal: _vetProvider.selectedAnimal?.name,
          ),
        ),
      );
    }
  }

  void _openCompatibilityChecker() {
    final db = _vetProvider.interactionDatabase;
    if (db == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              // Ручка для перетаскивания
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerFor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              CompatibilityChecker(
                interactionDb: db,
                allDrugs: _vetProvider.allDrugs,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Быстрые команды',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickActionChip(
              _wakeWordEnabled ? 'ВетВойс выкл' : 'ВетВойс',
              _wakeWordEnabled ? Icons.spatial_audio_off : Icons.spatial_audio_off_outlined,
              _toggleWakeWord,
              isActive: _wakeWordEnabled,
            ),
            if (_vetProvider.diseasesCount > 0)
              _buildQuickActionChip(
                'Болезни',
                Icons.coronavirus_outlined,
                _openDiseasesScreen,
              ),
            if (_vetProvider.interactionDatabase != null && _vetProvider.interactionDatabase!.interactions.isNotEmpty)
              _buildQuickActionChip(
                'Совместимость',
                Icons.compare_arrows,
                _openCompatibilityChecker,
                isActive: false,
              ),
            _buildQuickActionChip('Сброс', Icons.refresh, _resetForm),
            _buildQuickActionChip('Повтори', Icons.volume_up, _speakResult),
            _buildQuickActionChip('Помощь', Icons.help_outline, _speakHelp),
            _buildQuickActionChip(
              _handsFreeMode ? 'Обычный режим' : 'Без рук',
              _handsFreeMode ? Icons.touch_app : Icons.pan_tool,
              _toggleHandsFree,
              isActive: _handsFreeMode,
            ),
          ],
        ),
      ],
    );
  }

  /// Быстрые пресеты веса для животного
  Widget _buildWeightPresets(dynamic animal) {
    // Получаем типичные веса
    List<double> presets;
    String animalId;
    if (animal is Animal) {
      animalId = animal.id;
      final mid = (animal.minWeight + animal.maxWeight) / 2;
      final step = (animal.maxWeight - animal.minWeight) / 4;
      presets = [
        animal.minWeight,
        animal.minWeight + step,
        mid,
        animal.maxWeight - step,
        animal.maxWeight,
      ];
    } else {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((w) {
          final label = w >= 100 ? '${w.toInt()}' : w >= 10 ? '${w.toInt()}' : '${w.toStringAsFixed(1)}';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                _weightController.text = label;
                _vetProvider.setWeight(w);
                _validateWeight(w);
                _dismissKeyboard();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.safeGreen.withOpacity(0.2)),
                ),
                child: Text(
                  '$label кг',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.safeGreen,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Автоскролл к карточке результата
  void _scrollToResult() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        // Скроллим вниз к результату
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildQuickActionChip(String label, IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: isActive ? AppTheme.safeGreen : AppTheme.textSecondary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isActive ? AppTheme.safeGreen.withOpacity(0.1) : AppTheme.backgroundFor(context),
      side: BorderSide(
        color: isActive ? AppTheme.safeGreen.withOpacity(0.3) : Colors.transparent,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        color: isActive ? AppTheme.safeGreen : AppTheme.textPrimary,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
