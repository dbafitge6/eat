import 'package:share_plus/share_plus.dart';
import '../models/meal_entry.dart';

class ShareService {
  static Future<void> shareMeal({
    required String mealName,
    required double kcal,
    required double protein,
    required double fat,
    required double carb,
  }) async {
    final text = '''🍽️ $mealName を記録しました

📊 栄養素
カロリー: ${kcal.round()} kcal
たんぱく質: ${protein.toStringAsFixed(1)}g
脂質: ${fat.toStringAsFixed(1)}g
炭水化物: ${carb.toStringAsFixed(1)}g

#eat #食事記録 #ダイエット #健康管理''';

    await Share.share(text);
  }

  static Future<void> shareDaySummary({
    required List<MealEntry> meals,
    required double targetKcal,
    required int waterMl,
  }) async {
    final totalKcal = meals.fold(0.0, (s, m) => s + m.kcal);
    final totalProtein = meals.fold(0.0, (s, m) => s + m.protein);
    final totalFat = meals.fold(0.0, (s, m) => s + m.fat);
    final totalCarb = meals.fold(0.0, (s, m) => s + m.carb);
    final ratio = (totalKcal / targetKcal * 100).round();

    final text = '''📋 今日の食事まとめ

カロリー: ${totalKcal.round()} / ${targetKcal.round()} kcal ($ratio%)
たんぱく質: ${totalProtein.toStringAsFixed(1)}g
脂質: ${totalFat.toStringAsFixed(1)}g
炭水化物: ${totalCarb.toStringAsFixed(1)}g
水分: $waterMl ml

${ratio <= 100 ? '✅ 目標達成！' : '⚠️ 少しオーバー'}

#eat #食事記録 #ダイエット''';

    await Share.share(text);
  }

  static Future<void> shareWeekSummary({
    required double weeklyKcal,
    required double weeklyTarget,
  }) async {
    final ratio = (weeklyKcal / weeklyTarget * 100).round();
    final text = '''📅 今週の食事まとめ

週間カロリー: ${weeklyKcal.round()} / ${weeklyTarget.round()} kcal ($ratio%)

${ratio <= 100 ? '✅ 週間目標達成！' : '⚠️ 少しオーバー気味'}
でも1週間単位でみれば大丈夫！継続が大切 💪

#eat #食事管理 #週間ダイエット''';

    await Share.share(text);
  }
}
