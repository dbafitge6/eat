import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food.dart';

class BarcodeService {
  static final BarcodeService instance = BarcodeService._();
  BarcodeService._();

  /// Returns (food, packageGrams) — packageGrams is null if unknown.
  Future<(Food, double?)?> lookup(String barcode) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
        '?fields=product_name,product_name_ja,nutriments,product_quantity,quantity',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;

      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = (product['product_name_ja'] as String?)?.trim().isNotEmpty == true
          ? product['product_name_ja'] as String
          : (product['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      final n = (product['nutriments'] as Map<String, dynamic>?) ?? {};

      // 内容量: product_quantity(数値優先) → quantity文字列をパース
      double? packageGrams;
      final pq = product['product_quantity'];
      if (pq != null) {
        packageGrams = _d(pq);
      } else {
        final qs = (product['quantity'] as String?) ?? '';
        final m = RegExp(r'([\d.]+)\s*g', caseSensitive: false).firstMatch(qs);
        if (m != null) packageGrams = double.tryParse(m.group(1)!);
      }
      if (packageGrams != null && packageGrams <= 0) packageGrams = null;

      final food = Food(
        id: 'barcode_$barcode',
        name: name,
        kcal: _d(n['energy-kcal_100g']),
        protein: _d(n['proteins_100g']),
        fat: _d(n['fat_100g']),
        carb: _d(n['carbohydrates_100g']),
        fiber: _d(n['fiber_100g']),
        sodium: _d(n['sodium_100g']) * 1000,
        calcium: _d(n['calcium_100g']) * 1000,
        iron: _d(n['iron_100g']) * 1000,
      );
      return (food, packageGrams);
    } catch (_) {
      return null;
    }
  }

  double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
