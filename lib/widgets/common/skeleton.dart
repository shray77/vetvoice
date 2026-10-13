// Skeleton — скелетон-лоадеры (Фаза 3, v1.19.0).
//
// ЗАЧЕМ: спиннер по центру и disabled-плитка с «Загрузка…» не дают ощущения
// каркаса будущего контента. SkeletonBox — скруглённый прямоугольник с
// бегущим бликом (shimmer), SkeletonList — готовый каркас списка карточек
// (круг-аватар + две строки) для экранов избранного/поиска.
//
// Без пакетов: свой LinearGradient на AnimationController. Theme-aware
// по AppTheme.isDarkNow — как StatusChip (экраны, где живут скелетоны,
// уже имеют зависимость от Theme.of — урок v1.18.1 про IndexedStack).
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;

  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = AppTheme.isDarkNow;
    final Color base = dark ? AppTheme.darkFieldFill : AppTheme.fieldFill;
    final Color sheen = dark ? AppTheme.darkSurfaceLight : AppTheme.white;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Блик уезжает слева направо: alignment от -1 до 2
            // (заходит за край с обеих сторон — без «телепорта»).
            final double t = -1 + _controller.value * 3;
            return Container(
              color: base,
              child: Align(
                alignment: Alignment(t, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          sheen.withAlpha(0),
                          sheen.withAlpha(70),
                          sheen.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Готовый каркас списка карточек: N строк (круг + две строки текста).
/// Используется вместо Center(CircularProgressIndicator) в списках
/// избранного и поиска — пользователь сразу видит форму будущего контента.
class SkeletonList extends StatelessWidget {
  final int items;

  const SkeletonList({super.key, this.items = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: items,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Row(
            children: [
              SkeletonBox(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      width: double.infinity,
                      height: 14,
                    ),
                    const SizedBox(height: 8),
                    SkeletonBox(width: 140, height: 11),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
