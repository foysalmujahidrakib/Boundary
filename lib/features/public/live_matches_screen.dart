import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/models/innings.dart';
import '../../domain/models/public_models.dart';
import '../../domain/scoring/formatters.dart';
import '../../domain/scoring/scorecard.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/ball_chip.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/match_header.dart';
import '../../shared/widgets/scorecard_widgets.dart';
import '../scorecard/scorecard_screen.dart' show PublicScorecardView;

/// Live Match Centre (`Livematches.html`): every match being played right
/// now, with live score, scorecard, over-by-over timeline and match info.
class LiveMatchesScreen extends StatefulWidget {
  const LiveMatchesScreen({super.key});

  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return Scaffold(
      appBar: AppBar(title: const Text('Live matches')),
      body: SafeArea(
        child: StreamBuilder<List<PublicMatchScore>>(
          stream: repo.watchLiveMatches(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  NoticeBanner('Live matches could not be loaded.'),
                ],
              );
            }
            final matches = snapshot.data;
            if (matches == null) {
              return const LoadingBlock(message: 'Loading live matches…');
            }
            if (matches.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyState(
                    'No match is being scored right now. Check back soon.',
                  ),
                ],
              );
            }
            final selected = matches.firstWhere(
              (m) => m.matchId == _selectedId,
              orElse: () => matches.first,
            );
            return Column(
              children: [
                if (matches.length > 1)
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ChoiceChip(
                        label: Text(matches[i].displayTitle),
                        selected: matches[i].matchId == selected.matchId,
                        onSelected: (_) =>
                            setState(() => _selectedId = matches[i].matchId),
                      ),
                    ),
                  ),
                Expanded(child: LiveMatchCentre(match: selected)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tabbed view of one published match.
class LiveMatchCentre extends StatelessWidget {
  const LiveMatchCentre({super.key, required this.match});

  final PublicMatchScore match;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Live'),
              Tab(text: 'Scorecard'),
              Tab(text: 'Overs'),
              Tab(text: 'Info'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _tab(_LiveTab(match: match)),
                _tab(PublicScorecardView(match: match)),
                _tab(_OversTab(match: match)),
                _tab(_InfoTab(match: match)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(Widget child) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [child],
  );
}

class _LiveTab extends StatelessWidget {
  const _LiveTab({required this.match});

  final PublicMatchScore match;

  @override
  Widget build(BuildContext context) {
    final innings = match.innings;
    if (innings.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MatchHeader(
            badge: PublicStatuses.liveChip(match),
            live: true,
            title: match.displayTitle,
            meta: match.meta,
          ),
          const SizedBox(height: 16),
          const EmptyState('The innings has not started yet.'),
        ],
      );
    }
    final inn = innings.last;
    final battingTeam = match.teamName(inn.battingTeamId);
    final report = ScorecardBuilder.buildInnings(
      inn,
      innings.length - 1,
      match.teamName,
      match.playerName,
    );
    final atCrease = report.batting.where((b) => b.isAtCrease).toList();
    final bowlerRow = report.bowling
        .where((b) => b.playerId == inn.bowlerId)
        .firstOrNull;
    final overs = ScorecardBuilder.overs(inn);
    final over = overs.isEmpty ? null : overs.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MatchHeader(
          badge: PublicStatuses.liveChip(match),
          live: match.isGenuinelyLive,
          title: match.displayTitle,
          meta: match.meta,
          result: match.result,
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                battingTeam,
                style: AppText.heading(size: 15, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${inn.total}/${inn.wickets}',
                    style: AppText.score(size: 54, color: AppColors.white),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '(${inn.oversLabel} ov)',
                      style: AppText.muted(size: 14),
                    ),
                  ),
                ],
              ),
              Text(
                'Run rate ${Fmt.runRate(inn.total, inn.legalBalls)}',
                style: AppText.muted(size: 12),
              ),
              if (_chaseLine(innings, match.overs) case final line?) ...[
                const SizedBox(height: 8),
                Text(
                  line,
                  style: AppText.heading(size: 14, color: AppColors.mint),
                ),
              ],
              if (innings.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  '${match.teamName(innings.first.battingTeamId)}: '
                  '${innings.first.total}/${innings.first.wickets} (${innings.first.oversLabel} ov)',
                  style: AppText.muted(size: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!inn.completed && atCrease.isNotEmpty)
          SectionCard(
            title: 'At the crease',
            child: Column(
              children: [
                StatTable(
                  titleHeader: 'Batter',
                  headers: const ['R', 'B', '4s', '6s', 'SR'],
                  valueWidth: 42,
                  rows: [
                    for (final b in atCrease)
                      StatRow(
                        title: b.playerId == inn.strikerId
                            ? '${b.name} *'
                            : b.name,
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
                if (bowlerRow != null) ...[
                  const SizedBox(height: 10),
                  StatTable(
                    titleHeader: 'Bowler',
                    headers: const ['O', 'R', 'W', 'Econ'],
                    valueWidth: 46,
                    rows: [
                      StatRow(
                        title: bowlerRow.name,
                        values: [
                          bowlerRow.overs,
                          '${bowlerRow.runs}',
                          '${bowlerRow.wickets}',
                          bowlerRow.economy,
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        if (over != null) ...[
          const SizedBox(height: 14),
          SectionCard(
            title: over.complete ? 'Last over' : 'This over',
            trailing: SoftTag('${over.runs} runs'),
            child: BallRow(over.deliveries),
          ),
        ],
      ],
    );
  }

  /// `Need 24 from 18 balls` for the chasing side.
  static String? _chaseLine(List<Innings> innings, int overs) {
    if (innings.length < 2) return null;
    final second = innings[1];
    if (second.completed) return null;
    final target = innings.first.total + 1;
    final needed = target - second.total;
    final ballsLeft = overs * 6 - second.legalBalls;
    if (needed <= 0) return null;
    return 'Need $needed from ${Fmt.plural(ballsLeft < 0 ? 0 : ballsLeft, 'ball')} (target $target)';
  }
}

class _OversTab extends StatelessWidget {
  const _OversTab({required this.match});

  final PublicMatchScore match;

  @override
  Widget build(BuildContext context) {
    if (match.innings.isEmpty) {
      return const EmptyState('No overs have been bowled yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < match.innings.length; i++) ...[
          Text(
            '${Fmt.ordinal(i + 1)} innings · ${match.teamName(match.innings[i].battingTeamId)}',
            style: AppText.heading(size: 16),
          ),
          const SizedBox(height: 10),
          if (match.innings[i].deliveries.isEmpty)
            const EmptyState('No balls bowled.')
          else
            for (final over in ScorecardBuilder.overs(
              match.innings[i],
            ).reversed) ...[
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Over ${over.number}',
                          style: AppText.heading(size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            over.bowlerId == null
                                ? ''
                                : match.playerName(over.bowlerId),
                            style: AppText.muted(size: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${over.runs} runs',
                          style: AppText.body(
                            size: 12,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BallRow(over.deliveries, size: 30),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.match});

  final PublicMatchScore match;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppText.muted(size: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppText.body(size: 13, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    var fours = 0, sixes = 0, extras = 0, wickets = 0;
    for (final inn in match.innings) {
      extras += inn.extras;
      wickets += inn.wickets;
      for (final b in inn.batters.values) {
        fours += b.fours;
        sixes += b.sixes;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Match info',
          child: Column(
            children: [
              line(
                'Teams',
                '${match.teamName(match.teamAId)} vs ${match.teamName(match.teamBId)}',
              ),
              line('Date', match.matchDate),
              line('Start time', match.startTime),
              line('Venue', match.venue),
              line('Format', '${match.format} · ${match.overs} overs'),
              line('Result', match.result),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Match stats',
          child: Column(
            children: [
              line('Fours', '$fours'),
              line('Sixes', '$sixes'),
              line('Extras', '$extras'),
              line('Wickets', '$wickets'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open full scorecard'),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.publicScorecard,
              arguments: PublicMatchArgs(match.matchId),
            ),
          ),
        ),
      ],
    );
  }
}
