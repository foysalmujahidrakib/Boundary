import '../../core/ui.dart';

/// Widest layout width, matching the web `.container` (1120px).
const double kContentMaxWidth = 1120;

/// Breakpoint at which two-column layouts kick in (tablet / landscape).
const double kWideBreakpoint = 900;

/// Centers content and caps its width on tablets, with page padding.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 32),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Two columns on wide screens, stacked on phones (`grid-template-columns`
/// collapsing under 900px in the web CSS).
class TwoColumn extends StatelessWidget {
  const TwoColumn({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
    this.gap = 18,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kWideBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: primaryFlex, child: primary),
              SizedBox(width: gap),
              Expanded(flex: secondaryFlex, child: secondary),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            SizedBox(height: gap),
            secondary,
          ],
        );
      },
    );
  }
}
