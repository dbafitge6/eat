import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/nutrition_db_service.dart';

class MissingNutrientsWidget extends StatelessWidget {
  final List<String> todayFoodNames;

  const MissingNutrientsWidget({super.key, required this.todayFoodNames});

  @override
  Widget build(BuildContext context) {
    final db = NutritionDbService.instance;
    final analysis = db.analyzefoods(todayFoodNames);
    final coveredIngredients = analysis.ingredientIds;
    final coveredNutrients = analysis.nutrientIds;

    final allIngredients = db.functionalIngredients.values.toList();
    final allNutrients = db.nutrients.values.toList();

    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_outlined, color: primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '今日の摂取成分',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '食事内容から推定 ※参考値です',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(
                children: [
                  _LegendDot(color: Colors.greenAccent, label: '摂取済み'),
                  const SizedBox(width: 12),
                  _LegendDot(color: Colors.orangeAccent, label: '今日不足'),
                ],
              ),
              const SizedBox(height: 10),
              // Functional ingredients section
              if (allIngredients.isNotEmpty) ...[
                Text(
                  '機能性成分',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allIngredients.map((ing) {
                    final covered = coveredIngredients.contains(ing.id);
                    return _NutrientChip(
                      label: '${ing.emoji} ${ing.name}',
                      covered: covered,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
              // Nutrients section
              if (allNutrients.isNotEmpty) ...[
                Text(
                  'ビタミン・ミネラル',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allNutrients.map((nut) {
                    final covered = coveredNutrients.contains(nut.id);
                    return _NutrientChip(
                      label: '${nut.emoji} ${nut.name}',
                      covered: covered,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final bool covered;

  const _NutrientChip({required this.label, required this.covered});

  @override
  Widget build(BuildContext context) {
    final color = covered ? Colors.greenAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}
