import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';

class LimitService {
  static final LimitService _instance = LimitService._();
  static LimitService get instance => _instance;
  LimitService._();

  static const _aiSearchKey = 'limit_ai_search_';
  static const _restaurantKey = 'limit_restaurant_';

  static const freeMealLimit = 3;
  static const freeAISearchLimit = 5;
  static const freeRestaurantLimit = 3;
  static const freeAIChatLimit = 3;
  static const premiumAIChatLimit = 15;

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<int> _getCount(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefix + _today()) ?? 0;
  }

  Future<void> _increment(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefix + _today();
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  // AI food search
  Future<bool> canSearchAI() async {
    if (PurchaseService.instance.isPremium) return true;
    return await _getCount(_aiSearchKey) < freeAISearchLimit;
  }

  Future<void> incrementAICount() => _increment(_aiSearchKey);

  Future<int> aiCountRemaining() async {
    if (PurchaseService.instance.isPremium) return 999;
    return freeAISearchLimit - await _getCount(_aiSearchKey);
  }

  // Restaurant suggestions
  Future<bool> canSearchRestaurant() async {
    if (PurchaseService.instance.isPremium) return true;
    return await _getCount(_restaurantKey) < freeRestaurantLimit;
  }

  Future<void> incrementRestaurantCount() => _increment(_restaurantKey);

  Future<int> restaurantCountRemaining() async {
    if (PurchaseService.instance.isPremium) return 999;
    return freeRestaurantLimit - await _getCount(_restaurantKey);
  }
}
