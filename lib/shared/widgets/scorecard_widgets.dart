import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/scoring/formatters.dart';
import '../../domain/scoring/scorecard.dart';
import 'app_card.dart';

/// One row of a [StatTable].
class StatRow {
  const StatRow({
    required this.title,
    required this.values,
    this.subtitle,
    this.highlight = false,
  });

  final String title;
  final String? subtitle;
  final List<String> values;

  /// Tints the row (batters currently at the crease).
  final bool highlight;
}

/// A compact table: a flexible first column and fixed-width numeric columns,
/// so it fits a phone without horizontal scrolling.
class StatTable extends StatelessWidget {
  const StatTable({
    super.key,
    required this.titleHeader,
    required this.headers,
    required this.rows,
    this.valueWidth = 44,
  });

  final String titleHeader;
  final List<String> headers;
  final List<StatRow> rows;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    final header = AppText.body(
      size: 10,
      weight: FontWeight.w800,
      color: AppColors.muted,
      letterSpacing: 0.8,
    );

    TableRow headerRow() => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(titleHeader.toUpperCase(), style: header),
        ),
        for (final h in headers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              h.toUpperCase(),
              style: header,
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );

    TableRow dataRow(StatRow r) => TableRow(
      decoration: BoxDecoration(
        color: r.highlight ? AppColors.highlight : null,
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title,
                style: AppText.body(size: 13, weight: FontWeight.w700),
              ),
              if (r.subtitle != null)
                Text(r.subtitle!, style: AppText.muted(size: 11)),
            ],
          ),
        ),
        for (var i = 0; i < r.values.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              r.values[i],
              textAlign: TextAlign.right,
              style: AppText.body(
                size: 13,
                // The first figure (runs / overs) is the headline number.
                weight: i == 0 ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(),
        for (var i = 0; i < headers.length; i++)
          i + 1: FixedColumnWidth(valueWidth),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [headerRow(), for (final r in rows) dataRow(r)],
    );
  }
}

/// Full scorecard of one innings: batting, extras, bowling, fall of wickets
/// and stands.
class InningsReportCard extends StatelessWidget {
  const InningsReportCard({super.key, required this.report});

  final InningsReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('${Fmt.ordinal(r.index + 1)} innings'),
                    const SizedBox(height: 6),
                    Text(r.battingTeamName, style: AppText.heading(size: 19)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.total}/${r.wickets}',
                    style: AppText.heading(size: 26, color: AppColors.mint),
                  ),
                  Text(
                    '${r.oversLabel} ov${r.completed ? ' · completed' : ''}',
                    style: AppText.muted(size: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (r.batting.isEmpty)
            Text('No balls faced yet.', style: AppText.muted())
          else
            StatTable(
              titleHeader: 'Batter',
              headers: const ['R', 'B', '4s', '6s', 'SR'],
              valueWidth: 42,
              rows: [
                for (final b in r.batting)
                  StatRow(
                    title: b.isAtCrease ? '${b.name} *' : b.name,
                    subtitle: b.dismissal,
                    highlight: b.isAtCrease,
                    values: [
                      '${b.runs}',
                      '${b.balls}',
                      '${b.fours}',
                      '${b.sixes}',
                      b.strikeRate,
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            'Extras  ${r.extras.summary}',
            style: AppText.body(size: 12, color: AppColors.muted),
          ),
          if (r.bowling.isNotEmpty) ...[
            const SizedBox(height: 14),
            StatTable(
              titleHeader: 'Bowler',
              headers: const ['O', 'R', 'W', 'Econ'],
              valueWidth: 46,
              rows: [
                for (final b in r.bowling)
                  StatRow(
                    title: b.name,
                    values: [b.overs, '${b.runs}', '${b.wickets}', b.economy],
                  ),
              ],
            ),
          ],
          if (r.fallOfWickets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Fall of wickets', style: AppText.heading(size: 13)),
            const SizedBox(height: 4),
            Text(
              r.fallOfWickets.map((f) => f.summary).join('   '),
              style: AppText.body(
                size: 12,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ],
          if (r.stands.length > 1 ||
              (r.stands.isNotEmpty && r.stands.first.runs > 0)) ...[
            const SizedBox(height: 14),
            Text('Stands', style: AppText.heading(size: 13)),
            const SizedBox(height: 4),
            for (final s in r.stands)
              Text(
                s.summary,
                style: AppText.body(
                  size: 12,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Badge for the scorecard heading, e.g. `LIVE SCORE`.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge(this.text, {super.key, this.live = false});

  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.orange : AppColors.mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: AppText.body(
              size: 10,
              weight: FontWeight.w800,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
