import 'app_services.dart';
import 'core/routes.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/ui.dart';
import 'features/club/club_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/matches/matches_screen.dart';
import 'features/public/live_matches_screen.dart';
import 'features/scorecard/scorecard_screen.dart';
import 'features/scoring/scoring_screen.dart';
import 'features/tournaments/tournaments_screen.dart';

/// Root widget: theme, service scope and route table.
class BoundaryApp extends StatelessWidget {
  const BoundaryApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Boundary',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.landing,
        // Applies system-inset protection to the Navigator, including every
        // route, dialog, and bottom sheet presented by the main application.
        builder: (context, child) => SafeArea(
          child: child ?? const SizedBox.shrink(),
        ),
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    Widget screen() {
      switch (settings.name) {
        case AppRoutes.landing:
          return const LandingScreen();
        case AppRoutes.dashboard:
          return const DashboardScreen();
        case AppRoutes.liveMatches:
          return const LiveMatchesScreen();
        case AppRoutes.club:
          if (args is ClubArgs) return ClubScreen(args: args);
        case AppRoutes.matches:
          if (args is ClubArgs) return MatchesScreen(args: args);
        case AppRoutes.tournaments:
          if (args is ClubArgs) return TournamentsScreen(args: args);
        case AppRoutes.scoring:
          if (args is MatchArgs) return ScoringScreen(args: args);
        case AppRoutes.scorecard:
          if (args is MatchArgs) return ScorecardScreen(args: args);
        case AppRoutes.publicScorecard:
          if (args is PublicMatchArgs) return PublicScorecardScreen(args: args);
      }
      return const _NotFoundScreen();
    }

    return MaterialPageRoute<void>(
      builder: (_) => screen(),
      settings: settings,
    );
  }
}

/// Shown for an unknown route or a route opened without its arguments.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('Page not found', style: AppText.heading(size: 20)),
              const SizedBox(height: 6),
              Text(
                'Open a club or match from your dashboard.',
                style: AppText.muted(size: 13),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.landing, (_) => false),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
