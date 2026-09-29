import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final name in [
    'hint',
    'trophy',
    'clear',
    'mute',
    'heart',
    'lock',
    'coin',
    'erase',
    'pause',
    'ad',
    'pencil',
    'backArrow',
    'unmute',
  ]) {
    test(
      '$name icon is lightweight, decodable and truly transparent',
      () async {
        final bytes = await File('lib/assets/icons/$name.png').readAsBytes();
        expect(bytes.length, lessThan(32768));
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 64);
        expect(frame.image.height, 64);
        final pixels = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var transparent = 0;
        var visible = 0;
        for (var i = 3; i < pixels.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) == 0) transparent++;
          if (pixels.getUint8(i) > 0) visible++;
        }
        expect(transparent, greaterThan(400));
        expect(visible, greaterThan(200));
        frame.image.dispose();
        codec.dispose();
      },
    );
  }
}
