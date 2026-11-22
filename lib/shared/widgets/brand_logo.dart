import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';

/// The Boundary icon plus the `boundary.` wordmark (`.brand` in the web CSS).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = size * 3.00;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 7), // adjust X to pull closer, Y to nudge vertically
          child: Image.asset(
            'assets/icon/icon.png',
            width: mark,
            height: mark,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Boundary logo',
          ),
        ),
        Transform.translate(
          offset: const Offset(-10, 9),
          child: Text.rich(
            TextSpan(
              text: 'boundary',
              style: AppText.heading(size: size, letterSpacing: -1),
              children: [
                TextSpan(
                  text: '.',
                  style: AppText.heading(size: size, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}