import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';

/// Opens [builder] in a keyboard-aware modal bottom sheet and resolves with
/// whatever the sheet pops (mobile replacement for the web's inline forms).
Future<T?> showFormSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Title + scrollable body that lifts above the keyboard.
class FormSheetFrame extends StatelessWidget {
  const FormSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.heading(size: 22)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppText.muted(size: 13)),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// A small gap between form fields.
class FieldGap extends StatelessWidget {
  const FieldGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}
