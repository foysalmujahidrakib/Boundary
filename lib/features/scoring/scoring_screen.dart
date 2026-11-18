import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/innings.dart';
import '../../domain/scoring/scorecard.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/ball_chip.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/require_auth.dart';
import '../../shared/widgets/responsive.dart';
import '../../shared/widgets/workspace_scaffold.dart';
import 'scoring_controller.dart';
import 'widgets/innings_setup_card.dart';
import 'widgets/live_score_card.dart';
import 'widgets/run_pad.dart';
import 'widgets/scoring_dialogs.dart';

/// Ball-by-ball live scoring (`scoring.html`).
class ScoringScreen extends StatelessWidget {
  const ScoringScreen({super.key, required this.args});

  final MatchArgs args;

  @override
  Widget build(BuildContext context) {
    return RequireAuth(
      builder: (context, user) => _ScoringBody(args: args, user: user),
    );
  }
}

class _ScoringBody extends StatefulWidget {
  const _ScoringBody({required this.args, required this.user});

  final MatchArgs args;
  final User user;

  @override
  State<_ScoringBody> createState() => _ScoringBodyState();
}

class _ScoringBodyState extends State<_ScoringBody> {
  ScoringController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ScoringController(
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

  // ---------------------------------------------------------------- actions

  void _report(String? error) {
    if (error != null && mounted) showToast(context, error);
  }

  Future<void> _record(DeliveryRequest request) async {
    final c = _controller!;
    final error = await c.recordDelivery(
      request,
      pickNextBowler: (eligible) async {
        if (!mounted) return null;
        return showNextBowlerDialog(
          context,
          innings: c.current!,
          eligible: eligible,
          maxOversPerBowler: c.rules.maxOversPerBowler,
        );
      },
    );
    _report(error);
  }

  Future<void> _wicket() async {
    final c = _controller!;
    final inn = c.current;
    if (inn == null) return;
    final choice = await showWicketDialog(
      context,
      innings: inn,
      players: c.players,
    );
    if (choice == null) return;
    await _record(
      DeliveryRequest(
        wicket: true,
        dismissedBatterId: choice.dismissedBatterId,
        incomingBatterId: choice.incomingBatterId,
        dismissalType: choice.dismissalType,
      ),
    );
  }

  Future<void> _extra(String kind) async {
    final runs = await showExtrasDialog(context, kind);
    if (runs == null) return;
    await _record(
      kind == DeliveryKind.noBall
          ? DeliveryRequest(kind: kind, batterRuns: runs)
          : DeliveryRequest(kind: kind, extraRunsInput: runs),
    );
  }

  Future<void> _undo() async {
    final ok = await confirmDialog(
      context,
      title: 'Undo delivery',
      message: 'Undo the most recent delivery?',
      confirmLabel: 'Undo',
    );
    if (!ok) return;
    _report(await _controller!.undoLastDelivery());
  }

  Future<void> _endInnings() async {
    final ok = await confirmDialog(
      context,
      title: 'End innings',
      message: 'End this innings now?',
      confirmLabel: 'End innings',
      destructive: true,
    );
    if (!ok) return;
    _report(await _controller!.endInnings());
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return WorkspaceScaffold(
          user: widget.user,
          children: [
            if (c.error != null) ...[
              NoticeBanner(c.error!),
              const SizedBox(height: 16),
            ],
            if (!c.ready && c.error == null)
              const LoadingBlock(message: 'Loading match…')
            else if (c.ready)
              ..._content(c),
          ],
        );
      },
    );
  }

  List<Widget> _content(ScoringController c) {
    final match = c.match!;
    final inn = c.current;
    final meta = [
      match.matchDate,
      match.startTime,
      match.venue,
      '${match.format} · ${match.overs} ov',
    ].where((s) => s.isNotEmpty).join(' · ');

    return [
      const Eyebrow('Live scoring'),
      const SizedBox(height: 8),
      Text(c.title, style: AppText.heading(size: 26, letterSpacing: -0.7)),
      const SizedBox(height: 4),
      Text(meta, style: AppText.muted(size: 13)),
      if (c.result.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(c.result, style: AppText.heading(size: 16, color: AppColors.mint)),
      ],
      const SizedBox(height: 16),
      if (!c.canManage) ...[
        const NoticeBanner(
          'Only club admins can score matches. You can follow the score below.',
        ),
        const SizedBox(height: 16),
      ],
      if (c.publishFailed) ...[
        const NoticeBanner(
          'The live score was saved, but the public scorecard could not be updated. '
          'It will refresh on the next ball.',
        ),
        const SizedBox(height: 16),
      ],
      if (!c.scoreLoaded)
        const LoadingBlock()
      else ...[
        if (c.canManage && c.nextInningsNumber != null) ...[
          if (c.awaitingSecondInnings) ...[
            const NoticeBanner(
              'Innings break. Set up the second innings to continue.',
            ),
            const SizedBox(height: 16),
          ],
          InningsSetupCard(
            // Rebuild the form when the innings changes.
            key: ValueKey('setup-${c.nextInningsNumber}'),
            controller: c,
            inningsNumber: c.nextInningsNumber!,
            forcedBattingTeamId: c.forcedBattingTeamId,
            busy: c.busy,
            onStart:
                ({
                  required String battingTeamId,
                  required String strikerId,
                  required String nonStrikerId,
                  required String bowlerId,
                }) async {
                  _report(
                    await c.startInnings(
                      battingTeamId: battingTeamId,
                      strikerId: strikerId,
                      nonStrikerId: nonStrikerId,
                      bowlerId: bowlerId,
                    ),
                  );
                },
          ),
          const SizedBox(height: 16),
        ],
        if (!c.hasInnings && !c.canManage)
          const EmptyState('Scoring has not started for this match yet.'),
        if (inn != null) ...[
          TwoColumn(
            primary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LiveScoreCard(controller: c, innings: inn),
                if (c.canManage && !inn.completed) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RunPad(
                          enabled: c.canScoreNow,
                          onRuns: (runs) =>
                              _record(DeliveryRequest(batterRuns: runs)),
                          onWicket: _wicket,
                          onExtra: _extra,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.undo, size: 18),
                                label: const Text('Undo'),
                                onPressed: c.busy || inn.deliveries.isEmpty
                                    ? null
                                    : _undo,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.flag_outlined, size: 18),
                                label: const Text('End innings'),
                                onPressed: c.busy ? null : _endInnings,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (c.canManage && inn.completed && c.innings.length == 2) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Undo last delivery'),
                    onPressed: c.busy || inn.deliveries.isEmpty ? null : _undo,
                  ),
                ],
              ],
            ),
            secondary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BallLog(innings: inn),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Open scorecard'),
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.scorecard,
                    arguments: MatchArgs(clubId: c.clubId, matchId: c.matchId),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ];
  }
}

class _BallLog extends StatelessWidget {
  const _BallLog({required this.innings});

  final Innings innings;

  @override
  Widget build(BuildContext context) {
    final overs = ScorecardBuilder.overs(innings).reversed.take(4).toList();
    return SectionCard(
      eyebrow: 'Ball by ball',
      title: 'Recent overs',
      child: overs.isEmpty
          ? const EmptyState('No deliveries recorded yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final over in overs) ...[
                  Row(
                    children: [
                      Text(
                        'Over ${over.number}',
                        style: AppText.heading(size: 13),
                      ),
                      const Spacer(),
                      Text('${over.runs} runs', style: AppText.muted(size: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BallRow(over.deliveries, size: 30),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}
