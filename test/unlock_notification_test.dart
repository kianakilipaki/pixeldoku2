import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/features/themes/themes_page.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/widgets/unlock_notification.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'unlock notification slides out and opens its target when tapped',
    (tester) async {
      var opened = false;
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      showUnlockNotification(
        pageContext,
        label: 'Swift Paw',
        onOpen: () => opened = true,
      );
      await tester.pumpAndSettle();
      expect(find.text('SWIFT PAW'), findsOneWidget);
      await tester.tap(find.text('SWIFT PAW'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.text('SWIFT PAW'), findsNothing);
    },
  );

  testWidgets('unlock notification automatically disappears', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    showUnlockNotification(pageContext, label: 'Hatchling', onOpen: () {});
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('HATCHLING'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('HATCHLING'), findsNothing);
  });

  testWidgets('Collections opens and reveals a requested title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(
          home: CollectionsPage(revealTitle: 'Lightning Solver'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final target = find.text('LIGHTNING SOLVER');
    expect(target, findsOneWidget);
    expect(tester.getRect(target).bottom, lessThanOrEqualTo(700));
    expect(tester.getRect(target).top, greaterThanOrEqualTo(0));
  });
}
