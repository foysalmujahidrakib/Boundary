import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import 'scorecard_widgets.dart';

/// Heading block of a scorecard: badge, title, fixture details and result.
class MatchHeader extends StatelessWidget {
  const MatchHeader({
    super.key,
    required this.badge,
    required this.title,
    this.meta = '',
    this.result = '',
    this.live = false,
  });

  final String badge;
  final bool live;
  final String title;
  final String meta;
  final String result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScoreBadge(badge, live: live),
        const SizedBox(height: 12),
        Text(
          title,
          style: AppText.heading(size: 28, letterSpacing: -0.8, height: 1.1),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meta, style: AppText.muted(size: 13)),
        ],
        if (result.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(result, style: AppText.heading(size: 16, color: AppColors.mint)),
        ],
      ],
    );
  }
}
