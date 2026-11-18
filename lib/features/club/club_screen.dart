import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../domain/models/team.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/require_auth.dart';
import '../../shared/widgets/workspace_scaffold.dart';
import '../dashboard/dashboard_screen.dart' show RolePill;
import 'club_workspace_controller.dart';
import 'player_form_sheet.dart';
import 'team_form_sheet.dart';

/// A club's teams and squads (`club.html`).
class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key, required this.args});

  final ClubArgs args;

  @override
  Widget build(BuildContext context) {
    return RequireAuth(
      builder: (context, user) => _ClubBody(clubId: args.clubId, user: user),
    );
  }
}

class _ClubBody extends StatefulWidget {
  const _ClubBody({required this.clubId, required this.user});

  final String clubId;
  final User user;

  @override
  State<_ClubBody> createState() => _ClubBodyState();
}

class _ClubBodyState extends State<_ClubBody> {
  ClubWorkspaceController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ClubWorkspaceController(
      services: AppScope.of(context),
      clubId: widget.clubId,
      user: widget.user,
      watchPlayers: true,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  Future<void> _editTeam(ClubWorkspaceController c, [Team? team]) async {
    final draft = await showFormSheet<Team>(
      context,
      (_) => TeamFormSheet(clubId: c.clubId, initial: team),
    );
    if (draft == null || !mounted) return;
    final roster = AppScope.of(context).roster;
    try {
      await roster.saveTeam(draft, teamId: team?.id, userId: widget.user.uid);
      if (mounted) {
        showToast(context, team == null ? 'Team saved.' : 'Team updated.');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, describeError(e, fallback: 'Could not save team.'));
      }
    }
  }

  Future<void> _deleteTeam(ClubWorkspaceController c, Team team) async {
    if (c.players.any((p) => p.teamId == team.id)) {
      await alertDialog(
        context,
        title: 'Team has players',
        message: 'Move or remove this team’s players before deleting the team.',
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Delete team',
      message: 'Delete ${team.displayName}?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final roster = AppScope.of(context).roster;
    try {
      await roster.deleteTeam(team.id);
      if (mounted) showToast(context, 'Team deleted.');
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not delete team.'),
        );
      }
    }
  }

  Future<void> _editPlayer(
    ClubWorkspaceController c, {
    Player? player,
    String? teamId,
  }) async {
    final draft = await showFormSheet<Player>(
      context,
      (_) => PlayerFormSheet(
        clubId: c.clubId,
        teams: c.teams,
        initial: player,
        preselectedTeamId: teamId,
      ),
    );
    if (draft == null || !mounted) return;
    final roster = AppScope.of(context).roster;
    try {
      await roster.savePlayer(
        draft,
        playerId: player?.id,
        userId: widget.user.uid,
      );
      if (mounted) {
        showToast(
          context,
          player == null ? 'Player saved.' : 'Player updated.',
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not save player.'),
        );
      }
    }
  }

  Future<void> _deletePlayer(Player player) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove player',
      message: 'Remove ${player.fullName} from this club?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final roster = AppScope.of(context).roster;
    try {
      await roster.deletePlayer(player.id);
      if (mounted) showToast(context, 'Player removed.');
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          describeError(e, fallback: 'Could not remove player.'),
        );
      }
    }
  }

  // ------------------------------------------------------------------ build

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
              const LoadingBlock(message: 'Loading club…')
            else if (club != null) ...[
              _ClubHeading(controller: controller),
              const SizedBox(height: 18),
              _TeamsCard(
                controller: controller,
                onAddTeam: () => _editTeam(controller),
                onEditTeam: (t) => _editTeam(controller, t),
                onDeleteTeam: (t) => _deleteTeam(controller, t),
                onAddPlayer: (teamId) =>
                    _editPlayer(controller, teamId: teamId),
                onEditPlayer: (p) => _editPlayer(controller, player: p),
                onDeletePlayer: _deletePlayer,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ClubHeading extends StatelessWidget {
  const _ClubHeading({required this.controller});

  final ClubWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final club = controller.club!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Club workspace'),
                  const SizedBox(height: 8),
                  Text(
                    club.displayName,
                    style: AppText.heading(size: 28, letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 4),
                  Text(club.subtitle, style: AppText.muted(size: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            RolePill(controller.role),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.emoji_events_outlined, size: 18),
              label: const Text('Tournaments'),
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.tournaments,
                arguments: ClubArgs(controller.clubId),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.sports_cricket, size: 18),
              label: const Text('Matches'),
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.matches,
                arguments: ClubArgs(controller.clubId),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamsCard extends StatelessWidget {
  const _TeamsCard({
    required this.controller,
    required this.onAddTeam,
    required this.onEditTeam,
    required this.onDeleteTeam,
    required this.onAddPlayer,
    required this.onEditPlayer,
    required this.onDeletePlayer,
  });

  final ClubWorkspaceController controller;
  final VoidCallback onAddTeam;
  final ValueChanged<Team> onEditTeam;
  final ValueChanged<Team> onDeleteTeam;
  final ValueChanged<String?> onAddPlayer;
  final ValueChanged<Player> onEditPlayer;
  final ValueChanged<Player> onDeletePlayer;

  @override
  Widget build(BuildContext context) {
    final teams = controller.teams;
    final players = controller.players;
    final canManage = controller.canManage;

    final Widget list;
    if (!controller.teamsLoaded) {
      list = const LoadingBlock(message: 'Loading teams…');
    } else if (teams.isEmpty) {
      list = EmptyState(
        canManage
            ? 'No teams yet. Add your first team to start building squads.'
            : 'No teams have been added to this club yet.',
      );
    } else {
      list = Column(
        children: [
          for (final team in teams) ...[
            _TeamTile(
              team: team,
              players: (players.where((p) => p.teamId == team.id).toList()
                ..sort(Player.byJerseyThenName)),
              canManage: canManage,
              onEdit: () => onEditTeam(team),
              onDelete: () => onDeleteTeam(team),
              onAddPlayer: () => onAddPlayer(team.id),
              onEditPlayer: onEditPlayer,
              onDeletePlayer: onDeletePlayer,
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return SectionCard(
      eyebrow: 'Squad structure',
      title: 'Teams & squads',
      subtitle: 'Select a team to see the players registered to it.',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SoftTag('${teams.length} ${teams.length == 1 ? 'team' : 'teams'}'),
          const SizedBox(height: 6),
          SoftTag(
            '${players.length} ${players.length == 1 ? 'player' : 'players'}',
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canManage) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Add team'),
                  onPressed: onAddTeam,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Register player'),
                  onPressed: teams.isEmpty ? null : () => onAddPlayer(null),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          list,
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.players,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onAddPlayer,
    required this.onEditPlayer,
    required this.onDeletePlayer,
  });

  final Team team;
  final List<Player> players;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddPlayer;
  final ValueChanged<Player> onEditPlayer;
  final ValueChanged<Player> onDeletePlayer;

  @override
  Widget build(BuildContext context) {
    const transparent = RoundedRectangleBorder(side: BorderSide.none);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: ExpansionTile(
        shape: transparent,
        collapsedShape: transparent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            team.initials,
            style: AppText.heading(size: 14, color: AppColors.onMint),
          ),
        ),
        title: Text(team.displayName, style: AppText.heading(size: 16)),
        subtitle: Text(
          '${team.subtitle}  ·  ${players.length} ${players.length == 1 ? 'player' : 'players'}',
          style: AppText.muted(size: 12),
        ),
        children: [
          if (canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: const Text('Add player'),
                    onPressed: onAddPlayer,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit team'),
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
            ),
          if (players.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: EmptyState('No players registered to this team yet.'),
            )
          else
            for (final player in players)
              _PlayerRow(
                player: player,
                canManage: canManage,
                onEdit: () => onEditPlayer(player),
                onDelete: () => onDeletePlayer(player),
              ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Player player;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      player.role,
      player.battingStyle,
      if (player.bowlingStyle.isNotEmpty) player.bowlingStyle,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              player.jerseyNumber?.toString() ?? '–',
              style: AppText.heading(size: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.fullName,
                  style: AppText.heading(size: 14, weight: FontWeight.w700),
                ),
                if (details.isNotEmpty)
                  Text(details, style: AppText.muted(size: 11)),
              ],
            ),
          ),
          if (canManage) ...[
            IconButton(
              tooltip: 'Edit player',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Remove player',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.orange,
              ),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
