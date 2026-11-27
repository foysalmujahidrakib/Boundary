import 'package:boundary/shared/widgets/brand_logo.dart';
import 'package:boundary/domain/constants.dart';
import 'package:boundary/features/scoring/widgets/scoring_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BrandLogo renders the bundled Boundary icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandLogo())),
      ),
    );

    expect(find.bySemanticsLabel('Boundary logo'), findsOneWidget);
  });

  testWidgets('no-ball dialog offers and records zero batter runs', (
    tester,
  ) async {
    int? selectedRuns;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedRuns = await showExtrasDialog(
                  context,
                  DeliveryKind.noBall,
                );
              },
              child: const Text('Record no-ball'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Record no-ball'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '0'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '0'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(selectedRuns, 0);
  });
}
