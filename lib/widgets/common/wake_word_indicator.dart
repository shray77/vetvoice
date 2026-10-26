// WakeWordIndicator — пульсирующая плашка «ВетВойс слушает» (Фаза 3, v1.19.0).
//
// ЗАЧЕМ: индикатор фонового слушания wake word жил ТОЛЬКО в кнопке на
// вкладке «Калькулятор» (home_screen, пульс через _wakeWordAnimationController).
// После Фазы 2 shell слушает на любой вкладке (IndexedStack), но на «Главной»
// и «Ещё» активности микрофона видно не было — непонятно, включён ли wake word
// вообще. Плашка над нижней навигацией видна на всех вкладках.
//
// ЧИСТЫЙ ВИЗУАЛ: читает state WakeWordService и подписан на его стримы
// (тот же паттерн, что VoiceStatusBar). Пайплайн STT/Vosk не трогается:
// никаких start/stop/initialize — только наблюдение.
import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/wake_word_service.dart';
import '../../utils/app_theme.dart';

class WakeWordIndicator extends StatefulWidget {
  const WakeWordIndicator({super.key});

  @override
  State<WakeWordIndicator> createState() => _WakeWordIndicatorState();
}

class _WakeWordIndicatorState extends State<WakeWordIndicator>
    with SingleTickerProviderStateMixin {
  final WakeWordService _service = WakeWordService.instance;
  // ГРАБЛЯ (поймал golden-тест 06_shell, Task 176): late final означал
  // ЛЕНИВУЮ инициализацию — если пульс ни разу не тронули (wake word не
  // слушал), первое обращение случалось в dispose() → AnimationController
  // создавался на ДЕАКТИВИРОВАННОМ элементе → «Looking up a deactivated
  // widget's ancestor is unsafe». Лечится явным созданием в initState.
  late final AnimationController _pulse;
  StreamSubscription? _subState;
  StreamSubscription? _subListen;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _subState = _service.onStateChanged.listen((_) => _safeSetState());
    _subListen =
        _service.onListeningStateChanged.listen((_) => _safeSetState());
    if (_isListening) _pulse.repeat(reverse: true);
  }

  bool get _isListening =>
      _service.state == 'LISTENING' && _service.isListening;

  void _safeSetState() {
    if (!mounted) return;
    setState(() {});
    // Пульс строго пока слушаем (урок MicButton: старт/стоп по состоянию,
    // а не по факту перестройки).
    if (_isListening) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) {
        _pulse.stop();
        _pulse.reset();
      }
    }
  }

  @override
  void dispose() {
    _subState?.cancel();
    _subListen?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Зависимость от Theme — плашка живёт в шелле на всех вкладках
    // (урок v1.18.1: IndexedStack-дети без Theme.of не перестраиваются).
    Theme.of(context);
    if (!_isListening) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final double t = _pulse.value;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.isDarkNow
                ? AppTheme.darkSurfaceLight
                : AppTheme.successContainer,
            borderRadius:
                const BorderRadius.all(Radius.circular(AppTheme.radiusPill)),
            border: Border.all(
              color: (AppTheme.isDarkNow ? AppTheme.darkSuccess : AppTheme.success)
                  .withAlpha(60 + (t * 80).round()),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Пульсирующая точка «микрофон активен»
              Transform.scale(
                scale: 1.0 + t * 0.35,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.isDarkNow
                        ? AppTheme.darkSuccess
                        : AppTheme.success,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ВетВойс слушает',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.isDarkNow
                      ? AppTheme.darkSuccess
                      : AppTheme.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
