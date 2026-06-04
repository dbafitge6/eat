import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/nutrition_db_service.dart';

class SymptomScreen extends StatefulWidget {
  final List<String> todayFoodNames;

  const SymptomScreen({super.key, required this.todayFoodNames});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  SymptomInfo? _selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final secondary = cs.secondary;
    final db = NutritionDbService.instance;
    final symptoms = db.allSymptoms;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: [primary, secondary]).createShader(bounds),
          child: const Text(
            '不調から食材を探す',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          const Text(
            '今感じている不調を選んでください',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          const Text(
            '※医療的なアドバイスではありません。参考情報としてご利用ください。',
            style: TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          // Symptom buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: symptoms.map((s) {
              final isSelected = _selected?.id == s.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selected = isSelected ? null : s;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [primary, secondary])
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Detail panel
          if (_selected != null) ...[
            const SizedBox(height: 20),
            _SymptomDetailCard(
              symptom: _selected!,
              todayFoodNames: widget.todayFoodNames,
              primary: primary,
              secondary: secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _SymptomDetailCard extends StatelessWidget {
  final SymptomInfo symptom;
  final List<String> todayFoodNames;
  final Color primary;
  final Color secondary;

  const _SymptomDetailCard({
    required this.symptom,
    required this.todayFoodNames,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final db = NutritionDbService.instance;
    final analysis = db.analyzefoods(todayFoodNames);
    final coveredIngredients = analysis.ingredientIds;

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
              // Header
              Row(
                children: [
                  Text(symptom.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    symptom.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Message
              Text(
                symptom.message,
                style: const TextStyle(
                    fontSize: 13, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 14),

              // Related ingredients
              if (symptom.relatedIngredients.isNotEmpty) ...[
                Text(
                  'サポートが期待できる成分',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...symptom.relatedIngredients.map((id) {
                  final ing = db.getIngredient(id);
                  if (ing == null) return const SizedBox.shrink();
                  final alreadyCovered = coveredIngredients.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ing.emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    ing.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: alreadyCovered
                                          ? Colors.greenAccent
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (alreadyCovered)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        '今日摂取済み',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ing.effect,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                    height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
              ],

              // Recommended foods
              if (symptom.foods.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 16),
                Text(
                  'おすすめ食材',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: symptom.foods.map((food) {
                    // Check if today's meals include this food
                    final eaten = todayFoodNames.any((name) =>
                        name.contains(food) || food.contains(name));
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: eaten
                            ? Colors.greenAccent.withValues(alpha: 0.15)
                            : primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: eaten
                              ? Colors.greenAccent.withValues(alpha: 0.5)
                              : primary.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (eaten) ...[
                            const Icon(Icons.check,
                                size: 11, color: Colors.greenAccent),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            food,
                            style: TextStyle(
                              fontSize: 12,
                              color: eaten ? Colors.greenAccent : Colors.white,
                            ),
                          ),
                        ],
                      ),
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
