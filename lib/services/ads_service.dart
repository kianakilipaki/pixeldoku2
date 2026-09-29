import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:pixeldoku/services/purchase_service.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../state/app_state.dart';

class AdsService {
  static bool _isReady = false;
  static bool _interstitialReady = false;
  static bool _isInitializing = false;
  static bool _isInitialized = false;
  static bool _isLoadingInterstitial = false;
  static bool _isShowingInterstitial = false;

  static String get _interstitialPlacementId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? 'Interstitial_iOS'
      : 'Interstitial_Android';

  // -----------------------------
  // IS READY
  // -----------------------------
  static bool get isReady => _isReady;

  // -----------------------------
  // INIT
  // -----------------------------
  static void init() {
    AppLogger.log('AdsService.init preload start');
    _loadRewarded('CoinShopAd');
    _loadInterstitial();
  }

  static void ensureInitialized() {
    if (_isInitialized || _isInitializing) {
      AppLogger.log(
        'AdsService.ensureInitialized skipped initialized=$_isInitialized initializing=$_isInitializing',
      );
      return;
    }

    if (!_supportsUnityAds) {
      AppLogger.log(
        'AdsService.ensureInitialized skipped unsupported platform',
      );
      return;
    }

    _isInitializing = true;
    AppLogger.log('AdsService.ensureInitialized UnityAds.init start');
    UnityAds.init(
      gameId: defaultTargetPlatform == TargetPlatform.android
          ? '6110380'
          : '6110381',
      testMode: true,
      onComplete: () {
        _isInitializing = false;
        _isInitialized = true;
        AppLogger.log('AdsService.ensureInitialized UnityAds.init complete');
        init();
      },
      onFailed: (error, message) {
        _isInitializing = false;
        AppLogger.log(
          'AdsService.ensureInitialized UnityAds.init failed: $message',
        );
      },
    );
  }

  // -----------------------------
  // SHOW REWARDED
  // -----------------------------
  static void showRewarded(AppState appState) {
    showRewardedCoins(appState);
  }

  static void showRewardedCoins(AppState appState) {
    ensureInitialized();
    if (!_isReady) {
      AppLogger.log("Unity rewarded coins not ready yet");
      return;
    }

    UnityAds.showVideoAd(
      placementId: 'CoinShopAd',
      onComplete: (placementId) {
        AppLogger.log('Unity rewarded coins complete placement=$placementId');
        appState.addCoins(10);

        // reset state and preload next ad
        _isReady = false;
        _loadRewarded(placementId);
      },
      onFailed: (placementId, error, message) {
        AppLogger.log("Unity Ads show failed: $message");
      },
    );
  }

  static void showRewardedHints(AppState appState) {
    ensureInitialized();
    if (!_isReady) {
      AppLogger.log("Unity rewarded hints not ready yet");
      return;
    }

    UnityAds.showVideoAd(
      placementId: 'CoinShopAd',
      onComplete: (placementId) {
        AppLogger.log('Unity rewarded hints complete placement=$placementId');
        appState.addHints(3);
        _isReady = false;
        _loadRewarded(placementId);
      },
      onFailed: (placementId, error, message) {
        AppLogger.log("Unity Ads show failed: $message");
      },
    );
  }

  static Future<bool> showInterstitial() async {
    if (!await PurchaseService.shouldShowGameplayAds()) {
      AppLogger.log('Unity interstitial skipped: gameplay ads removed');
      return false;
    }

    if (!_supportsUnityAds) {
      AppLogger.log('Unity interstitial skipped unsupported platform');
      return false;
    }

    ensureInitialized();
    if (_isShowingInterstitial) {
      AppLogger.log(
        'Unity interstitial skipped because one is already showing',
      );
      return false;
    }
    _isShowingInterstitial = true;

    if (!await _waitForInterstitial()) {
      _isShowingInterstitial = false;
      AppLogger.log(
        'Unity interstitial unavailable after waiting for initialization/load',
      );
      return false;
    }

    _interstitialReady = false;
    final result = Completer<bool>();

    void finish(bool shown) {
      if (result.isCompleted) return;
      _isShowingInterstitial = false;
      _loadInterstitial();
      result.complete(shown);
    }

    try {
      await UnityAds.showVideoAd(
        placementId: _interstitialPlacementId,
        onStart: (placementId) {
          AppLogger.log('Unity interstitial started placement=$placementId');
        },
        onComplete: (placementId) {
          AppLogger.log('Unity interstitial complete placement=$placementId');
          finish(true);
        },
        onSkipped: (placementId) {
          AppLogger.log('Unity interstitial skipped placement=$placementId');
          finish(true);
        },
        onFailed: (placementId, error, message) {
          AppLogger.log("Unity interstitial failed: $message");
          finish(false);
        },
      );
    } catch (error) {
      AppLogger.log('Unity interstitial show exception: $error');
      finish(false);
    }

    return result.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _isShowingInterstitial = false;
        _loadInterstitial();
        return false;
      },
    );
  }

  static void _loadRewarded(String placementId) {
    AppLogger.log('Unity rewarded load start placement=$placementId');
    UnityAds.load(
      placementId: placementId,
      onComplete: (placementId) {
        _isReady = true;
        AppLogger.log('Unity rewarded load complete placement=$placementId');
      },
      onFailed: (placementId, error, message) {
        _isReady = false;
        AppLogger.log("Unity Ads failed to load: $message");
      },
    );
  }

  static void _loadInterstitial() {
    if (!_supportsUnityAds ||
        !_isInitialized ||
        _interstitialReady ||
        _isLoadingInterstitial) {
      return;
    }

    _isLoadingInterstitial = true;
    AppLogger.log('Unity interstitial load start');
    try {
      UnityAds.load(
        placementId: _interstitialPlacementId,
        onComplete: (placementId) {
          _isLoadingInterstitial = false;
          _interstitialReady = true;
          AppLogger.log(
            'Unity interstitial load complete placement=$placementId',
          );
        },
        onFailed: (placementId, error, message) {
          _isLoadingInterstitial = false;
          _interstitialReady = false;
          AppLogger.log(
            'Unity interstitial failed to load error=$error message=$message',
          );
        },
      ).catchError((Object error) {
        _isLoadingInterstitial = false;
        _interstitialReady = false;
        AppLogger.log('Unity interstitial load exception: $error');
      });
    } catch (error) {
      _isLoadingInterstitial = false;
      _interstitialReady = false;
      AppLogger.log('Unity interstitial load exception: $error');
    }
  }

  static Future<bool> _waitForInterstitial() async {
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    var retriedLoad = false;

    while (DateTime.now().isBefore(deadline)) {
      if (_interstitialReady) return true;

      if (_isInitialized && !_isLoadingInterstitial && !retriedLoad) {
        retriedLoad = true;
        _loadInterstitial();
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    return _interstitialReady;
  }

  static bool get _supportsUnityAds {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }
}
