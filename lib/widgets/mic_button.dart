import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

/// Кнопка микрофона с плавной пульсацией и эффектом расходящихся волн
class MicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.onLongPress,
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (widget.isListening) {
      _startListeningAnimation();
    }
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
    final isDark = AppTheme.isDark(context);

    return GestureDetector(
      onTap: widget.enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            }
          : null,
      onLongPress: widget.enabled
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPress?.call();
            }
          : null,
      child: SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple circles при прослушивании
            if (widget.isListening) ..._buildRippleCircles(),

            // Основная кнопка
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isListening ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isListening
                          ? const LinearGradient(
                              colors: [AppTheme.safeGreenLight, AppTheme.safeGreenDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : (widget.enabled
                              ? LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF2C323B), const Color(0xFF1E232B)]
                                      : [const Color(0xFF2B303A), const Color(0xFF191F28)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null),
                      color: !widget.enabled
                          ? (isDark ? AppTheme.darkDivider : AppTheme.dividerGray)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: widget.isListening
                              ? AppTheme.safeGreen.withOpacity(0.4)
                              : Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                          blurRadius: widget.isListening ? 24 : 14,
                          spreadRadius: widget.isListening ? 2 : 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isListening ? Icons.mic : Icons.mic_none_rounded,
                      size: 38,
                      color: AppTheme.white,
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
            scale: 1.0 + (value * 0.45),
            child: Opacity(
              opacity: (1.0 - value) * 0.4,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.safeGreen,
                    width: 2.0,
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
      children: List.generate(6, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.12;
            final animValue = (_controller.value + delay) % 1.0;
            final height = 6.0 + (math.sin(animValue * math.pi * 2).abs()) * 16.0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 3.5,
              height: height,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        );
      }),
    );
  }
}
