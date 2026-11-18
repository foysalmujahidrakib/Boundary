import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui.dart';

/// The scoring keypad (`.score-btn` grid): runs, OUT and the extras.
class RunPad extends StatelessWidget {
  const RunPad({
    super.key,
    required this.enabled,
    required this.onRuns,
    required this.onWicket,
    required this.onExtra,
  });

  final bool enabled;
  final ValueChanged<int> onRuns;
  final VoidCallback onWicket;

  /// Called with a [DeliveryKind] value (`wide`, `no_ball`, ...).
  final ValueChanged<String> onExtra;

  void _tap(VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: [
            for (final runs in [0, 1, 2, 3, 4, 5, 6])
              _PadButton(
                label: '$runs',
                boundary: runs == 4 || runs == 6,
                onPressed: enabled ? () => _tap(() => onRuns(runs)) : null,
              ),
            _PadButton(
              label: 'OUT',
              wicket: true,
              onPressed: enabled ? () => _tap(onWicket) : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (label, kind) in const [
              ('WD', 'wide'),
              ('NB', 'no_ball'),
              ('LB', 'leg_bye'),
              ('BYE', 'bye'),
              ('PEN', 'penalty'),
            ]) ...[
              Expanded(
                child: _PadButton(
                  label: label,
                  extra: true,
                  height: 46,
                  onPressed: enabled ? () => _tap(() => onExtra(kind)) : null,
                ),
              ),
              if (kind != 'penalty') const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.onPressed,
    this.boundary = false,
    this.wicket = false,
    this.extra = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool boundary;
  final bool wicket;
  final bool extra;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (wicket) {
      background = AppColors.orange;
      foreground = AppColors.white;
    } else if (boundary) {
      background = AppColors.mint;
      foreground = AppColors.onMint;
    } else if (extra) {
      background = Colors.transparent;
      foreground = AppColors.white;
    } else {
      background = AppColors.surfaceRaised;
      foreground = AppColors.white;
    }

    final disabled = onPressed == null;
    final button = Material(
      color: disabled
          ? background.withValues(alpha: extra ? 0 : 0.4)
          : background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: extra ? const BorderSide(color: AppColors.line) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Center(
          child: Text(
            label,
            style:
                (extra
                        ? AppText.body(size: 14, weight: FontWeight.w800)
                        : AppText.score(size: wicket ? 24 : 32))
                    .copyWith(
                      color: disabled
                          ? foreground.withValues(alpha: 0.4)
                          : foreground,
                    ),
          ),
        ),
      ),
    );
    return height == null ? button : SizedBox(height: height, child: button);
  }
}
