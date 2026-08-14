import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Кнопка микрофона с анимацией пульсации
class MicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final bool enabled;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация пульсации (масштаб)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Анимация кругов (ripple effect)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _startListeningAnimation();
    } else if (!widget.isListening && oldWidget.isListening) {
      _stopListeningAnimation();
    }
  }

  void _startListeningAnimation() {
    _pulseController.repeat(reverse: true);
    _rippleController.repeat();
  }

  void _stopListeningAnimation() {
    _pulseController.stop();
    _pulseController.reset();
    _rippleController.stop();
    _rippleController.reset();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple circles (только при прослушивании)
            if (widget.isListening) ..._buildRippleCircles(),

            // Основная кнопка
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isListening ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.enabled
                          ? AppTheme.safeGreen
                          : AppTheme.textTertiary,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.safeGreen.withOpacity(
                            widget.isListening ? 0.5 : 0.3,
                          ),
                          blurRadius: widget.isListening ? 30 : 20,
                          spreadRadius: widget.isListening ? 5 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isListening ? Icons.mic : Icons.mic_none,
                      size: 44,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRippleCircles() {
    return List.generate(3, (index) {
      return AnimatedBuilder(
        animation: _rippleController,
        builder: (context, child) {
          final double value = (_rippleController.value + index * 0.33) % 1.0;
          return Transform.scale(
            scale: 1.0 + (value * 0.5),
            child: Opacity(
              opacity: (1.0 - value) * 0.4,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.safeGreen,
                    width: 3,
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Виджет визуализации звуковых волн
class SoundWaveVisualizer extends StatefulWidget {
  final bool isActive;
  final Color color;

  const SoundWaveVisualizer({
    super.key,
    required this.isActive,
    this.color = AppTheme.safeGreen,
  });

  @override
  State<SoundWaveVisualizer> createState() => _SoundWaveVisualizerState();
}

class _SoundWaveVisualizerState extends State<SoundWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.1;
            final animValue = (_controller.value + delay) % 1.0;
            final height = 8.0 + (math.sin(animValue * math.pi * 2) + 1) * 12;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
