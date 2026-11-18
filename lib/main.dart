import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'app_services.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/ui.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    // Most likely `flutterfire configure` has not been run for this platform.
    runApp(_SetupErrorApp(message: error.toString()));
    return;
  }
  runApp(BoundaryApp(services: AppServices()));
}

/// Friendly screen when Firebase is not configured (instead of a crash).
class _SetupErrorApp extends StatelessWidget {
  const _SetupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      builder: (context, child) => SafeArea(
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 40,
                    color: AppColors.orange,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Firebase is not configured',
                    style: AppText.heading(size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Run `flutterfire configure --project=boundary-4b4e8` in the '
                    'project folder, then restart the app.',
                    style: AppText.body(
                      size: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(message, style: AppText.muted(size: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
