import 'package:boundary/shared/widgets/brand_logo.dart';
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
}
