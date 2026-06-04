import 'package:flutter/material.dart';
import '../services/nutrition_db_service.dart';
import '../models/meal_entry.dart';

class SymptomSearchScreen extends StatefulWidget {
  final List<MealEntry> todayMeals;

  const SymptomSearchScreen({super.key, required this.todayMeals});

  @override
  State<SymptomSearchScreen> createState() => _SymptomSearchScreenState();
}

class _SymptomSearchScreenState extends State<SymptomSearchScreen> {
  Map<String, dynamic>? _selected;

  @override
  Widget build(BuildContext context) {
    final db = NutritionDbService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);

    return Scaffold(
      appBar: AppBar(
        title: const Text('体の不調から食材を探す'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: db.symptoms.isEmpty
          ? const Center(child: Text('データを読み込み中...'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '今日、体の調子はどうですか？',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),

                // 不調タググリッド
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: db.symptoms.map((s) {
                    final isSelected = _selected?['id'] == s['id'];
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selected = isSelected ? null : s;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.1)),
                          ),
                        ),
                        child: Text(
                          s['symptom'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : textColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // 選択した不調の詳細
                if (_selected != null) _SymptomDetail(
                  symptom: _selected!,
                  todayMeals: widget.todayMeals,
                ),
              ],
            ),
    );
  }
}

class _SymptomDetail extends StatelessWidget {
  final Map<String, dynamic> symptom;
  final List<MealEntry> todayMeals;

  const _SymptomDetail({required this.symptom, required this.todayMeals});

  @override
  Widget build(BuildContext context) {
    final db = NutritionDbService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);

    final deficiencies =
        List<String>.from(symptom['possible_deficiencies'] as List? ?? []);
    final foods =
        List<String>.from(symptom['recommended_foods'] as List? ?? []);
    final advice = symptom['advice'] as String? ?? '';

    // 今日すでに食べた食材を除外
    final todayFoodNames = todayMeals.map((m) => m.foodName.toLowerCase()).toSet();
    final remainingFoods = foods.where((f) {
      return !todayFoodNames.any((d) => d.contains(f.toLowerCase()));
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symptom['symptom'] as String,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),

          // 不足成分
          if (deficiencies.isNotEmpty) ...[
            Text(
              '不足している可能性のある成分：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            ...deficiencies.map((id) {
              String name = id;
              List<String> topFoods = [];

              final fi = db.getFunctionalIngredientById(id);
              if (fi != null) {
                name = fi['name'] as String? ?? id;
                topFoods = List<String>.from(fi['top_foods'] as List? ?? []);
              } else {
                final n = db.getNutrientById(id);
                if (n != null) {
                  name = n['name'] as String? ?? id;
                  topFoods = List<String>.from(n['top_foods'] as List? ?? []);
                }
              }
              final foodStr = topFoods.take(3).join('・');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          if (foodStr.isNotEmpty)
                            TextSpan(
                              text: '（$foodStr）',
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // おすすめ食材
          if (foods.isNotEmpty) ...[
            Text(
              'おすすめ食材：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: foods.map((f) {
                final alreadyEaten = todayFoodNames.any(
                    (d) => d.contains(f.toLowerCase()));
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: alreadyEaten
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                        : cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: alreadyEaten
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                          : cs.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (alreadyEaten)
                        const Text('✓ ',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold)),
                      Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          color: alreadyEaten
                              ? const Color(0xFF4CAF50)
                              : textColor,
                          fontWeight: FontWeight.w500,
                          decoration: alreadyEaten
                              ? TextDecoration.none
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // アドバイス
          if (advice.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      advice,
                      style: TextStyle(fontSize: 12, color: textColor),
                    ),
                  ),
                ],
              ),
            ),

          // 今日すでに食べている場合
          if (remainingFoods.length < foods.length && todayMeals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '✓ 一部の食材は今日すでに摂れています',
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
