import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../domain/models/cricket_match.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/require_auth.dart';
import '../../shared/widgets/workspace_scaffold.dart';
import '../club/club_workspace_controller.dart';
import 'match_form_sheet.dart';

/// Fixtures of a club (`matches.html`).
class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key, required this.args});

  final ClubArgs args;

  @override
  Widget build(BuildContext context) {
    return RequireAuth(
      builder: (context, user) => _MatchesBody(clubId: args.clubId, user: user),
    );
  }
}

class _MatchesBody extends StatefulWidget {
  const _MatchesBody({required this.clubId, required this.user});

  final String clubId;
  final User user;

  @override
  State<_MatchesBody> createState() => _MatchesBodyState();
}

class _MatchesBodyState extends State<_MatchesBody> {
  ClubWorkspaceController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ClubWorkspaceController(
      services: AppScope.of(context),
      clubId: widget.clubId,
      user: widget.user,
      watchTournaments: true,
      watchMatches: true,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _edit(ClubWorkspaceController c, [CricketMatch? match]) async {
    final draft = await showFormSheet<CricketMatch>(
      context,
      (_) => MatchFormSheet(
        clubId: c.clubId,
        teams: c.teams,
        tournaments: c.tournaments,
        initial: match,
      ),
    );
    if (draft == null || !mounted) return;
    final repo = AppScope.of(context).matches;
    try {
      await repo.save(draft, matchId: match?.id, userId: widget.user.uid);
      if (mounted) {
        showToast(context, match == null ? 'Match saved.' : 'Match updated.');
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not save the match.'),
        );
      }
    }
  }

  Future<void> _delete(CricketMatch m, String title) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete match',
      message: 'Delete match “$title”?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = AppScope.of(context).matches;
    try {
      await repo.delete(m.id);
      if (mounted) showToast(context, 'Match deleted.');
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not delete the match.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final club = controller.club;
        return WorkspaceScaffold(
          user: widget.user,
          children: [
            if (controller.error != null) ...[
              NoticeBanner(controller.error!),
              const SizedBox(height: 16),
            ],
            if (club == null && controller.error == null)
              const LoadingBlock(message: 'Loading matches…')
            else if (club != null)
              SectionCard(
                eyebrow: club.displayName,
                title: 'Matches',
                subtitle: 'Schedule fixtures, then score them live.',
                trailing: SoftTag('${controller.matches.length} total'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.canManage) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Schedule match'),
                          onPressed: controller.dataLoaded
                              ? () => _edit(controller)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!controller.matchesLoaded)
                      const LoadingBlock()
                    else if (controller.matches.isEmpty)
                      const EmptyState('No matches scheduled yet.')
                    else
                      for (final m in controller.matches) ...[
                        _MatchTile(
                          match: m,
                          controller: controller,
                          onEdit: () => _edit(controller, m),
                          onDelete: (title) => _delete(m, title),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.match,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final CricketMatch match;
  final ClubWorkspaceController controller;
  final VoidCallback onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final a = controller.teamName(match.teamAId);
    final b = controller.teamName(match.teamBId);
    final title = match.title.isNotEmpty ? match.title : '$a vs $b';
    final tournament = match.tournamentId == null
        ? null
        : controller.tournaments
              .where((t) => t.id == match.tournamentId)
              .firstOrNull
              ?.name;
    final meta = [
      match.matchDate,
      match.startTime,
      match.venue,
      '${match.format} · ${match.overs} ov',
    ].where((s) => s.isNotEmpty).join(' · ');

    final toss = match.tossWinnerId == null
        ? null
        : '${controller.teamName(match.tossWinnerId)} won the toss'
              '${match.tossDecision == null ? '' : ' and chose to ${match.tossDecision}'}';

    void open(String route) => Navigator.of(context).pushNamed(
      route,
      arguments: MatchArgs(clubId: controller.clubId, matchId: match.id),
    );

    return AppCard(
      color: AppColors.canvas,
      radius: 10,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: AppText.heading(size: 17))),
              const SizedBox(width: 8),
              StatusChip(match.status),
            ],
          ),
          if (match.title.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '$a vs $b',
              style: AppText.body(size: 13, weight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 4),
          Text(meta, style: AppText.muted(size: 12)),
          if (tournament != null)
            Text('🏆 $tournament', style: AppText.muted(size: 12)),
          if (toss != null) Text(toss, style: AppText.muted(size: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              if (controller.canManage)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  icon: const Icon(Icons.scoreboard_outlined, size: 16),
                  label: const Text('Score'),
                  onPressed: () => open(AppRoutes.scoring),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Scorecard'),
                onPressed: () => open(AppRoutes.scorecard),
              ),
              if (controller.canManage) ...[
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  onPressed: () => onDelete(title),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
