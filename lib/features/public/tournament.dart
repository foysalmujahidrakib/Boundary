import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/models/public_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';

import '../../shared/widgets/responsive.dart';
import '../../shared/widgets/standings_table.dart';

/// Public page listing every **ongoing** tournament with its live matches,
/// recent results and points table. No sign-in required.
class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return Scaffold(
    appBar: AppBar(
        title: const Text('Ongoing tournaments')
        ),
      body: SafeArea(
        child: StreamBuilder<List<PublicTournament>>(
          stream: repo.watchOngoingTournaments(),
          builder: (context, tournamentSnap) {
            if (tournamentSnap.hasError) {
              return _message(
                const NoticeBanner(
                  'Tournaments could not be loaded right now.',
                ),
              );
            }
            final tournaments = tournamentSnap.data;
            if (tournaments == null) {
              return const LoadingBlock(message: 'Loading tournaments…');
            }
            if (tournaments.isEmpty) {
              return _message(
                const EmptyState('There is no ongoing tournament right now.'),
              );
            }
            final sorted = [...tournaments]
              ..sort((a, b) => b.startDate.compareTo(a.startDate));

            // Matches are loaded once and shared by every tournament card.
            return StreamBuilder<List<PublicMatchScore>>(
              stream: repo.watchCompletedMatches(),
              builder: (context, completedSnap) {
                return StreamBuilder<List<PublicMatchScore>>(
                  stream: repo.watchLiveMatches(),
                  builder: (context, liveSnap) {
                    final completed = completedSnap.data;
                    final live = liveSnap.data ?? const <PublicMatchScore>[];
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ContentWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final t in sorted) ...[
                                _TournamentCard(
                                  tournament: t,
                                  completed: completed,
                                  live: live,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.tournament,
    required this.completed,
    required this.live,
  });

  final PublicTournament tournament;

  /// `null` while the results are still loading.
  final List<PublicMatchScore>? completed;
  final List<PublicMatchScore> live;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final meta = [
      t.season,
      t.format,
      [t.startDate, t.endDate].where((d) => d.isNotEmpty).join(' → '),
      t.venue,
    ].where((s) => s.isNotEmpty).join(' · ');

    final liveHere = live.where((m) => m.tournamentId == t.id).toList();
    final results =
        (completed ?? const <PublicMatchScore>[])
            .where((m) => m.tournamentId == t.id)
            .toList()
          ..sort((a, b) => b.matchDate.compareTo(a.matchDate));

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(t.name, style: AppText.heading(size: 22))),
              const SizedBox(width: 8),
              const _OngoingBadge(),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: AppText.muted(size: 12)),
          ],
          const SizedBox(height: 4),
          Text('${t.teamIds.length} teams', style: AppText.muted(size: 12)),
          if (liveHere.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Eyebrow('Live now'),
            const SizedBox(height: 8),
            for (final m in liveHere) _MatchTile(match: m, live: true),
          ],
          const SizedBox(height: 18),
          const Eyebrow('Standings'),
          const SizedBox(height: 8),
          if (completed == null)
            const LoadingBlock()
          else
            StandingsTable(tournament: t, matches: completed!),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Eyebrow('Recent results'),
            const SizedBox(height: 8),
            for (final m in results.take(5)) _MatchTile(match: m),
          ],
        ],
      ),
    );
  }
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

class _OngoingBadge extends StatelessWidget {
  const _OngoingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ONGOING',
        style: AppText.body(
          size: 10,
          weight: FontWeight.w800,
          color: AppColors.green,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
