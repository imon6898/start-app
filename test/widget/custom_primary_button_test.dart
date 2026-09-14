import 'package:flutter/material.dart';
import 'package:flutter_starter/app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// House pattern for a widget test: GetMaterialApp is the shell, because R and
/// CustomColors both resolve through Get.context.
void main() {
  Future<void> pumpButton(WidgetTester tester, Widget button) {
    return tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: Center(child: button)),
      ),
    );
  }

  testWidgets('renders its label', (tester) async {
    await pumpButton(tester, CustomButton(text: 'Sign In', onPressed: () {}));

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('fires onPressed when tapped', (tester) async {
    var taps = 0;
    await pumpButton(
      tester,
      CustomButton(text: 'Sign In', onPressed: () => taps++),
    );

    await tester.tap(find.byType(CustomButton));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('is inert while loading', (tester) async {
    var taps = 0;
    await pumpButton(
      tester,
      CustomButton(text: 'Sign In', loading: true, onPressed: () => taps++),
    );

    await tester.tap(find.byType(CustomButton));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('is inert when onPressed is null', (tester) async {
    await pumpButton(
      tester,
      const CustomButton(text: 'Sign In', onPressed: null),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
