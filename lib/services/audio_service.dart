import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/models/theme_catalog.dart';

class PixelAudioService {
  PixelAudioService._();

  static final PixelAudioService instance = PixelAudioService._();

  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'theme_music');
  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx');
  bool _configuredAssetPrefix = false;
  final Map<String, Uint8List> _sfxBytes = {};

  bool _musicOn = true;
  bool _sfxOn = true;
  String? _currentMusicAsset;
  int _sfxToken = 0;

  static const String magicSfx = 'lib/assets/sfx/080245_sfx-magic-84935.mp3';
  static const String wrongSfx = 'lib/assets/sfx/error-8-206492.mp3';
  static const String levelCompleteSfx =
      'lib/assets/sfx/open-new-level-143027.mp3';

  Future<void> init({
    required bool musicOn,
    required bool sfxOn,
    PixelDokuTheme? theme,
  }) async {
    _musicOn = musicOn;
    _sfxOn = sfxOn;

    _configureAssetPrefix();
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _sfxPlayer.setReleaseMode(ReleaseMode.release);
    unawaited(_preloadSfx());

    if (theme != null) {
      await playThemeMusic(theme);
    }
  }

  Future<void> setMusicOn(bool value, {PixelDokuTheme? theme}) async {
    _musicOn = value;

    if (!_musicOn) {
      await _musicPlayer.pause();
      return;
    }

    if (theme != null) {
      await playThemeMusic(theme);
    } else {
      await _musicPlayer.resume();
    }
  }

  Future<void> setSfxOn(bool value) async {
    _sfxOn = value;
  }

  Future<void> playThemeMusic(PixelDokuTheme theme) async {
    _configureAssetPrefix();
    if (!_musicOn) return;
    if (_currentMusicAsset == theme.musicAsset) {
      await _musicPlayer.resume();
      return;
    }

    _currentMusicAsset = theme.musicAsset;
    await _safeRun(
      'AudioService.playThemeMusic asset=${theme.musicAsset}',
      () => _musicPlayer.play(AssetSource(theme.musicAsset)),
    );
  }

  Future<void> pauseMusic() async {
    await _safeRun('AudioService.pauseMusic', _musicPlayer.pause);
  }

  Future<void> resumeMusic() async {
    if (!_musicOn) return;
    await _safeRun('AudioService.resumeMusic', _musicPlayer.resume);
  }

  Future<void> stopMusic() async {
    _currentMusicAsset = null;
    await _safeRun('AudioService.stopMusic', _musicPlayer.stop);
  }

  Future<void> playWrongAnswer() => playSfx(wrongSfx);

  Future<void> playHint() => playSfx(magicSfx);

  Future<void> playLevelComplete() => playSfx(levelCompleteSfx);

  Future<void> playSfx(String asset) async {
    if (!_sfxOn) return;

    final token = ++_sfxToken;
    final shouldResumeMusic =
        _musicOn && _musicPlayer.state == PlayerState.playing;

    await _safeRun('AudioService.playSfx asset=$asset', () async {
      if (shouldResumeMusic) {
        await _musicPlayer.pause();
      }

      await _sfxPlayer.stop();
      final bytes = _sfxBytes[asset] ?? await _loadAssetBytes(asset);
      _sfxBytes[asset] = bytes;
      await _sfxPlayer.play(BytesSource(bytes));
      await Future<void>.delayed(_sfxDuration(asset));

      if (token == _sfxToken && shouldResumeMusic && _musicOn) {
        await _musicPlayer.resume();
      }
    });
  }

  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
  }

  void _configureAssetPrefix() {
    if (_configuredAssetPrefix) return;

    _musicPlayer.audioCache = AudioCache(prefix: '');
    _sfxPlayer.audioCache = AudioCache(prefix: '');
    _configuredAssetPrefix = true;
    AppLogger.log('AudioService asset cache prefix set to empty');
  }

  Future<void> _preloadSfx() async {
    for (final asset in [magicSfx, wrongSfx, levelCompleteSfx]) {
      _sfxBytes[asset] ??= await _loadAssetBytes(asset);
    }
  }

  Future<Uint8List> _loadAssetBytes(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Duration _sfxDuration(String asset) {
    return switch (asset) {
      wrongSfx => const Duration(milliseconds: 900),
      magicSfx => const Duration(milliseconds: 1400),
      levelCompleteSfx => const Duration(milliseconds: 1800),
      _ => const Duration(milliseconds: 1000),
    };
  }

  Future<void> _safeRun(String label, Future<void> Function() action) async {
    try {
      AppLogger.log('$label start');
      await action();
      AppLogger.log('$label complete');
    } catch (error, stackTrace) {
      AppLogger.error('$label failed', error, stackTrace);
    }
  }
}
