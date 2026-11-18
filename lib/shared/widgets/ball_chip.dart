import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/innings.dart';

/// One delivery as a coloured circle (`.ball-chip`): wickets orange,
/// boundaries mint, extras amber, everything else neutral.
class BallChip extends StatelessWidget {
  const BallChip(this.delivery, {super.key, this.size = 34});

  final Delivery delivery;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    Color background = AppColors.fill;
    Color foreground = AppColors.white;
    Color? border;

    if (d.wicket) {
      background = AppColors.orange;
    } else if (d.kind == DeliveryKind.penalty) {
      background = const Color(0xFF475569);
    } else if (DeliveryKind.extras.contains(d.kind)) {
      background = const Color(0xFFFEF3C7);
      foreground = const Color(0xFF92400E);
    } else if (d.batterRuns == 4 || d.batterRuns == 6) {
      background = AppColors.mint;
      foreground = AppColors.onMint;
    } else if (d.batterRuns == 0) {
      border = AppColors.line;
      background = Colors.transparent;
      foreground = AppColors.muted;
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            d.label,
            style: AppText.body(
              size: 12,
              weight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapping row of [BallChip]s.
class BallRow extends StatelessWidget {
  const BallRow(this.deliveries, {super.key, this.size = 34});

  final List<Delivery> deliveries;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) {
      return Text('No balls yet.', style: AppText.muted());
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final d in deliveries) BallChip(d, size: size)],
    );
  }
}
