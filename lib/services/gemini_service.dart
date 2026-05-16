import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<String?> getApiKey() async => ApiConfig.geminiApiKey;

  // HTTP で直接 Gemini REST API を呼ぶ共通メソッド
  Future<String?> _generate(String apiKey, String prompt) async {
    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 8192,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = candidates[0]['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null) return null;
    // gemini-2.5-flash はthinkingパートが先に来るので thought!=true のテキストを結合
    final textParts = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text']?.toString() ?? '')
        .join('');
    return textParts.isEmpty ? null : textParts;
  }

  Future<Map<String, double>?> extractNutritionFromText(String pageText) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null) return null;

      final prompt = '''
以下のHTMLから栄養成分（カロリー・たんぱく質・脂質・炭水化物）を抽出してください。
ルール:
- 100gあたりの値に換算して返す
- JSON形式のみ返す。説明文不要
- 形式: {"kcal": 数値, "protein": 数値, "fat": 数値, "carb": 数値}
- 見つからない項目は0

HTML:
$pageText
''';

      final text = await _generate(apiKey, prompt);
      if (text == null) return null;
      final cleaned = text.replaceAll(RegExp(r'```[a-z]*\n?'), '').replaceAll('```', '').trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final json = jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
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
''';

      final text = await _generate(apiKey, prompt);
      if (text == null) return [];
      return _parseResponse(text);
    } catch (_) {
      return [];
    }
  }

  // チャット用: 単発メッセージを送ってレスポンスを返す
  Future<String?> chat(String apiKey, List<Map<String, String>> history, String message) async {
    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final contents = <Map<String, dynamic>>[];
    for (final h in history) {
      contents.add({'role': h['role'], 'parts': [{'text': h['text']}]});
    }
    contents.add({'role': 'user', 'parts': [{'text': message}]});

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
    });
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = candidates[0]['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null) return null;
    final textParts = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text']?.toString() ?? '')
        .join('');
    return textParts.isEmpty ? null : textParts;
  }

  // 外食メニュー提案
  Future<List<RestaurantMenuItem>> searchRestaurantMenu(String query) async {
    final apiKey = await getApiKey();
    if (apiKey == null) throw Exception('APIキーが設定されていません');

    final prompt = '''
「$query」の典型的なメニューを10件提案してください。
必ずJSON配列のみで返してください。説明文・コードブロック記号は不要です。

[{"name":"メニュー名","kcal":500,"protein":20,"fat":15,"carb":60}]
''';

    final text = await _generate(apiKey, prompt);
    if (text == null) throw Exception('レスポンスが空です');
    final jsonStr = _extractJsonArray(text);
    if (jsonStr == null) throw Exception('JSONが見つかりません\n返答: ${text.substring(0, text.length.clamp(0, 200))}');
    final list = jsonDecode(jsonStr) as List;
    return list.map((m) => RestaurantMenuItem.fromJson(m as Map<String, dynamic>)).toList();
  }

  String? _extractJsonArray(String text) {
    // markdownコードブロックを除去
    var cleaned = text.replaceAll(RegExp(r'```[a-z]*\n?'), '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return cleaned.substring(start, end + 1);
  }

  List<Food> _parseResponse(String text) {
    try {
      final jsonStr = _extractJsonArray(text);
      if (jsonStr == null) return [];
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

class RestaurantMenuItem {
  final String name;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;

  RestaurantMenuItem({required this.name, required this.kcal,
      required this.protein, required this.fat, required this.carb});

  factory RestaurantMenuItem.fromJson(Map<String, dynamic> j) => RestaurantMenuItem(
    name: j['name']?.toString() ?? '',
    kcal: _d(j['kcal']),
    protein: _d(j['protein']),
    fat: _d(j['fat']),
    carb: _d(j['carb']),
  );

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
