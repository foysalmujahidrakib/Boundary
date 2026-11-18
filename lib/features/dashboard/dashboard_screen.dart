import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../data/errors.dart';
import '../../data/repositories/club_repository.dart';
import '../../domain/constants.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/require_auth.dart';
import '../../shared/widgets/responsive.dart';
import '../../shared/widgets/workspace_scaffold.dart';

/// The signed-in home: your clubs, and a form to create a new one.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequireAuth(builder: (context, user) => _DashboardBody(user: user));
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({required this.user});

  final User user;

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  late Future<MyClubs> _clubs = _load();

  Future<MyClubs> _load() =>
      AppScope.of(context).clubs.loadMyClubs(widget.user.uid);

  Future<void> _reload() async {
    setState(() => _clubs = _load());
    await _clubs.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
      user: widget.user,
      onRefresh: _reload,
      children: [
        FutureBuilder<MyClubs>(
          future: _clubs,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final role = (data != null && data.entries.isNotEmpty)
                ? data.entries.first.membership.role
                : ClubRole.member;
            return _Heading(role: role);
          },
        ),
        const SizedBox(height: 20),
        TwoColumn(
          primary: _ClubListCard(future: _clubs),
          secondary: _CreateClubCard(user: widget.user, onCreated: _reload),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Your workspace'),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'Good cricket starts here',
                  style: AppText.heading(size: 30, letterSpacing: -1),
                  children: [
                    TextSpan(
                      text: '.',
                      style: AppText.heading(size: 30, color: AppColors.mint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your club workspace and get ready for your next match.',
                style: AppText.muted(size: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RolePill(role),
      ],
    );
  }
}

/// `CLUB ADMIN` badge.
class RolePill extends StatelessWidget {
  const RolePill(this.role, {super.key});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.highlight,
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ClubRole.label(role),
        style: AppText.body(
          size: 9,
          weight: FontWeight.w800,
          color: AppColors.mint,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ClubListCard extends StatelessWidget {
  const _ClubListCard({required this.future});

  final Future<MyClubs> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyClubs>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final Widget body;
        if (snapshot.hasError) {
          body = NoticeBanner(
            describeError(
              snapshot.error!,
              fallback: 'Your clubs could not be loaded.',
            ),
          );
        } else if (data == null) {
          body = const LoadingBlock(message: 'Loading your club memberships…');
        } else if (data.entries.isEmpty) {
          body = const EmptyState(
            'You are not part of a club yet. Create one to get started.',
          );
        } else {
          body = Column(
            children: [
              for (final entry in data.entries) ...[
                _ClubTile(entry: entry),
                const SizedBox(height: 10),
              ],
            ],
          );
        }

        final count = data?.membershipCount ?? 0;
        return SectionCard(
          eyebrow: 'Club workspace',
          title: 'Your clubs',
          trailing: SoftTag('$count ${count == 1 ? 'club' : 'clubs'}'),
          child: body,
        );
      },
    );
  }
}

class _ClubTile extends StatelessWidget {
  const _ClubTile({required this.entry});

  final ClubMembership entry;

  @override
  Widget build(BuildContext context) {
    final club = entry.club;
    return AppCard(
      color: AppColors.canvas,
      radius: 10,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRoutes.club, arguments: ClubArgs(club.id)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              club.initials,
              style: AppText.heading(size: 15, color: AppColors.onMint),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.displayName, style: AppText.heading(size: 16)),
                const SizedBox(height: 2),
                Text(club.displayLocation, style: AppText.muted(size: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RolePill(entry.membership.role),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _CreateClubCard extends StatefulWidget {
  const _CreateClubCard({required this.user, required this.onCreated});

  final User user;
  final Future<void> Function() onCreated;

  @override
  State<_CreateClubCard> createState() => _CreateClubCardState();
}

class _CreateClubCardState extends State<_CreateClubCard> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final clubs = AppScope.of(context).clubs;
    try {
      await clubs.createClub(
        user: widget.user,
        name: _name.text.trim(),
        location: _location.text.trim(),
        description: _description.text.trim(),
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _name.clear();
      _location.clear();
      _description.clear();
      showToast(context, 'Club created.');
      setState(() => _busy = false);
      await widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeError(e, fallback: 'The club could not be created.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'Start something',
      title: 'Create a club',
      subtitle:
          'Set up a dedicated workspace for your cricket club or organization.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Club name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a club name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? 'Creating…' : 'Create club'),
            ),
          ],
        ),
      ),
    );
  }
}
