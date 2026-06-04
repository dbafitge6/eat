import 'package:flutter/material.dart';
import '../models/meal_entry.dart';
import '../services/deficiency_trend_service.dart';

class MissingNutrientsWidget extends StatelessWidget {
  final List<MealEntry> meals;
  final Map<String, List<MealEntry>>? weeklyMeals; // 週次データ（オプション）

  const MissingNutrientsWidget({
    super.key,
    required this.meals,
    this.weeklyMeals,
  });

  @override
  Widget build(BuildContext context) {
    final missing = DeficiencyTrendService.instance.getTodayMissingNutrients(meals);
    final chronic = weeklyMeals != null
        ? DeficiencyTrendService.instance.getChronicDeficiencies(weeklyMeals!, 7)
        : <DeficiencyAlert>[];

    if (missing.isEmpty && chronic.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 慢性的な不足（複数日）
          if (chronic.isNotEmpty) ...[
            Row(
              children: [
                const Text('🔴', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '継続的な不足',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF44336),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...chronic.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.message,
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 16),
          ],

          // 今日の不足
          if (missing.isNotEmpty) ...[
            Text(
              '今日まだ摂れていないもの',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            ...missing.map((item) {
              final foods = item.topFoods.take(2).join('・');
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Text('🟡 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          if (foods.isNotEmpty)
                            Text(
                              '→ $foods で補えます',
                              style: TextStyle(fontSize: 11, color: subColor),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
