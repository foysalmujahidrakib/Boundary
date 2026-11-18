import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';

/// The "B" mark plus the `boundary.` wordmark (`.brand` in the web CSS).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = size * 1.45;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: mark,
          height: mark,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(9),
              topRight: Radius.circular(9),
              bottomRight: Radius.circular(9),
              bottomLeft: Radius.circular(3),
            ),
          ),
          child: Text(
            'B',
            style: AppText.heading(size: size * 0.82, color: AppColors.onMint),
          ),
        ),
        const SizedBox(width: 9),
        Text.rich(
          TextSpan(
            text: 'boundary',
            style: AppText.heading(size: size, letterSpacing: -1),
            children: [
              TextSpan(
                text: '.',
                style: AppText.heading(size: size, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
