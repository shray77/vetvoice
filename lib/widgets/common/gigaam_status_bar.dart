// GigaAmStatusBar — карточка офлайн-движка GigaAM (Сбер) в настройках (v1.20.0).
//
// Самоподписывающийся компонент по образцу VoiceStatusBar: подписан на стримы
// GigaAmService (onStateChanged/onDownloadProgress/onError), сам перерисовывается,
// сам знает все состояния. Дополнительно держит тумблер «использовать для
// распознавания» (persist в SharedPreferences через GigaAmService.setEnabled).
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/gigaam_service.dart';
import '../../utils/app_theme.dart';
import 'haptics.dart';

class GigaAmStatusBar extends StatefulWidget {
  const GigaAmStatusBar({super.key});

  /// Текст статуса по состоянию модели.
  static String statusText(GigaAmService s) {
    switch (s.state) {
      case GigaAmService.stateRecording:
        return 'Слушаю... скажите дозировку, остановлюсь по тишине';
      case GigaAmService.stateRecognizing:
        return 'Распознаю...';
      case GigaAmService.stateReady:
        return 'Скачана и готова — распознавание работает без интернета';
      case GigaAmService.stateLoading:
        if (s.totalMB > 0) {
          final pct =
              (s.downloadedMB / s.totalMB * 100).clamp(0, 100).toStringAsFixed(0);
          return 'Скачивание: ${s.downloadedMB.toStringAsFixed(1)} из '
              '${s.totalMB.toStringAsFixed(0)} МБ ($pct%)';
        }
        return s.loadingMessage.isNotEmpty ? s.loadingMessage : 'Подготовка модели...';
      case GigaAmService.stateError:
        return s.errorMessage ?? 'Ошибка загрузки модели';
      default:
        return 'Модель не загружена (~216 МБ, качается один раз)';
    }
  }

  static IconData statusIcon(GigaAmService s) {
    switch (s.state) {
      case GigaAmService.stateRecording:
        return Icons.graphic_eq;
      case GigaAmService.stateRecognizing:
        return Icons.psychology_alt_outlined;
      case GigaAmService.stateReady:
        return Icons.verified_outlined;
      case GigaAmService.stateLoading:
        return Icons.downloading;
      case GigaAmService.stateError:
        return Icons.error_outline;
      default:
        return Icons.cloud_download_outlined;
    }
  }

  /// Пара (цвет иконки/акцента, фон карточки) — theme-aware.
  static (Color, Color) statusColors(GigaAmService s) {
    final bool dark = AppTheme.isDarkNow;
    switch (s.state) {
      case GigaAmService.stateRecording:
      case GigaAmService.stateReady:
        return (dark ? AppTheme.darkSuccess : AppTheme.success,
            dark ? AppTheme.darkSurfaceLight : AppTheme.successContainer);
      case GigaAmService.stateRecognizing:
      case GigaAmService.stateLoading:
        return (dark ? AppTheme.darkInfo : AppTheme.info,
            dark ? AppTheme.darkSurfaceLight : AppTheme.infoContainer);
      case GigaAmService.stateError:
        return (dark ? AppTheme.darkError : AppTheme.errorRed,
            dark ? AppTheme.darkErrorContainer : AppTheme.errorContainer);
      default:
        return (dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            dark ? AppTheme.darkFieldFill : AppTheme.fieldFill);
    }
  }

  @override
  State<GigaAmStatusBar> createState() => _GigaAmStatusBarState();
}

class _GigaAmStatusBarState extends State<GigaAmStatusBar> {
  final GigaAmService _service = GigaAmService.instance;
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  StreamSubscription? _sub3;

  @override
  void initState() {
    super.initState();
    _sub1 = _service.onStateChanged.listen((_) => _safeSetState());
    _sub2 = _service.onDownloadProgress.listen((_) => _safeSetState());
    _sub3 = _service.onError.listen((_) => _safeSetState());
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _sub3?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (accent, fill) = GigaAmStatusBar.statusColors(_service);
    final bool isBusy = _service.state == GigaAmService.stateLoading ||
        _service.state == GigaAmService.stateRecognizing;
    final bool isRecording = _service.state == GigaAmService.stateRecording;
    final bool downloaded = _service.state == GigaAmService.stateReady ||
        _service.state == GigaAmService.stateRecording ||
        _service.state == GigaAmService.stateRecognizing;
    final double? progress = (_service.state == GigaAmService.stateLoading &&
            _service.totalMB > 0)
        ? (_service.downloadedMB / _service.totalMB).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(GigaAmStatusBar.statusIcon(_service), color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Офлайн-движок GigaAM (Сбер)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // Хвост: действие по состоянию
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isRecording)
                TextButton(
                  onPressed: () => _service.stopTranscribe(),
                  child: const Text('Стоп'),
                )
              else if (!downloaded)
                TextButton(
                  onPressed: () {
                    AppHaptics.confirm();
                    _service.initialize();
                  },
                  child: const Text('Загрузить'),
                )
              else
                Icon(Icons.check_circle, color: accent, size: 22),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            GigaAmStatusBar.statusText(_service),
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
          const SizedBox(height: 4),
          // Тумблер: использовать GigaAM как движок распознавания
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppTheme.safeGreen,
            title: Text(
              'Распознавать без интернета (GigaAM)',
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              _service.isEnabled
                  ? 'Голосовой ввод идёт офлайн; при сбое — системный движок'
                  : 'Выключено: используется системный движок + интернет',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
            value: _service.isEnabled,
            onChanged: (v) {
              AppHaptics.select();
              _service.setEnabled(v);
              _safeSetState();
            },
          ),
        ],
      ),
    );
  }
}
