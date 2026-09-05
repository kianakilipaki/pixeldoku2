import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (error) {
      debugPrint('LOGS: Restore purchases failed: $error');
      return null;
    }
  }

  Future<Offerings?> loadOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (error) {
      debugPrint('LOGS: Load offerings failed: $error');
      return null;
    }
  }
}
