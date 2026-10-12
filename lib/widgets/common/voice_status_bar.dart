// VoiceStatusBar — живой статус офлайн-модели Vosk (Фаза 1, v1.17.0).
//
// ЗАЧЕМ: статус-логика (текст/иконка/цвет по state + прогресс скачивания +
// кнопка «Загрузить») была написана внутри settings_screen приватными
// геттерами — на другом экране её не переиспользовать. VoiceStatusBar —
// самоподписывающийся компонент: подписан на стримы WakeWordService
// (onStateChanged/onDownloadProgress/onError/onListeningStateChanged),
// сам перерисовывается, сам знает все состояния.
//
// Демо-встраивание v1.17.0: settings_screen — секция «Голос и распознавание»
// (ListTile заменён на этот компонент; текст-пояснение остался в настройках).
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/wake_word_service.dart';
import '../../utils/app_theme.dart';

class VoiceStatusBar extends StatefulWidget {
  const VoiceStatusBar({super.key});

  /// Единый текст статуса по state (использовался в настройках — теперь тут).
  static String statusText(WakeWordService s) {
    switch (s.state) {
      case 'LISTENING':
        return 'Скачана и активна: слушает «ВетВойс» (офлайн)';
      case 'READY':
        return 'Скачана и готова — включите wake word кнопкой микрофона с волной';
      case 'LOADING':
        if (s.isExtracting) return 'Распаковка модели...';
        if (s.totalMB > 0) {
          final pct = (s.downloadedMB / s.totalMB * 100).clamp(0, 100).toStringAsFixed(0);
          return 'Скачивание: ${s.downloadedMB.toStringAsFixed(1)} из '
              '${s.totalMB.toStringAsFixed(0)} МБ ($pct%)';
        }
        return s.loadingMessage.isNotEmpty ? s.loadingMessage : 'Загрузка модели...';
      case 'ERROR':
        return s.errorMessage ?? 'Ошибка загрузки модели';
      default:
        return 'Модель не загружена (нужна только для wake word)';
    }
  }

  static IconData statusIcon(WakeWordService s) {
    switch (s.state) {
      case 'LISTENING':
      case 'READY':
        return Icons.mic_outlined;
      case 'LOADING':
        return Icons.downloading;
      case 'ERROR':
        return Icons.error_outline;
      default:
        return Icons.mic_none;
    }
  }

  /// Пара (цвет иконки/акцента, фон строки) — theme-aware.
  static (Color, Color) statusColors(WakeWordService s) {
    final bool dark = AppTheme.isDarkNow;
    switch (s.state) {
      case 'LISTENING':
      case 'READY':
        return (dark ? AppTheme.darkSuccess : AppTheme.success,
            dark ? AppTheme.darkSurfaceLight : AppTheme.successContainer);
      case 'LOADING':
        return (dark ? AppTheme.darkInfo : AppTheme.info,
            dark ? AppTheme.darkSurfaceLight : AppTheme.infoContainer);
      case 'ERROR':
        return (dark ? AppTheme.darkError : AppTheme.errorRed,
            dark ? AppTheme.darkErrorContainer : AppTheme.errorContainer);
      default:
        return (dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            dark ? AppTheme.darkFieldFill : AppTheme.fieldFill);
    }
  }

  @override
  State<VoiceStatusBar> createState() => _VoiceStatusBarState();
}

class _VoiceStatusBarState extends State<VoiceStatusBar> {
  final WakeWordService _service = WakeWordService.instance;
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  StreamSubscription? _sub3;
  StreamSubscription? _sub4;

  @override
  void initState() {
    super.initState();
    // Все 4 стрима → перерисовка (как делал settings, теперь тут инкапсулировано)
    _sub1 = _service.onStateChanged.listen((_) => _safeSetState());
    _sub2 = _service.onDownloadProgress.listen((_) => _safeSetState());
    _sub3 = _service.onError.listen((_) => _safeSetState());
    _sub4 = _service.onListeningStateChanged.listen((_) => _safeSetState());
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _sub3?.cancel();
    _sub4?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (accent, fill) = VoiceStatusBar.statusColors(_service);
    final bool isListening = _service.state == 'LISTENING';
    final bool isLoading = _service.state == 'LOADING';
    final double? progress = (isLoading && _service.totalMB > 0)
        ? (_service.downloadedMB / _service.totalMB).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(VoiceStatusBar.statusIcon(_service), color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Офлайн-модель Vosk (wake word «ВетВойс»)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // Хвост: действие по состоянию
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isListening)
                TextButton(
                  onPressed: () => _service.stopListening(),
                  child: const Text('Стоп'),
                )
              else if (!_service.isInitialized)
                TextButton(
                  onPressed: () => _service.initialize(),
                  child: const Text('Загрузить'),
                )
              else
                Icon(Icons.check_circle, color: accent, size: 22),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            VoiceStatusBar.statusText(_service),
            style: TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.textSecondary,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusMicro)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.dividerGray,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
