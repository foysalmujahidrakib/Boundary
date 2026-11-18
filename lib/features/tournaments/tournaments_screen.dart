import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../domain/models/tournament.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/require_auth.dart';
import '../../shared/widgets/workspace_scaffold.dart';
import '../club/club_workspace_controller.dart';
import 'tournament_form_sheet.dart';

/// A club's tournaments (`tournaments.html`). Every save is mirrored to the
/// public standings summary.
class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key, required this.args});

  final ClubArgs args;

  @override
  Widget build(BuildContext context) {
    return RequireAuth(
      builder: (context, user) =>
          _TournamentsBody(clubId: args.clubId, user: user),
    );
  }
}

class _TournamentsBody extends StatefulWidget {
  const _TournamentsBody({required this.clubId, required this.user});

  final String clubId;
  final User user;

  @override
  State<_TournamentsBody> createState() => _TournamentsBodyState();
}

class _TournamentsBodyState extends State<_TournamentsBody> {
  ClubWorkspaceController? _controller;
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final c = ClubWorkspaceController(
      services: AppScope.of(context),
      clubId: widget.clubId,
      user: widget.user,
      watchTournaments: true,
    );
    c.addListener(_syncPublicOnce);
    _controller = c;
  }

  /// Once the data is in, make sure every public summary is current (covers
  /// tournaments created before publishing existed, and renamed teams).
  void _syncPublicOnce() {
    final c = _controller;
    if (c == null || _synced || !c.ready || !c.dataLoaded || !c.canManage) {
      return;
    }
    _synced = true;
    AppScope.of(context).tournaments.syncPublicCopies(c.tournaments, c.teams);
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncPublicOnce);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _edit(
    ClubWorkspaceController c, [
    Tournament? tournament,
  ]) async {
    final draft = await showFormSheet<Tournament>(
      context,
      (_) => TournamentFormSheet(
        clubId: c.clubId,
        teams: c.teams,
        initial: tournament,
      ),
    );
    if (draft == null || !mounted) return;
    final repo = AppScope.of(context).tournaments;
    try {
      await repo.save(
        draft,
        tournamentId: tournament?.id,
        userId: widget.user.uid,
        teams: c.teams,
      );
      if (mounted) {
        showToast(
          context,
          tournament == null ? 'Tournament created.' : 'Tournament updated.',
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not save the tournament.'),
        );
      }
    }
  }

  Future<void> _delete(Tournament t) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete tournament',
      message: 'Delete tournament “${t.name}”?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = AppScope.of(context).tournaments;
    try {
      await repo.delete(t.id);
      if (mounted) showToast(context, 'Tournament deleted.');
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not delete the tournament.'),
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
              const LoadingBlock(message: 'Loading tournaments…')
            else if (club != null)
              SectionCard(
                eyebrow: club.displayName,
                title: 'Tournaments',
                subtitle:
                    'Competitions your club runs. Standings are published automatically.',
                trailing: SoftTag('${controller.tournaments.length} total'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.canManage) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create tournament'),
                          onPressed: controller.dataLoaded
                              ? () => _edit(controller)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!controller.tournamentsLoaded)
                      const LoadingBlock()
                    else if (controller.tournaments.isEmpty)
                      const EmptyState('No tournaments yet.')
                    else
                      for (final t in controller.tournaments) ...[
                        _TournamentTile(
                          tournament: t,
                          teamName: controller.teamName,
                          canManage: controller.canManage,
                          onEdit: () => _edit(controller, t),
                          onDelete: () => _delete(t),
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

class _TournamentTile extends StatelessWidget {
  const _TournamentTile({
    required this.tournament,
    required this.teamName,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Tournament tournament;
  final String Function(String? id, [String fallback]) teamName;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final dates = [
      t.startDate,
      t.endDate,
    ].where((d) => d.isNotEmpty).join(' → ');
    final meta = [
      t.season,
      t.format,
      dates,
      t.venue,
    ].where((s) => s.isNotEmpty).join(' · ');

    return AppCard(
      color: AppColors.canvas,
      radius: 10,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.name, style: AppText.heading(size: 17))),
              StatusChip(t.status),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: AppText.muted(size: 12)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in t.teamIds)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    teamName(id),
                    style: AppText.body(size: 11, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 6),
            Row(
              children: [
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
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
