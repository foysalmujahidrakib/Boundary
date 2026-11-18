import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/ui.dart';
import '../../domain/models/public_models.dart';
import '../../domain/scoring/scorecard.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/match_header.dart';
import '../../shared/widgets/require_auth.dart';
import '../../shared/widgets/scorecard_widgets.dart';
import '../../shared/widgets/workspace_scaffold.dart';
import '../scoring/match_session_controller.dart';

/// The private scorecard of a club match (`scorecard.html`), read from the
/// club's own `matchScores` document and updating live.
class ScorecardScreen extends StatelessWidget {
  const ScorecardScreen({super.key, required this.args});

  final MatchArgs args;

  @override
  Widget build(BuildContext context) {
    return RequireAuth(
      builder: (context, user) => _ScorecardBody(args: args, user: user),
    );
  }
}

class _ScorecardBody extends StatefulWidget {
  const _ScorecardBody({required this.args, required this.user});

  final MatchArgs args;
  final User user;

  @override
  State<_ScorecardBody> createState() => _ScorecardBodyState();
}

class _ScorecardBodyState extends State<_ScorecardBody> {
  MatchSessionController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= MatchSessionController(
      services: AppScope.of(context),
      clubId: widget.args.clubId,
      matchId: widget.args.matchId,
      user: widget.user,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final match = c.match;
        final complete = c.innings.length >= 2 && c.innings[1].completed;
        return WorkspaceScaffold(
          user: widget.user,
          children: [
            if (c.error != null) ...[
              NoticeBanner(c.error!),
              const SizedBox(height: 16),
            ],
            if (match == null && c.error == null)
              const LoadingBlock(message: 'Loading scorecard…')
            else if (match != null) ...[
              MatchHeader(
                badge: complete ? 'MATCH COMPLETED' : 'LIVE SCORE',
                live: !complete,
                title: c.title,
                meta: [
                  match.matchDate,
                  match.startTime,
                  match.venue,
                  match.format,
                ].where((p) => p.isNotEmpty).join(' · '),
                result: c.result,
              ),
              const SizedBox(height: 18),
              if (!c.scoreLoaded)
                const LoadingBlock()
              else if (c.innings.isEmpty)
                const EmptyState(
                  'No innings has been recorded for this match yet.',
                )
              else
                ..._scorecard(c),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _scorecard(MatchSessionController c) {
    final reports = ScorecardBuilder.build(
      innings: c.innings,
      teamName: (id) => c.teamName(id),
      playerName: c.playerName,
    );
    final aggregates = ScorecardBuilder.playerAggregates(
      c.innings,
      c.playerName,
    );
    final batters = aggregates.where((p) => p.balls > 0 || p.runs > 0).toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    final bowlers = aggregates.where((p) => p.legalBallsBowled > 0).toList()
      ..sort((a, b) => b.wickets.compareTo(a.wickets));

    return [
      for (final r in reports) ...[
        InningsReportCard(report: r),
        const SizedBox(height: 14),
      ],
      if (batters.isNotEmpty || bowlers.isNotEmpty)
        SectionCard(
          eyebrow: 'Match summary',
          title: 'Player performances',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (batters.isNotEmpty)
                StatTable(
                  titleHeader: 'Batting',
                  headers: const ['R', 'B', '4s', '6s', 'SR'],
                  valueWidth: 42,
                  rows: [
                    for (final p in batters)
                      StatRow(
                        title: p.name,
                        values: [
                          '${p.runs}',
                          '${p.balls}',
                          '${p.fours}',
                          '${p.sixes}',
                          p.strikeRate,
                        ],
                      ),
                  ],
                ),
              if (batters.isNotEmpty && bowlers.isNotEmpty)
                const SizedBox(height: 14),
              if (bowlers.isNotEmpty)
                StatTable(
                  titleHeader: 'Bowling',
                  headers: const ['O', 'R', 'W', 'Econ'],
                  valueWidth: 46,
                  rows: [
                    for (final p in bowlers)
                      StatRow(
                        title: p.name,
                        values: [
                          p.overs,
                          '${p.runsConceded}',
                          '${p.wickets}',
                          p.economy,
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
    ];
  }
}

/// Public (signed-out) scorecard from `publicMatchScores` (the web's
/// `public-scorecard.html`).
class PublicScorecardScreen extends StatelessWidget {
  const PublicScorecardScreen({super.key, required this.args});

  final PublicMatchArgs args;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).public;
    return Scaffold(
      appBar: AppBar(title: const Text('Scorecard')),
      body: SafeArea(
        child: StreamBuilder<PublicMatchScore?>(
          stream: repo.watchMatch(args.matchId),
          builder: (context, snapshot) {
            Widget body;
            if (snapshot.hasError) {
              body = const NoticeBanner('The scorecard could not be loaded.');
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              body = const LoadingBlock(message: 'Loading scorecard…');
            } else if (snapshot.data == null) {
              body = const EmptyState('This scorecard is not available yet.');
            } else {
              body = PublicScorecardView(match: snapshot.data!);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [body],
            );
          },
        ),
      ),
    );
  }
}

/// The body of a public scorecard (also reused inside the live match centre).
class PublicScorecardView extends StatelessWidget {
  const PublicScorecardView({super.key, required this.match});

  final PublicMatchScore match;

  @override
  Widget build(BuildContext context) {
    final reports = ScorecardBuilder.build(
      innings: match.innings,
      teamName: match.teamName,
      playerName: match.playerName,
    );
    final status = PublicStatuses.normalize(match.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MatchHeader(
          badge: PublicStatuses.scorecardBadge(status),
          live: match.isGenuinelyLive,
          title: match.displayTitle,
          meta: match.meta,
          result: match.result,
        ),
        const SizedBox(height: 18),
        if (reports.isEmpty)
          const EmptyState('The innings has not started yet.')
        else
          for (final r in reports) ...[
            InningsReportCard(report: r),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}
