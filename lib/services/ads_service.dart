import 'package:flutter/foundation.dart';
import 'package:pixeldoku/core/utils/app_logger.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../state/app_state.dart';

class AdsService {
  static bool _isReady = false;
  static bool _interstitialReady = false;
  static bool _isInitializing = false;
  static bool _isInitialized = false;

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
        appState.addCoins(100);

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

  static void showInterstitial() {
    ensureInitialized();
    if (!_interstitialReady) return;

    UnityAds.showVideoAd(
      placementId: 'Interstitial_LevelComplete',
      onComplete: (placementId) {
        AppLogger.log('Unity interstitial complete placement=$placementId');
        _interstitialReady = false;
        _loadInterstitial();
      },
      onFailed: (placementId, error, message) {
        _interstitialReady = false;
        _loadInterstitial();
        AppLogger.log("Unity interstitial failed: $message");
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
    AppLogger.log('Unity interstitial load start');
    UnityAds.load(
      placementId: 'Interstitial_LevelComplete',
      onComplete: (placementId) {
        _interstitialReady = true;
        AppLogger.log(
          'Unity interstitial load complete placement=$placementId',
        );
      },
      onFailed: (placementId, error, message) {
        _interstitialReady = false;
        AppLogger.log("Unity interstitial failed to load: $message");
      },
    );
  }

  static bool get _supportsUnityAds {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }
}
