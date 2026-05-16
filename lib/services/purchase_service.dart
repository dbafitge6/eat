import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._();
  static PurchaseService get instance => _instance;
  PurchaseService._();

  static const productId = 'eat_premium_monthly';
  static const _premiumKey = 'is_premium';

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    _sub = InAppPurchase.instance.purchaseStream.listen(_handlePurchases);
  }

  void dispose() => _sub?.cancel();

  void _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == productId) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          await _setPremium(true);
          await InAppPurchase.instance.completePurchase(p);
        } else if (p.status == PurchaseStatus.error) {
          // No action needed
        }
      }
    }
  }

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }

  Future<bool> purchase() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return false;
    final response =
        await InAppPurchase.instance.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return false;
    final param =
        PurchaseParam(productDetails: response.productDetails.first);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<bool> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      return _isPremium;
    } catch (_) {
      return false;
    }
  }
}
