import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/models/public_models.dart';
import '../../domain/scoring/formatters.dart';
import '../../domain/scoring/standings.dart';
import 'feedback.dart';
import 'scorecard_widgets.dart';

/// Points table of one public tournament (P, W, L, Pts, NRR).
///
/// Used on the homepage and on the ongoing-tournaments page.
class StandingsTable extends StatelessWidget {
  const StandingsTable({
    super.key,
    required this.tournament,
    required this.matches,
  });

  final PublicTournament tournament;

  /// Completed public matches (any tournament; they are filtered here).
  final List<PublicMatchScore> matches;

  @override
  Widget build(BuildContext context) {
    final rows = Standings.calculate(tournament, matches);
    if (rows.isEmpty) {
      return const EmptyState('No teams are registered for this tournament.');
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
  }
}
