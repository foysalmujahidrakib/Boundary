import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui.dart';
import '../../../domain/models/innings.dart';
import '../../../domain/scoring/formatters.dart';
import '../../../domain/scoring/scorecard.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/ball_chip.dart';
import '../match_session_controller.dart';

/// Score summary of the innings being scored: total, overs, run rate,
/// target, the batters at the crease, the bowler and the current over.
class LiveScoreCard extends StatelessWidget {
  const LiveScoreCard({
    super.key,
    required this.controller,
    required this.innings,
  });

  final MatchSessionController controller;
  final Innings innings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final inn = innings;
    final rules = c.match!.overs;

    String batter(String? id) {
      if (id == null) return '—';
      final s = inn.batters[id];
      final figures = s == null ? '0 (0)' : '${s.runs} (${s.balls})';
      return '${c.playerName(id)}  $figures';
    }

    final bowlerStats = inn.bowlerId == null ? null : inn.bowlers[inn.bowlerId];
    final overs = ScorecardBuilder.overs(inn);
    final over = overs.isEmpty ? null : overs.last;

    String? target;
    if (inn.number == 2 && c.innings.isNotEmpty) {
      final goal = c.innings.first.total + 1;
      final need = goal - inn.total;
      final left = rules * 6 - inn.legalBalls;
      target = need > 0
          ? 'Target $goal · need $need from ${Fmt.plural(left < 0 ? 0 : left, 'ball')}'
          : 'Target $goal reached';
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.teamName(inn.battingTeamId)} · ${Fmt.ordinal(inn.number)} innings',
                  style: AppText.heading(size: 14, color: AppColors.muted),
                ),
              ),
              if (inn.completed)
                Text(
                  'COMPLETED',
                  style: AppText.eyebrow(color: AppColors.mint),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${inn.total}/${inn.wickets}',
                style: AppText.score(size: 58, color: AppColors.white),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  '${inn.oversLabel} / $rules ov',
                  style: AppText.muted(size: 14),
                ),
              ),
            ],
          ),
          Text(
            'Run rate ${Fmt.runRate(inn.total, inn.legalBalls)}'
            '  ·  Extras ${inn.extras}',
            style: AppText.muted(size: 12),
          ),
          if (target != null) ...[
            const SizedBox(height: 8),
            Text(
              target,
              style: AppText.heading(size: 14, color: AppColors.mint),
            ),
          ],
          const Divider(height: 28),
          _line(
            Icons.sports_cricket,
            '${batter(inn.strikerId)} *',
            strong: true,
          ),
          const SizedBox(height: 6),
          _line(Icons.sports_cricket_outlined, batter(inn.nonStrikerId)),
          const SizedBox(height: 6),
          _line(
            Icons.sports_baseball_outlined,
            inn.bowlerId == null
                ? '—'
                : '${c.playerName(inn.bowlerId)}  '
                      '${Fmt.overs(bowlerStats?.legalBalls ?? 0)}-'
                      '${bowlerStats?.runs ?? 0}-${bowlerStats?.wickets ?? 0}',
          ),
          if (over != null) ...[
            const SizedBox(height: 16),
            Text(
              over.complete ? 'Last over' : 'This over',
              style: AppText.eyebrow(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            BallRow(over.deliveries),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, {bool strong = false}) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: AppText.body(
            size: 14,
            weight: strong ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
