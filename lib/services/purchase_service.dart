import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoveAdsPurchaseResult {
  const RemoveAdsPurchaseResult({
    required this.purchased,
    this.cancelled = false,
    this.message,
  });

  final bool purchased;
  final bool cancelled;
  final String? message;
}

class PurchaseService {
  static const removeAdsEntitlement = 'no_gameplay_ads';
  static const removeAdsProductId = 'remove_gameplay_ads';
  static const suggestedRemoveAdsPrice = r'$2.99';
  static const _removedAdsPreference = 'gameplay_ads_removed';
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');

  static Future<void>? _initialization;
  static bool _configured = false;
  static bool gameplayAdsRemoved = false;

  Package? _removeAdsPackage;

  static Future<void> initialize() =>
      _initialization ??= _initializePurchases();

  static Future<void> _initializePurchases() async {
    final preferences = await SharedPreferences.getInstance();
    gameplayAdsRemoved = preferences.getBool(_removedAdsPreference) ?? false;

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final apiKey = defaultTargetPlatform == TargetPlatform.android
        ? _androidApiKey
        : _iosApiKey;
    if (apiKey.isEmpty) {
      debugPrint(
        'LOGS: RevenueCat API key missing; real-money purchases are disabled',
      );
      return;
    }

    try {
      if (!await Purchases.isConfigured) {
        await Purchases.configure(PurchasesConfiguration(apiKey));
      }
      _configured = true;
      unawaited(_refreshEntitlement());
    } catch (error) {
      debugPrint('LOGS: RevenueCat initialization failed: $error');
    }
  }

  static Future<void> _refreshEntitlement() async {
    if (!_configured) return;
    try {
      await _applyCustomerInfo(await Purchases.getCustomerInfo());
    } catch (error) {
      debugPrint('LOGS: Refresh purchases failed: $error');
    }
  }

  static Future<void> _applyCustomerInfo(CustomerInfo customerInfo) async {
    final removed =
        customerInfo.entitlements.active[removeAdsEntitlement]?.isActive ==
        true;
    gameplayAdsRemoved = removed;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_removedAdsPreference, removed);
  }

  static Future<bool> shouldShowGameplayAds() async {
    await initialize();
    return !gameplayAdsRemoved;
  }

  Future<CustomerInfo?> restorePurchases() async {
    await initialize();
    if (!_configured) return null;
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _applyCustomerInfo(customerInfo);
      return customerInfo;
    } catch (error) {
      debugPrint('LOGS: Restore purchases failed: $error');
      return null;
    }
  }

  Future<Offerings?> loadOfferings() async {
    await initialize();
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (error) {
      debugPrint('LOGS: Load offerings failed: $error');
      return null;
    }
  }

  Future<String?> loadRemoveAdsPrice() async {
    final offerings = await loadOfferings();
    final packages = offerings?.current?.availablePackages ?? const <Package>[];
    for (final package in packages) {
      if (package.storeProduct.identifier == removeAdsProductId) {
        _removeAdsPackage = package;
        return package.storeProduct.priceString;
      }
    }
    return null;
  }

  Future<RemoveAdsPurchaseResult> purchaseRemoveAds() async {
    await initialize();
    if (!_configured) {
      return const RemoveAdsPurchaseResult(
        purchased: false,
        message: 'Play Store purchases are not configured yet.',
      );
    }

    if (gameplayAdsRemoved) {
      return const RemoveAdsPurchaseResult(purchased: true);
    }

    if (_removeAdsPackage == null) await loadRemoveAdsPrice();
    final package = _removeAdsPackage;
    if (package == null) {
      return const RemoveAdsPurchaseResult(
        purchased: false,
        message: 'Remove Ads is not available from the Play Store yet.',
      );
    }

    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      await _applyCustomerInfo(result.customerInfo);
      if (gameplayAdsRemoved) {
        return const RemoveAdsPurchaseResult(purchased: true);
      }
      return const RemoveAdsPurchaseResult(
        purchased: false,
        message: 'The purchase completed, but Remove Ads was not unlocked.',
      );
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const RemoveAdsPurchaseResult(purchased: false, cancelled: true);
      }
      debugPrint('LOGS: Remove Ads purchase failed: $error');
      return const RemoveAdsPurchaseResult(
        purchased: false,
        message: 'The purchase could not be completed. Please try again.',
      );
    } catch (error) {
      debugPrint('LOGS: Remove Ads purchase failed: $error');
      return const RemoveAdsPurchaseResult(
        purchased: false,
        message: 'The purchase could not be completed. Please try again.',
      );
    }
  }
}
