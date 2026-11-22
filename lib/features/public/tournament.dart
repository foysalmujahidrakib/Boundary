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

/// Public page listing every **ongoing** tournament with its points table
/// and a "See Matches" button. No sign-in required.
class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return Scaffold(
      appBar: AppBar(title: const Text('Ongoing Tournaments')),
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

            // Completed matches are loaded once and shared by every card
            // (they are only needed for the standings tables).
            return StreamBuilder<List<PublicMatchScore>>(
              stream: repo.watchCompletedMatches(),
              builder: (context, completedSnap) {
                final completed = completedSnap.data;
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
        ),
      ),
    );
  }

  Widget _message(Widget child) =>
      ListView(padding: const EdgeInsets.all(16), children: [child]);
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, required this.completed});

  final PublicTournament tournament;

  /// `null` while the results are still loading.
  final List<PublicMatchScore>? completed;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final meta = [
      t.season,
      t.format,
      [t.startDate, t.endDate].where((d) => d.isNotEmpty).join(' → '),
      t.venue,
    ].where((s) => s.isNotEmpty).join(' · ');

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
          const SizedBox(height: 18),
          const Eyebrow('Standings'),
          const SizedBox(height: 8),
          if (completed == null)
            const LoadingBlock()
          else
            StandingsTable(tournament: t, matches: completed!),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.sports_cricket, size: 18),
            label: const Text('See Matches'),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.tournamentMatches,
              arguments: TournamentMatchesArgs(
                tournamentId: t.id,
                tournamentName: t.name,
              ),
            ),
          ),
        ],
      ),
    );
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