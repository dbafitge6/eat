import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class RecognizedFoodItem {
  final String name;
  final double confidence; // 0.0 ~ 1.0
  final double estimatedGrams;

  const RecognizedFoodItem({
    required this.name,
    required this.confidence,
    required this.estimatedGrams,
  });

  bool get isLowConfidence => confidence < 0.6;
}

class FoodRecognitionService {
  static final FoodRecognitionService instance = FoodRecognitionService._();
  FoodRecognitionService._();

  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<List<RecognizedFoodItem>> recognizeFoodFromImage(
      String imagePath) async {
    try {
      const apiKey = ApiConfig.geminiApiKey;
      if (apiKey.isEmpty) {
        debugPrint('[FoodRecognition] APIキーなし');
        return [];
      }

      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);
      debugPrint(
          '[FoodRecognition] 画像サイズ: ${imageBytes.length} bytes');

      final uri = Uri.parse('$_endpoint?key=$apiKey');
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': base64Image
                }
              },
              {
                'text': '''この食事の写真に写っている食材・料理を全て特定してください。

以下のJSON配列形式のみで返してください。説明文・コードブロックは不要です。

[
  {
    "name": "食材・料理名（日本語）",
    "confidence": 0.0〜1.0（確信度。はっきり見えるものは0.9以上、不明瞭なものは0.5未満）,
    "estimated_grams": 推定グラム数（数値）
  }
]

注意:
- 見えているものだけを列挙する
- 推定が難しいものはconfidenceを低くする
- 料理名でも食材名でも可
- 最大10件まで'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 1024,
          'thinkingConfig': {'thinkingBudget': 0},
        },
      });

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[FoodRecognition] HTTPステータス: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('[FoodRecognition] エラー: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return [];
      final content = candidates[0]['content'] as Map?;
      final parts = content?['parts'] as List?;
      if (parts == null) return [];
      final text = parts
          .whereType<Map>()
          .where((p) => p['thought'] != true)
          .map((p) => p['text']?.toString() ?? '')
          .join('');

      debugPrint('[FoodRecognition] Geminiレスポンス: $text');
      if (text.isEmpty) return [];

      final cleaned =
          text.replaceAll(RegExp(r'```[a-z]*\n?'), '').replaceAll('```', '').trim();
      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');
      if (start == -1 || end == -1 || end <= start) return [];

      final list = jsonDecode(cleaned.substring(start, end + 1)) as List;
      return list.whereType<Map>().map((item) {
        final confidence = _toDouble(item['confidence']) .clamp(0.0, 1.0);
        final grams = _toDouble(item['estimated_grams']);
        return RecognizedFoodItem(
          name: item['name']?.toString() ?? '不明',
          confidence: confidence,
          estimatedGrams: grams > 0 ? grams : 100.0,
        );
      }).toList();
    } catch (e) {
      debugPrint('[FoodRecognition] 例外: $e');
      return [];
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
