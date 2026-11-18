import 'package:firebase_auth/firebase_auth.dart';

import '../../app_services.dart';
import '../../core/routes.dart';
import '../../core/ui.dart';

/// Guards a screen that needs a signed-in user (the web pages each did
/// `onAuthStateChanged` + `location.href = "index.html"`).
///
/// While Firebase is still restoring the session a spinner is shown; if there
/// is no user the app returns to the landing screen, and it does so again
/// automatically when the user signs out.
class RequireAuth extends StatelessWidget {
  const RequireAuth({super.key, required this.builder});

  final Widget Function(BuildContext context, User user) builder;

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return StreamBuilder<User?>(
      stream: auth.userChanges,
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) return builder(context, user);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const _RedirectToLanding();
      },
    );
  }
}

class _RedirectToLanding extends StatefulWidget {
  const _RedirectToLanding();

  @override
  State<_RedirectToLanding> createState() => _RedirectToLandingState();
}

class _RedirectToLandingState extends State<_RedirectToLanding> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.landing, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
