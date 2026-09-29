import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixeldoku/widgets/forest_page_widgets.dart';

void main() {
  testWidgets('ForestPressBounce scales down while pressed and springs back', (
    tester,
  ) async {
    const targetKey = Key('bounce-target');
    final hapticCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ForestPressBounce(
            child: SizedBox(key: targetKey, width: 100, height: 40),
          ),
        ),
      ),
    );

    AnimatedScale bounce() => tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(ForestPressBounce),
        matching: find.byType(AnimatedScale),
      ),
    );

    expect(bounce().scale, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await tester.pump();
    expect(bounce().scale, 0.95);
    expect(hapticCalls, hasLength(1));
    expect(hapticCalls.single.arguments, 'HapticFeedbackType.lightImpact');

    await gesture.up();
    await tester.pump();
    expect(bounce().scale, 1);
  });
}
