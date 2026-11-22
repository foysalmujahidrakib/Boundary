import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/models/public_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/responsive.dart';

/// Public page listing every completed match, newest first.
/// No sign-in required.
class AllMatchesScreen extends StatelessWidget {
  const AllMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return Scaffold(
      appBar: AppBar(title: const Text('All Matches')),
      body: SafeArea(
        child: StreamBuilder<List<PublicMatchScore>>(
          stream: repo.watchCompletedMatches(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message(
                const NoticeBanner('Matches could not be loaded right now.'),
              );
            }
            final matches = snapshot.data;
            if (matches == null) {
              return const LoadingBlock(message: 'Loading matches…');
            }
            if (matches.isEmpty) {
              return _message(
                const EmptyState('No completed matches yet. Check back soon.'),
              );
            }

            // Newest first: by date, then by start time.
            final sorted = [...matches]
              ..sort((a, b) {
                final byDate = b.matchDate.compareTo(a.matchDate);
                return byDate != 0 ? byDate : b.startTime.compareTo(a.startTime);
              });

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${sorted.length} completed '
                        '${sorted.length == 1 ? 'match' : 'matches'}',
                        style: AppText.muted(size: 12),
                      ),
                      const SizedBox(height: 12),
                      for (final m in sorted) _MatchTile(match: m),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _message(Widget child) =>
      ListView(padding: const EdgeInsets.all(16), children: [child]);
}

/// A tappable row that opens the public scorecard of the match.
class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});

  final PublicMatchScore match;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final scoreLines = [
      for (final inn in m.innings)
        '${m.teamName(inn.battingTeamId)} '
            '${inn.total}/${inn.wickets} (${inn.oversLabel} ov)',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppColors.surface,
        radius: 12,
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.publicScorecard,
          arguments: PublicMatchArgs(m.matchId),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.displayTitle, style: AppText.heading(size: 15)),
                  if (m.meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(m.meta, style: AppText.muted(size: 11)),
                  ],
                  if (scoreLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final line in scoreLines)
                      Text(
                        line,
                        style: AppText.body(
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                  ],
                  if (m.result.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      m.result,
                      style: AppText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.mint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}