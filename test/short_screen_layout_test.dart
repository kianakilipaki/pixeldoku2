import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/features/home/home_page.dart';
import 'package:pixeldoku/features/profile/profile_page.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('home fits without scrolling and menu remains fixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()..isLoading = false),
          ChangeNotifierProvider(create: (_) => GameState()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    final menuIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'lib/assets/icons/medallion-simple.png',
    );
    final before = tester.getRect(menuIcon);
    expect(find.byType(SingleChildScrollView), findsNothing);
    await tester.drag(find.byType(HomePage), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.getRect(menuIcon), before);
    expect(menuIcon.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final bottomInset in [24.0, 48.0]) {
    testWidgets(
      'navigation strip reserves $bottomInset pixels without double padding',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
        tester.view.padding = FakeViewPadding(bottom: bottomInset);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                ForestNavigationSafeArea(child: child!),
            home: Builder(
              builder: (context) {
                expect(MediaQuery.paddingOf(context).bottom, 0);
                expect(MediaQuery.viewPaddingOf(context).bottom, 0);
                return const SafeArea(
                  child: ColoredBox(key: ValueKey('page'), color: Colors.green),
                );
              },
            ),
          ),
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('page'))).bottom,
          640 - bottomInset,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(360, 640)]) {
    for (final page in [const HomePage(), const ProfilePage()]) {
      testWidgets('${page.runtimeType} fits $size without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AppState()),
              ChangeNotifierProvider(create: (_) => GameState()),
            ],
            child: MaterialApp(home: page),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('profile name Save appears only after editing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => GameState()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SAVE'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'UniquePlayer');
    await tester.pump();
    expect(find.text('SAVE'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(
      find.text('Connect to the internet to save a unique username.'),
      findsOneWidget,
    );
    expect(find.text('SAVE'), findsOneWidget);
  });

  testWidgets('short viewport scrolls controls into reach without shrinking', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 400,
            child: ForestResponsiveViewport(
              minimumHeight: 720,
              child: Column(
                children: [
                  SizedBox(height: 80, child: Text('HUD')),
                  Expanded(child: Placeholder()),
                  SizedBox(height: 80, child: Text('CONTROLS')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('CONTROLS').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
