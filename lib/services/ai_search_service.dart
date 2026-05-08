import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiFoodResult {
  final String name;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double fiber;
  final double sodium;
  final bool isEstimate;

  const AiFoodResult({
    required this.name,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.fiber,
    required this.sodium,
    required this.isEstimate,
  });
}

class AiSearchService {
  static final AiSearchService _instance = AiSearchService._();
  static AiSearchService get instance => _instance;
  AiSearchService._();

  static const _prefKey = 'anthropic_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key);
  }

  Future<AiFoodResult?> search(String query) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final prompt = '''
食品「$query」の栄養素を教えてください。
必ず以下のJSON形式だけで返してください。説明文は不要です。

{
  "name": "正式な食品名",
  "kcal": 100gあたりのカロリー(数値),
  "protein": たんぱく質g(数値),
  "fat": 脂質g(数値),
  "carb": 炭水化物g(数値),
  "fiber": 食物繊維g(数値),
  "sodium": ナトリウムmg(数値)
}

外食メニューや市販品の場合は1食・1個あたりの数値でも構いません。
その場合は name に「〇〇 (1食分)」のように記載してください。
数値が不明な場合は一般的な推定値を使用してください。
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 256,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final text = body['content'][0]['text'] as String;

      // JSONを抽出
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) return null;

      final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      return AiFoodResult(
        name: data['name'] as String? ?? query,
        kcal: (data['kcal'] as num?)?.toDouble() ?? 0,
        protein: (data['protein'] as num?)?.toDouble() ?? 0,
        fat: (data['fat'] as num?)?.toDouble() ?? 0,
        carb: (data['carb'] as num?)?.toDouble() ?? 0,
        fiber: (data['fiber'] as num?)?.toDouble() ?? 0,
        sodium: (data['sodium'] as num?)?.toDouble() ?? 0,
        isEstimate: true,
      );
    } catch (_) {
      return null;
    }
  }
}
