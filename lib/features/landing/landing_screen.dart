import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/responsive.dart';
import '../auth/auth_sheet.dart';
import 'public_standings_section.dart';

/// The public homepage (`index.html`): hero, live matches, public
/// tournament standings, features and sign-up.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _featuresKey = GlobalKey();
  final _howKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _openLive() => Navigator.of(context).pushNamed(AppRoutes.liveMatches);

  void _primaryAction(User? user, {bool register = true}) {
    if (user != null) {
      Navigator.of(context).pushNamed(AppRoutes.dashboard);
    } else {
      showAuthSheet(context, register: register);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return StreamBuilder<User?>(
      stream: auth.userChanges,
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const BrandLogo(size: 19),
            actions: [
              if (user == null) ...[
                TextButton(
                  onPressed: () => _primaryAction(null, register: false),
                  child: const Text('Log in'),
                ),
              ] else
                TextButton(
                  onPressed: () => _primaryAction(user),
                  child: const Text('Open workspace'),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu),
                onSelected: (value) {
                  switch (value) {
                    case 'features':
                      _scrollTo(_featuresKey);
                    case 'how':
                      _scrollTo(_howKey);
                    case 'live':
                      _openLive();
                    case 'register':
                      _primaryAction(null);
                    case 'signout':
                      auth.signOut();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'features',
                    child: Text('Features'),
                  ),
                  const PopupMenuItem(
                    value: 'how',
                    child: Text('How it works'),
                  ),
                  const PopupMenuItem(
                    value: 'live',
                    child: Text('Live matches'),
                  ),
                  if (user == null)
                    const PopupMenuItem(
                      value: 'register',
                      child: Text('Create account'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'signout',
                      child: Text('Sign out'),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: ContentWidth(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      user: user,
                      onPrimary: () => _primaryAction(user),
                      onExplore: () => _scrollTo(_featuresKey),
                    ),
                    const SizedBox(height: 36),
                    _SectionIntro(
                      eyebrow: 'Follow the action',
                      title: 'Live match.',
                      body:
                          'See every ongoing public match in one dedicated live match centre.',
                      action: FilledButton(
                        onPressed: _openLive,
                        child: const Text('Open Live Match Centre →'),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const _SectionIntro(
                      eyebrow: 'Competition centre',
                      title: 'Tournament standings.',
                      body:
                          'Every tournament on Boundary is public. Pick one to see its teams, points and net run rate.',
                    ),
                    const SizedBox(height: 16),
                    const PublicStandingsSection(),
                    const SizedBox(height: 40),
                    const _AudienceStrip(),
                    const SizedBox(height: 40),
                    KeyedSubtree(key: _featuresKey, child: const _Features()),
                    const SizedBox(height: 40),
                    KeyedSubtree(
                      key: _howKey,
                      child: _CallToAction(
                        user: user,
                        onPressed: () => _primaryAction(user),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero({
    required this.user,
    required this.onPrimary,
    required this.onExplore,
  });

  final User? user;
  final VoidCallback onPrimary;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Built for cricket communities'),
        const SizedBox(height: 16),
        Text(
          'Run your club.',
          style: AppText.heading(size: 44, letterSpacing: -2, height: 1.05),
        ),
        Text(
          'Own the game.',
          style: AppText.heading(
            size: 44,
            letterSpacing: -2,
            height: 1.05,
            color: AppColors.mint,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'One place for cricket clubs and organizers to manage their teams, '
          'competitions and match days. Give every fan a reason to follow.',
          style: AppText.body(size: 15, color: AppColors.muted, height: 1.55),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: onPrimary,
              child: Text(user == null ? 'Get started →' : 'Open workspace →'),
            ),
            OutlinedButton(
              onPressed: onExplore,
              child: const Text('Explore the platform'),
            ),
          ],
        ),
      ],
    );

    return TwoColumn(
      primaryFlex: 1,
      secondaryFlex: 1,
      gap: 28,
      primary: copy,
      secondary: const _PreviewPanel(),
    );
  }
}

/// The illustrative scoreboard in the hero (`.hero-panel`).
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surfaceRaised],
        ),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PLATFORM PREVIEW',
                style: AppText.eyebrow(color: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('BAN VS WI · 2nd Test', style: AppText.heading(size: 17)),
          const SizedBox(height: 14),
          _previewTeam('WI', 'Batting', '356/10'),
          const SizedBox(height: 8),
          _previewTeam('BAN', 'Yet to bat', '—'),
          const SizedBox(height: 12),
          Text('106.4 overs', style: AppText.muted(size: 12)),
          Text(
            'Illustrative data only',
            style: AppText.body(size: 10, color: AppColors.muted),
          ),
          const Divider(height: 28),
          for (final (n, label) in const [
            ('01', 'Club workspace'),
            ('02', 'Live match centre'),
            ('03', 'Tournament tools'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(
                    n,
                    style: AppText.heading(size: 13, color: AppColors.mint),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppText.body(size: 14, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewTeam(String code, String state, String score) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(code.substring(0, 2), style: AppText.heading(size: 12)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(code, style: AppText.heading(size: 15)),
            Text(state, style: AppText.muted(size: 11)),
          ],
        ),
      ),
      Text(score, style: AppText.heading(size: 20, color: AppColors.mint)),
    ],
  );
}

// -------------------------------------------------------------- sections

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 10),
        Text(title, style: AppText.heading(size: 30, letterSpacing: -1)),
        const SizedBox(height: 6),
        Text(
          body,
          style: AppText.body(size: 14, color: AppColors.muted, height: 1.5),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );
  }
}

class _AudienceStrip extends StatelessWidget {
  const _AudienceStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'MADE FOR EVERY LEVEL OF THE GAME',
          style: AppText.eyebrow(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final label in [
              'Clubs',
              'Organizers',
              'Players',
              'Supporters',
            ])
              SoftTag(label),
          ],
        ),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  static const _items = <(IconData, String, String)>[
    (
      Icons.groups_2_outlined,
      'Club workspace',
      'Keep your club identity, members and teams organized in one dedicated space.',
    ),
    (
      Icons.emoji_events_outlined,
      'Tournament management',
      'Set up competitions, invite teams and organize fixtures around your format.',
    ),
    (
      Icons.sports_cricket,
      'Live scoring',
      'Score ball by ball and let spectators follow published matches as they happen.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('One platform, many possibilities'),
        const SizedBox(height: 10),
        Text(
          'Everything around',
          style: AppText.heading(size: 30, letterSpacing: -1),
        ),
        Text(
          'your cricket club.',
          style: AppText.heading(
            size: 30,
            letterSpacing: -1,
            color: AppColors.mint,
          ),
        ),
        const SizedBox(height: 18),
        for (final (icon, title, body) in _items) ...[
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.highlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.mint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.heading(size: 17)),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: AppText.body(
                          size: 13,
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CallToAction extends StatelessWidget {
  const _CallToAction({required this.user, required this.onPressed});

  final User? user;
  final VoidCallback onPressed;

  static const _steps = <(String, String, String)>[
    ('01', 'Create your account', 'Register securely with your email.'),
    ('02', 'Set up a club', 'Add your club name and basic details.'),
    ('03', 'Build your cricket hub', 'Manage members, teams and tournaments.'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Get your club started'),
          const SizedBox(height: 10),
          Text(
            'Your game.',
            style: AppText.heading(size: 30, letterSpacing: -1),
          ),
          Text(
            'Your community.',
            style: AppText.heading(
              size: 30,
              letterSpacing: -1,
              color: AppColors.mint,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create an account, set up a club workspace and invite the people who help run your cricket.',
            style: AppText.body(size: 14, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPressed,
            child: Text(
              user == null ? 'Create your account →' : 'Open your workspace →',
            ),
          ),
          const SizedBox(height: 22),
          for (final (n, title, body) in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n,
                    style: AppText.heading(size: 20, color: AppColors.mint),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.heading(size: 15)),
                        Text(body, style: AppText.muted(size: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandLogo(size: 17),
        const SizedBox(height: 8),
        Text(
          '© Boundary · Developed by Foysal Mujahid Rakib',
          textAlign: TextAlign.center,
          style: AppText.muted(size: 11),
        ),
      ],
    );
  }
}
