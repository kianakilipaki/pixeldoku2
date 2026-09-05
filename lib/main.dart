import 'dart:async';
import 'dart:io' show Socket;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:pixeldoku/features/home/home_page.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/state/app_state.dart';
import 'package:pixeldoku/state/game_state.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------
// MAIN
// -----------------------------
Future<void> main() async {
  runZonedGuarded(
    () async {
      AppLogger.log('main start');
      WidgetsFlutterBinding.ensureInitialized();
      AppLogger.log('flutter bindings initialized');

      FlutterError.onError = (details) {
        AppLogger.error(
          'flutter framework error',
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.error('uncaught platform error', error, stackTrace);
        return true;
      };

      const supabaseHost = 'ebbapummsxfluikikbes.supabase.co';
      AppLogger.log('supabase reachability check start');
      if (await _canReachHost(supabaseHost)) {
        AppLogger.log('supabase initialize start');
        try {
          await Supabase.initialize(
            url: 'https://$supabaseHost',
            anonKey: 'sb_publishable_Mjy67YdON_KOSYlp37oB9g_1KKdggwd',
          );
          AppLogger.log('supabase initialize complete');
        } catch (error, stackTrace) {
          AppLogger.error(
            'supabase initialize failed; continuing offline',
            error,
            stackTrace,
          );
        }
      } else {
        AppLogger.log('supabase unreachable; continuing with local storage');
      }

      AppLogger.log('unity ads startup init skipped; ads initialize lazily');

      AppLogger.log('runApp start');
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppState()..init()),
            ChangeNotifierProvider(create: (_) => GameState()),
          ],
          child: const MainApp(),
        ),
      );
      AppLogger.log('runApp called');
    },
    (error, stackTrace) {
      AppLogger.error('uncaught zoned error', error, stackTrace);
    },
  );
}

Future<bool> _canReachHost(String host) async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      host,
      443,
      timeout: const Duration(seconds: 2),
    );
    return true;
  } on Object catch (error) {
    AppLogger.log('supabase reachability check failed: $error');
    return false;
  } finally {
    socket?.destroy();
  }
}

class MainApp extends StatelessWidget {
  // -----------------------------
  // MAIN APP
  // -----------------------------
  const MainApp({super.key});

  // -----------------------------
  // BUILD
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = baseTextTheme.copyWith(
      displayLarge: _silkscreen(baseTextTheme.displayLarge),
      displayMedium: _silkscreen(baseTextTheme.displayMedium),
      displaySmall: _silkscreen(baseTextTheme.displaySmall),
      headlineLarge: _silkscreen(baseTextTheme.headlineLarge),
      headlineMedium: _silkscreen(baseTextTheme.headlineMedium),
      headlineSmall: _silkscreen(baseTextTheme.headlineSmall),
      titleLarge: _silkscreen(baseTextTheme.titleLarge),
      titleMedium: _silkscreen(baseTextTheme.titleMedium),
      titleSmall: _silkscreen(baseTextTheme.titleSmall),
      bodyLarge: _firaSans(baseTextTheme.bodyLarge),
      bodyMedium: _firaSans(baseTextTheme.bodyMedium),
      bodySmall: _firaSans(baseTextTheme.bodySmall),
      labelLarge: _firaSans(baseTextTheme.labelLarge),
      labelMedium: _firaSans(baseTextTheme.labelMedium),
      labelSmall: _firaSans(baseTextTheme.labelSmall),
    );

    return MaterialApp(
      title: 'PixelDoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Silkscreen',
        textTheme: textTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(textStyle: _prominentLabel),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(textStyle: _prominentLabel),
        ),
      ),
      home: const HomePage(),
    );
  }

  static TextStyle? _silkscreen(TextStyle? style) =>
      style?.copyWith(fontFamily: 'Silkscreen', fontWeight: FontWeight.normal);

  static TextStyle? _firaSans(TextStyle? style) =>
      style?.copyWith(fontFamily: 'Fira Sans', fontWeight: FontWeight.w400);

  static const _prominentLabel = TextStyle(
    fontFamily: 'Silkscreen',
    fontWeight: FontWeight.normal,
  );
}
