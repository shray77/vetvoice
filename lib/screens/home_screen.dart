import 'dart:async';
import 'package:flutter/material.dart';
import '../models/animal.dart';
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
import 'infusion_calculator_screen.dart';
import 'unofficial_protocols_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'symptom_search_screen.dart';
import 'treatment_protocols_screen.dart';
import 'interactions_checker_screen.dart';
import 'withdrawal_calculator_screen.dart';

export '../services/speech_service.dart' show VoiceGender;

/// Главный экран приложения VetVoice AI с голосовым управлением и современной дизайн-системой
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

  // Режим wake word (слушает "ВетВойс")
  bool _wakeWordEnabled = false;
  bool _wasWakeWordManuallyEnabled = false;
  String _wakeWordHeard = '';

  // Автоозвучивание результатов
  bool _autoSpeakResult = true;

  // Mutex для race conditions
  bool _isTransitioning = false;
  Timer? _wakeWordRestartTimer;

  late AnimationController _handsFreeController;
  late AnimationController _wakeWordAnimationController;

  // Stream подписки
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

    _onWordsRecognizedSub = _speechService.onWordsRecognized.listen(_handleVoiceInput);
    _onSTTStateChangedSub = _speechService.onListeningStateChanged.listen((isListening) {
      if (!mounted) return;
      final wasListening = _isListening;
      setState(() => _isListening = isListening);
      if (wasListening && !isListening) {
        _restartWakeWordIfNeeded();
      }
    });

    _onCommandSub = _speechService.onCommand.listen((command) {
      _handleVoiceCommand(command);
      _restartWakeWordIfNeeded();
    });

    _onSTTErrorSub = _speechService.onError.listen(_handleVoiceError);
    _onWakeWordSub = _wakeWordService.onWakeWord.listen(_handleWakeWord);
    _onWakeWordStateChangedSub = _wakeWordService.onListeningStateChanged.listen((isListening) {
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

    _wakeWordAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  Future<void> _initializeApp() async {
    await _vetProvider.initialize();
    await _speechService.initializeSTT();
    await _speechService.initializeTTS();
    await _wakeWordService.initialize();

    if (!mounted) return;
    setState(() {});
  }

  void _restartWakeWordIfNeeded() {
    if (_wasWakeWordManuallyEnabled && !_wakeWordEnabled && !_isListening && !_handsFreeMode) {
      _wakeWordRestartTimer?.cancel();
      _wakeWordRestartTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && !_isListening && !_handsFreeMode && _wasWakeWordManuallyEnabled) {
          setState(() {
            _wakeWordEnabled = true;
          });
          _wakeWordAnimationController.repeat();
          _wakeWordService.startListening();
        }
      });
    }
  }

  void _handleWakeWord(_) {
    setState(() {
      _voiceStatusText = 'Слушаю команду...';
      _wakeWordEnabled = false;
      _wakeWordAnimationController.stop();
      _wakeWordAnimationController.reset();
    });

    _wakeWordService.setMicReleaseCallback(() async {
      _wakeWordService.clearMicReleaseCallback();
      if (!mounted) return;
      await _speechService.speak('Слушаю');
      if (!mounted) return;
      await _speechService.startListening();
    });
    _wakeWordService.stopListening();
  }

  void _handleWakeWordError(String error) {
    setState(() {
      _voiceStatusText = 'Ошибка wake word: $error';
    });
  }

  void _handleWakeWordPartial(String text) {
    setState(() {
      _wakeWordHeard = text;
    });
  }

  Future<void> _toggleWakeWord() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      _wakeWordEnabled = !_wakeWordEnabled;
      _wasWakeWordManuallyEnabled = _wakeWordEnabled;

      if (_wakeWordEnabled) {
        _wakeWordAnimationController.repeat();
        if (_speechService.isListening) {
          await _speechService.stopListening();
        }
        if (_handsFreeMode) {
          _handsFreeMode = false;
          _handsFreeController.stop();
          _speechService.setContinuousMode(false);
        }

        await _wakeWordService.startListening();
        if (_wakeWordService.isInitialized) {
          _speechService.speak('Скажите ВетВойс для активации');
          setState(() => _wakeWordHeard = '');
        } else if (_wakeWordService.isModelLoading) {
          _speechService.speak('Загружается голосовая модель');
        }
      } else {
        _wasWakeWordManuallyEnabled = false;
        _wakeWordAnimationController.stop();
        _wakeWordAnimationController.reset();
        await _wakeWordService.stopListening();
        setState(() => _wakeWordHeard = '');
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
        _speechService.speak('Сброс выполнен.');
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

      case VoiceCommandType.earMode:
        _toggleWakeWord();
        break;

      default:
        break;
    }
  }

  void _speakHelp() {
    const helpText = '''
      Говорите: "собака 15 килограмм энрофлоксацин".
      Команды: стоп, повтори, сброс, помощь, без рук.
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
        if (_wakeWordEnabled) {
          _wakeWordEnabled = false;
          _wasWakeWordManuallyEnabled = false;
          _wakeWordAnimationController.stop();
          _wakeWordAnimationController.reset();
          await _wakeWordService.stopListening();
        }
        _startHandsFreeListening();
      } else {
        _handsFreeController.stop();
        _speechService.stopListening();
        _speechService.speak('Режим без рук выключен.');
      }

      setState(() {});
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _startHandsFreeListening() async {
    try {
      await _speechService.speak('Режим без рук включён.');
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

    final drugNames = _vetProvider.availableDrugs.map((d) {
      if (d is CalcDrug) return d.name;
      if (d is RegistryDrug) return d.tradeName;
      return '';
    }).toList();

    final result = VoiceInputParser.parse(text, availableDrugs: drugNames);
    bool somethingChanged = false;

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

    if (result.hasGender && result.genderMatch != null) {
      final gender = result.genderMatch!.gender == VoiceGender.male
          ? Gender.male
          : Gender.female;
      if (_vetProvider.gender != gender) {
        _vetProvider.setGender(gender);
        somethingChanged = true;
      }
    }

    if (result.hasAge && result.ageMatch != null) {
      final ageMonths = result.ageMatch!.months;
      if (_vetProvider.ageMonths != ageMonths) {
        _vetProvider.setAgeMonths(ageMonths);
        somethingChanged = true;
      }
    }

    if (result.hasWeight) {
      _weightController.text = result.weight!.toInt().toString();
      _vetProvider.setWeight(result.weight!);
      _validateWeight(result.weight!);
      somethingChanged = true;
    }

    if (result.hasDrug && result.drugMatch != null) {
      final found = _vetProvider.findDrugByName(result.drugMatch!.inn);
      if (found) {
        somethingChanged = true;
        setState(() {
          _voiceHint = 'Препарат: ${result.drugMatch!.matchedAlias}';
        });
      }
    }

    if (somethingChanged) {
      setState(() {});
      if (_vetProvider.result.hasResult) {
        _scrollToResult();
        if (_autoSpeakResult) {
          _speakResult();
        }
      }
    }
  }

  void _onMicTap() {
    if (_isTransitioning) return;
    if (_isListening) {
      _speechService.stopListening();
      if (_wakeWordEnabled) {
        _wakeWordRestartTimer?.cancel();
        _wakeWordRestartTimer = Timer(const Duration(milliseconds: 500), () {
          if (_wakeWordEnabled && !_isListening && mounted) {
            _wakeWordService.startListening();
          }
        });
      }
    } else {
      if (_wakeWordEnabled) {
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
    if (drug is CalcDrug) {
      _vetProvider.selectDrug(drug);
    } else if (drug is RegistryDrug) {
      _vetProvider.selectRegistryDrug(drug);
    }
    _dismissKeyboard();
    setState(() {});
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

  void _dismissKeyboard() {
    _weightFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  void _scrollToResult() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
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
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor(context),
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

  void _openToolsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Справочники и модули',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppTheme.textSecondaryColor(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                _buildToolCard(
                  icon: Icons.search_rounded,
                  color: AppTheme.safeGreen,
                  title: 'Симптомы',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SymptomSearchScreen(
                          onDrugSelected: (d) => _vetProvider.selectDrug(d),
                        ),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.medical_services_rounded,
                  color: AppTheme.maleBlue,
                  title: 'Протоколы',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TreatmentProtocolsScreen(
                          vetProvider: _vetProvider,
                          onDrugSelected: (d) => _vetProvider.selectDrug(d),
                        ),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.compare_arrows_rounded,
                  color: AppTheme.warningOrange,
                  title: 'Совместимость',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InteractionsCheckerScreen(
                          vetProvider: _vetProvider,
                        ),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.timer_outlined,
                  color: AppTheme.errorRed,
                  title: 'Каренция',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WithdrawalCalculatorScreen(
                          vetProvider: _vetProvider,
                        ),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.water_drop_rounded,
                  color: AppTheme.infoBlue,
                  title: 'Инфузии',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InfusionCalculatorScreen(),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.coronavirus_outlined,
                  color: const Color(0xFF8B5CF6),
                  title: 'Болезни',
                  onTap: () {
                    Navigator.pop(context);
                    _openDiseasesScreen();
                  },
                ),
                _buildToolCard(
                  icon: Icons.star_rounded,
                  color: AppTheme.warningOrange,
                  title: 'Избранное',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.history_rounded,
                  color: AppTheme.textSecondaryColor(context),
                  title: 'История',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      ),
                    );
                  },
                ),
                _buildToolCard(
                  icon: Icons.settings_rounded,
                  color: AppTheme.textTertiaryColor(context),
                  title: 'Настройки',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _onWordsRecognizedSub?.cancel();
    _onSTTStateChangedSub?.cancel();
    _onCommandSub?.cancel();
    _onSTTErrorSub?.cancel();
    _onWakeWordSub?.cancel();
    _onWakeWordStateChangedSub?.cancel();
    _onWakeWordErrorSub?.cancel();
    _onWakeWordPartialSub?.cancel();
    _onDownloadProgressSub?.cancel();

    _wakeWordService.clearMicReleaseCallback();
    _wakeWordRestartTimer?.cancel();

    _weightController.dispose();
    _weightFocusNode.dispose();
    _scrollController.dispose();
    _speechService.dispose();
    _wakeWordService.dispose();
    _handsFreeController.dispose();
    _wakeWordAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
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
          const CircularProgressIndicator(color: AppTheme.safeGreen),
          const SizedBox(height: 20),
          Text(
            _vetProvider.statusMessage,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),

            // Быстрый доступ к инструментам (горизонтальная лента)
            _buildQuickToolsRail(),
            const SizedBox(height: 14),

            // Панель голосового контроля (Hands-free / Wake Word)
            _buildVoiceStatusBanner(),
            const SizedBox(height: 16),

            // Выбор животного
            _buildAnimalSelector(),

            // Параметры животного (пол, беременность, возраст)
            if (_vetProvider.selectedAnimalId != null) ...[
              const SizedBox(height: 16),
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

            const SizedBox(height: 16),
            _buildInputBlock(),

            const SizedBox(height: 20),
            _buildMicButtonStation(),

            if (_voiceStatusText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildVoiceStatus(),
            ],

            if (_voiceHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildVoiceHint(),
            ],

            const SizedBox(height: 20),
            ResultCard(
              result: _vetProvider.result,
              onSpeak: _speakResult,
              onDoseChanged: (dose) {
                _vetProvider.setCustomDose(dose);
                setState(() {});
              },
              animalName: _vetProvider.selectedAnimal?.name,
              weightKg: _vetProvider.weight,
            ),

            const SizedBox(height: 16),
            _buildQuickActions(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Логотип и статус
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Center(
                child: Icon(Icons.pets_rounded, color: AppTheme.safeGreen, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'VetVoice AI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _vetProvider.isOnline ? AppTheme.safeGreen : AppTheme.warningOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  _wakeWordEnabled ? 'Голос активен' : 'Готов к расчётам',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Компактный кластер кнопок (без перегрузки!)
        Row(
          children: [
            // Кнопка Wake Word
            _buildCompactWakeWordButton(),
            const SizedBox(width: 6),

            // Кнопка автоозвучки
            IconButton(
              icon: Icon(
                _autoSpeakResult ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: _autoSpeakResult ? AppTheme.safeGreen : AppTheme.textTertiaryColor(context),
                size: 22,
              ),
              onPressed: () => setState(() => _autoSpeakResult = !_autoSpeakResult),
              tooltip: _autoSpeakResult ? 'Озвучка включена' : 'Озвучка выключена',
            ),

            // Кнопка всех инструментов (Bottom Sheet)
            IconButton(
              icon: Icon(Icons.grid_view_rounded, color: AppTheme.textPrimaryColor(context), size: 22),
              onPressed: _openToolsBottomSheet,
              tooltip: 'Все инструменты',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactWakeWordButton() {
    final isDark = AppTheme.isDark(context);

    if (_wakeWordService.isModelLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.safeGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.safeGreen),
            ),
            SizedBox(width: 4),
            Text('Загрузка', style: TextStyle(fontSize: 10, color: AppTheme.safeGreen, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _toggleWakeWord,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _wakeWordEnabled
              ? AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.15)
              : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _wakeWordEnabled ? AppTheme.safeGreen : AppTheme.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _wakeWordEnabled ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
              size: 16,
              color: _wakeWordEnabled ? AppTheme.safeGreen : AppTheme.textSecondaryColor(context),
            ),
            const SizedBox(width: 4),
            Text(
              _wakeWordEnabled ? 'Слушает' : 'ВетВойс',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _wakeWordEnabled ? AppTheme.safeGreen : AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToolsRail() {
    final isDark = AppTheme.isDark(context);

    final tools = [
      {'title': 'Симптомы', 'icon': Icons.search_rounded, 'color': AppTheme.safeGreen, 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SymptomSearchScreen(onDrugSelected: (d) => _vetProvider.selectDrug(d))));
      }},
      {'title': 'Протоколы', 'icon': Icons.medical_services_rounded, 'color': AppTheme.maleBlue, 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => TreatmentProtocolsScreen(vetProvider: _vetProvider, onDrugSelected: (d) => _vetProvider.selectDrug(d))));
      }},
      {'title': 'Совместимость', 'icon': Icons.compare_arrows_rounded, 'color': AppTheme.warningOrange, 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => InteractionsCheckerScreen(vetProvider: _vetProvider)));
      }},
      {'title': 'Каренция', 'icon': Icons.timer_outlined, 'color': AppTheme.errorRed, 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawalCalculatorScreen(vetProvider: _vetProvider)));
      }},
      {'title': 'Инфузии', 'icon': Icons.water_drop_rounded, 'color': AppTheme.infoBlue, 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const InfusionCalculatorScreen()));
      }},
      {'title': 'Болезни', 'icon': Icons.coronavirus_outlined, 'color': const Color(0xFF8B5CF6), 'action': _openDiseasesScreen},
      {'title': 'Избранное', 'icon': Icons.star_rounded, 'color': AppTheme.warningOrange, 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
      }},
      {'title': 'История', 'icon': Icons.history_rounded, 'color': AppTheme.textSecondaryColor(context), 'action': () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
      }},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final t = tools[idx];
          final color = t['color'] as Color;
          return InkWell(
            onTap: t['action'] as VoidCallback,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : AppTheme.cardLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(t['icon'] as IconData, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    t['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoiceStatusBanner() {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _handsFreeMode
            ? AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.12)
            : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _handsFreeMode ? AppTheme.safeGreen.withOpacity(0.4) : AppTheme.borderColor(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _handsFreeMode ? Icons.pan_tool_alt_rounded : Icons.touch_app_rounded,
            size: 18,
            color: _handsFreeMode ? AppTheme.safeGreen : AppTheme.textSecondaryColor(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _handsFreeMode ? 'Режим "Без рук" активен' : 'Голосовое управление',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _handsFreeMode ? AppTheme.safeGreen : AppTheme.textPrimaryColor(context),
                  ),
                ),
                Text(
                  _handsFreeMode
                      ? 'Слушает непрерывно...'
                      : 'Нажмите микрофон или включите Hands-Free',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _handsFreeMode,
              onChanged: (_) => _toggleHandsFree(),
              activeColor: AppTheme.safeGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalSelector() {
    final animals = _vetProvider.animals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Выберите вид животного',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            Text(
              'или назовите голосом',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiaryColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.05,
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

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Вес пациента',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              if (animal != null)
                Text(
                  'Диапазон: ${animal.minWeight}-${animal.maxWeight > 100 ? animal.maxWeight.toStringAsFixed(0) : animal.maxWeight} кг',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weightController,
            focusNode: _weightFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _weightValidation?.hasError == true
                  ? AppTheme.errorRed
                  : AppTheme.textPrimaryColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'Введите вес (напр. 15)',
              suffixText: 'кг',
              suffixStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            onChanged: _onWeightChanged,
            onSubmitted: (_) => _dismissKeyboard(),
          ),

          if (animal != null) ...[
            const SizedBox(height: 8),
            _buildWeightPresets(animal),
          ],

          if (_weightValidation != null &&
              (_weightValidation!.hasError || _weightValidation!.hasWarning)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_weightValidation!.hasError ? AppTheme.errorRed : AppTheme.warningOrange).withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: (_weightValidation!.hasError ? AppTheme.errorRed : AppTheme.warningOrange).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _weightValidation!.hasError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                    size: 18,
                    color: _weightValidation!.hasError ? AppTheme.errorRed : AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _weightValidation!.hasError
                          ? _weightValidation!.error
                          : _weightValidation!.warning,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _weightValidation!.hasError ? AppTheme.errorRed : AppTheme.warningOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: AppTheme.dividerColor(context), height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Препарат',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                '${_vetProvider.totalDrugs} в базе',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DrugDropdown(
            drugs: _vetProvider.availableDrugs,
            selectedDrug: _vetProvider.selectedDrug ?? _vetProvider.selectedRegistryDrug,
            onDrugSelected: _onDrugSelected,
            hintText: 'Поиск по названию или МНН...',
          ),

          if (_vetProvider.selectedDrug != null) ...[
            const SizedBox(height: 14),
            Text(
              'Способ введения',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 6),
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
      ),
    );
  }

  Widget _buildWeightPresets(Animal animal) {
    final step = (animal.maxWeight - animal.minWeight) / 4;
    final presets = [
      animal.minWeight,
      animal.minWeight + step,
      (animal.minWeight + animal.maxWeight) / 2,
      animal.maxWeight - step,
      animal.maxWeight,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((w) {
          final label = w >= 100 ? '${w.toInt()}' : (w >= 10 ? '${w.toInt()}' : w.toStringAsFixed(1));
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                _weightController.text = label;
                _vetProvider.setWeight(w);
                _validateWeight(w);
                _dismissKeyboard();
                setState(() {});
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.safeGreen.withOpacity(0.25)),
                ),
                child: Text(
                  '$label кг',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

  Widget _buildMicButtonStation() {
    return Center(
      child: Column(
        children: [
          MicButton(
            isListening: _isListening,
            onTap: _onMicTap,
            onLongPress: _toggleHandsFree,
          ),
          const SizedBox(height: 10),
          Text(
            _isListening
                ? 'Слушаю пациента...'
                : (_handsFreeMode ? 'Режим "Без рук" активен' : 'Нажмите для записи команды'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isListening
                  ? AppTheme.safeGreen
                  : (_handsFreeMode ? AppTheme.safeGreen : AppTheme.textSecondaryColor(context)),
            ),
          ),
          if (_isListening) ...[
            const SizedBox(height: 8),
            const SoundWaveVisualizer(isActive: true),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.record_voice_over_rounded, color: AppTheme.safeGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _voiceStatusText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context) ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        _voiceHint,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondaryColor(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Быстрые действия',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildActionChip('Сброс', Icons.refresh_rounded, _resetForm),
            _buildActionChip('Повторить', Icons.replay_rounded, _speakResult),
            _buildActionChip('Помощь', Icons.help_outline_rounded, _speakHelp),
            _buildActionChip('Совместимость', Icons.compare_arrows_rounded, _openCompatibilityChecker),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context) ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondaryColor(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
