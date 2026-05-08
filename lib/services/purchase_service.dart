import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'ad_service.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._();
  static PurchaseService get instance => _instance;
  PurchaseService._();

  // RevenueCatコンソールで発行したAPIキーに差し替える
  static const String _apiKey = 'appl_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  static const String _entitlementId = 'premium';
  static const String _productId = 'eat_premium_monthly';

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> init() async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
    final config = PurchasesConfiguration(_apiKey);
    await Purchases.configure(config);
    await _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _isPremium =
          info.entitlements.all[_entitlementId]?.isActive ?? false;
      await AdService.instance.setPremium(_isPremium);
    } catch (_) {}
  }

  Future<bool> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null) return false;
      final pkg = offering.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == _productId,
        orElse: () => offering.availablePackages.first,
      );
      final result = await Purchases.purchasePackage(pkg);
      _isPremium =
          result.customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
      await AdService.instance.setPremium(_isPremium);
      return _isPremium;
    } catch (e) {
      return false;
    }
  }

  Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      _isPremium = info.entitlements.all[_entitlementId]?.isActive ?? false;
      await AdService.instance.setPremium(_isPremium);
      return _isPremium;
    } catch (_) {
      return false;
    }
  }
}
