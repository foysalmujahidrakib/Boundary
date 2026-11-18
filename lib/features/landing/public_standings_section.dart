import '../../app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/public_models.dart';
import '../../domain/scoring/formatters.dart';
import '../../domain/scoring/standings.dart';
import '../../domain/text_utils.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/scorecard_widgets.dart';

/// "Tournament standings": pick a public tournament and see its table
/// (port of `public-tournaments.js`). Needs no sign-in.
class PublicStandingsSection extends StatefulWidget {
  const PublicStandingsSection({super.key});

  @override
  State<PublicStandingsSection> createState() => _PublicStandingsSectionState();
}

class _PublicStandingsSectionState extends State<PublicStandingsSection> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return StreamBuilder<List<PublicTournament>>(
      stream: repo.watchTournaments(),
      builder: (context, tournamentSnap) {
        if (tournamentSnap.hasError) {
          return const NoticeBanner(
            'Tournaments could not be loaded right now.',
          );
        }
        final tournaments = tournamentSnap.data;
        if (tournaments == null) {
          return const LoadingBlock(message: 'Loading tournaments…');
        }
        if (tournaments.isEmpty) {
          return const EmptyState(
            'No public tournaments have been published yet.',
          );
        }

        final sorted = [...tournaments]
          ..sort((a, b) {
            final byStatus = TournamentStatus.sortRank(
              a.status,
            ).compareTo(TournamentStatus.sortRank(b.status));
            if (byStatus != 0) return byStatus;
            final byDate = b.startDate.compareTo(a.startDate);
            return byDate != 0 ? byDate : compareNames(a.name, b.name);
          });
        final selected = sorted.firstWhere(
          (t) => t.id == _selectedId,
          orElse: () => sorted.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(sorted[i].name),
                  selected: sorted[i].id == selected.id,
                  onSelected: (_) => setState(() => _selectedId = sorted[i].id),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _StandingsCard(tournament: selected),
          ],
        );
      },
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.tournament});

  final PublicTournament tournament;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    final meta = [
      tournament.season,
      tournament.format,
      [
        tournament.startDate,
        tournament.endDate,
      ].where((d) => d.isNotEmpty).join(' → '),
      tournament.venue,
    ].where((s) => s.isNotEmpty).join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tournament.name, style: AppText.heading(size: 19)),
              ),
              StatusChip(tournament.status),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: AppText.muted(size: 12)),
          ],
          const SizedBox(height: 12),
          StreamBuilder<List<PublicMatchScore>>(
            stream: repo.watchCompletedMatches(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const NoticeBanner('Standings could not be loaded.');
              }
              if (snapshot.data == null) return const LoadingBlock();
              final rows = Standings.calculate(tournament, snapshot.data!);
              if (rows.isEmpty) {
                return const EmptyState(
                  'No teams are registered for this tournament.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatTable(
                    titleHeader: 'Team',
                    headers: const ['P', 'W', 'L', 'Pts', 'NRR'],
                    valueWidth: 46,
                    rows: [
                      for (var i = 0; i < rows.length; i++)
                        StatRow(
                          title: '${i + 1}.  ${rows[i].name}',
                          values: [
                            '${rows[i].played}',
                            '${rows[i].wins}',
                            '${rows[i].losses}',
                            '${rows[i].points}',
                            Fmt.nrr(rows[i].netRunRate),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '2 points per win. Ranked by points, then net run rate.',
                    style: AppText.body(size: 11, color: AppColors.muted),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
