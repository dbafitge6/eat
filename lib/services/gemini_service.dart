import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food.dart';
import '../models/meal_entry.dart';
import '../models/meal_plan.dart';
import '../utils/pfc_score.dart';

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
以下のテキストから栄養成分（カロリー・たんぱく質・脂質・炭水化物）を抽出してください。
食品パッケージのラベルOCRテキスト、HTMLどちらにも対応してください。
ルール:
- 100gあたりの値に換算して返す（1食分・1枚分などの記載があれば100gに換算する）
- JSON形式のみ返す。説明文不要
- 形式: {"kcal": 数値, "protein": 数値, "fat": 数値, "carb": 数値}
- 見つからない項目は0
- エネルギー＝kcal、たんぱく質＝protein、脂質＝fat、炭水化物＝carb

テキスト:
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
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
        'thinkingConfig': {'thinkingBudget': 0},
      },
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

  // 1週間献立生成
  Future<List<MealPlan>?> generateMealPlan({
    required List<Map<String, dynamic>> schedule,
    required List<String> allergies,
    required String dislikedFoods,
    required double targetKcal,
    required String weekStart,
    DietType dietType = DietType.calorie,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;
    if (schedule.isEmpty) return [];

    const weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
    final scheduleLines = schedule.map((s) {
      final date = s['date'] as String;
      final mealType = s['meal_type'] as int;
      final dt = DateTime.parse(date);
      final dayName = weekdayNames[dt.weekday - 1];
      final mealName = ['朝食', '昼食', '夕食'][mealType];
      return '$date（$dayName）$mealName';
    }).join('\n');

    final allergyText = allergies.isEmpty ? 'なし' : allergies.join('、');
    final dislikedText = dislikedFoods.isEmpty ? 'なし' : dislikedFoods;

    final dietInstruction = dietType == DietType.keto
        ? '''- ダイエット種別: ケトジェニック（糖質制限）
- 1食あたりの糖質（carb）は10g以下に抑える
- 脂質を積極的に使い、全カロリーの60〜75%を脂質で摂る
- タンパク質は全カロリーの20〜30%、卵・肉・魚・チーズを中心に使う
- ご飯・パン・麺・根菜・砂糖を使わない（高糖質食材禁止）'''
        : '''- ダイエット種別: カロリー制限ダイエット
- 【絶対厳守】1食あたりの合計カロリー（dishesのkcal合計）は350kcal以下にすること
- 朝食は250kcal以下、昼食・夕食は350kcal以下を上限とする
- 揚げ物・炒め物・バター調理は一切使わない。蒸し・茹で・焼き・生を使う
- 主食（ご飯・パン・麺）は1食80g以下に抑えるか、完全に省いてよい
- 鶏むね・ささみ・白身魚・豆腐・卵・納豆・きのこ・葉物野菜を中心に使う
- たんぱく質は1食15g以上を目標にする（筋肉維持のため）
- 脂質の多い食材（豚バラ・サーモン・チーズ・マヨネーズ・ごま油多量）は使わない''';

    final prompt = '''
以下の条件で献立を生成してください。

【条件】
$dietInstruction
- 目標カロリー: ${targetKcal.round()} kcal/日
- アレルギー食材（必ず除外）: $allergyText
- 苦手食材（できれば除外）: $dislikedText
- 文科省食品データベースにある一般的な食材を優先
- 和食・洋食・中華をバランスよく

【生成する食事】
$scheduleLines

JSON配列のみを返してください（説明文・コードブロック不要）：
[{"date":"YYYY-MM-DD","meal_type":0,"title":"食事タイトル","dishes":[{"name":"食材名","grams":150,"kcal":200,"protein":5,"fat":3,"carb":35}]}]
meal_type: 0=朝食, 1=昼食, 2=夕食
''';

    try {
      final text = await _generate(apiKey, prompt);
      if (text == null) return null;
      final jsonStr = _extractJsonArray(text);
      if (jsonStr == null) return null;
      final list = jsonDecode(jsonStr) as List;
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        final dishes = (m['dishes'] as List? ?? [])
            .map((d) => MealPlanDish.fromJson(d as Map<String, dynamic>))
            .toList();
        return MealPlan(
          weekStart: weekStart,
          date: m['date'] as String,
          mealType: (m['meal_type'] as num).toInt(),
          title: m['title']?.toString() ?? '',
          dishes: dishes,
        );
      }).toList();
    } catch (_) {
      return null;
    }
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

  // 食事AIコメント生成
  Future<String?> generateMealComment(List<MealEntry> entries, int mealType) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;
    if (entries.isEmpty) return null;

    final mealName = ['朝食', '昼食', '夕食', '間食', '夜食', '補食'][mealType.clamp(0, 5)];
    final totalKcal = entries.fold(0.0, (s, e) => s + e.kcal);
    final totalProtein = entries.fold(0.0, (s, e) => s + e.protein);
    final totalFat = entries.fold(0.0, (s, e) => s + e.fat);
    final totalCarb = entries.fold(0.0, (s, e) => s + e.carb);
    final foodList = entries.map((e) => '${e.foodName}(${e.grams.round()}g)').join('、');

    final prompt = '''
以下の$mealNameの内容について、ダイエット・健康管理アプリのAIコーチとして短いコメントをしてください。

【食事内容】
$foodList
カロリー: ${totalKcal.round()}kcal / タンパク質: ${totalProtein.toStringAsFixed(1)}g / 脂質: ${totalFat.toStringAsFixed(1)}g / 炭水化物: ${totalCarb.toStringAsFixed(1)}g

【ルール】
- 2〜3文で簡潔に
- ポジティブな点を1つ褒める
- 改善点があれば1つだけやさしく提案する
- 絵文字を1〜2個使う
- 日本語のみ、JSON不要、テキストだけ返す
''';

    try {
      return await _generate(apiKey, prompt);
    } catch (_) {
      return null;
    }
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
