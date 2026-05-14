import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  static const _prefKey = 'gemini_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefKey) ?? '';
    return key.isEmpty ? null : key;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key.trim());
  }

  Future<Map<String, double>?> extractNutritionFromText(String pageText) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null) return null;

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final prompt = '''
以下のHTMLから栄養成分（カロリー・たんぱく質・脂質・炭水化物）を抽出してください。
サイトごとに構造が異なりますが、栄養成分表示テーブルやラベルを探して抽出してください。

ルール:
- 100gあたりの値に換算して返す（1食分・1本・1袋などは100g換算する）
- JSON形式のみ返す。説明文・コードブロック不要
- 形式: {"kcal": 数値, "protein": 数値, "fat": 数値, "carb": 数値}
- 見つからない項目は0

HTML:
$pageText
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final json = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      return {
        'kcal': _toDouble(json['kcal']),
        'protein': _toDouble(json['protein']),
        'fat': _toDouble(json['fat']),
        'carb': _toDouble(json['carb']),
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Food>> searchFood(String query) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null) return [];
      if (query.trim().isEmpty) return [];

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''
食品「$query」に関する食品を最大5件、以下のJSON配列形式のみで返してください。
他の文字は一切含めないでください。

[
  {
    "name": "食品名",
    "kcal": 100gあたりkcal(数値),
    "protein": 100gあたりたんぱく質g(数値),
    "fat": 100gあたり脂質g(数値),
    "carb": 100gあたり炭水化物g(数値)
  }
]

数値は整数または小数で返してください。不明な場合は0としてください。
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      return _parseResponse(text);
    } catch (_) {
      return [];
    }
  }

  List<Food> _parseResponse(String text) {
    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1 || end <= start) return [];

      final jsonStr = text.substring(start, end + 1);
      final raw = jsonDecode(jsonStr);
      if (raw is! List) return [];

      final results = <Food>[];
      for (int i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is! Map) continue;
        final food = _parseItem(item, i);
        if (food != null) results.add(food);
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Food? _parseItem(Map<dynamic, dynamic> item, int index) {
    try {
      final name = item['name']?.toString();
      if (name == null || name.isEmpty) return null;

      return Food(
        id: 'gemini_$index',
        name: name,
        kcal: _toDouble(item['kcal']),
        protein: _toDouble(item['protein']),
        fat: _toDouble(item['fat']),
        carb: _toDouble(item['carb']),
        fiber: _toDouble(item['fiber']),
        sodium: _toDouble(item['sodium']),
        calcium: _toDouble(item['calcium']),
        iron: _toDouble(item['iron']),
      );
    } catch (_) {
      return null;
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
