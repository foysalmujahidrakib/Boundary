import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/models/public_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/responsive.dart';

/// Live matches and finished results of one tournament. No sign-in needed.
class TournamentMatchesScreen extends StatelessWidget {
  const TournamentMatchesScreen({super.key, required this.args});

  final TournamentMatchesArgs args;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return Scaffold(
      appBar: AppBar(title: Text(args.tournamentName)),
      body: SafeArea(
        child: StreamBuilder<List<PublicMatchScore>>(
          stream: repo.watchCompletedMatches(),
          builder: (context, completedSnap) {
            return StreamBuilder<List<PublicMatchScore>>(
              stream: repo.watchLiveMatches(),
              builder: (context, liveSnap) {
                if (completedSnap.hasError || liveSnap.hasError) {
                  return _message(
                    const NoticeBanner(
                      'Matches could not be loaded right now.',
                    ),
                  );
                }
                final completedAll = completedSnap.data;
                final liveAll = liveSnap.data;
                if (completedAll == null || liveAll == null) {
                  return const LoadingBlock(message: 'Loading matches…');
                }

                final live = liveAll
                    .where((m) => m.tournamentId == args.tournamentId)
                    .toList();
                final results =
                    completedAll
                        .where((m) => m.tournamentId == args.tournamentId)
                        .toList()
                      ..sort((a, b) => b.matchDate.compareTo(a.matchDate));

                if (live.isEmpty && results.isEmpty) {
                  return _message(
                    const EmptyState(
                      'No matches have been published for this tournament yet.',
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (live.isNotEmpty) ...[
                            const Eyebrow('Live now'),
                            const SizedBox(height: 8),
                            for (final m in live)
                              _MatchTile(match: m, live: true),
                            const SizedBox(height: 18),
                          ],
                          if (results.isNotEmpty) ...[
                            const Eyebrow('Results'),
                            const SizedBox(height: 8),
                            for (final m in results) _MatchTile(match: m),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _message(Widget child) =>
      ListView(padding: const EdgeInsets.all(16), children: [child]);
}

/// A tappable match row that opens the public scorecard.
class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, this.live = false});

  final PublicMatchScore match;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final subtitle = live ? _liveScore(match) : match.result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        color: AppColors.canvas,
        radius: 10,
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.publicScorecard,
          arguments: PublicMatchArgs(match.matchId),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.displayTitle, style: AppText.heading(size: 14)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.body(
                        size: 12,
                        color: live ? AppColors.mint : AppColors.muted,
                      ),
                    ),
                  ],
                  if (match.matchDate.isNotEmpty)
                    Text(match.matchDate, style: AppText.muted(size: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  /// `Dhaka FC 104/6 (14.2 ov)` for the innings in progress.
  static String _liveScore(PublicMatchScore m) {
    if (m.innings.isEmpty) return 'Starting soon';
    final inn = m.innings.last;
    return '${m.teamName(inn.battingTeamId)} '
        '${inn.total}/${inn.wickets} (${inn.oversLabel} ov)';
  }
}
