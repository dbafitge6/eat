import 'package:flutter/material.dart';
import '../services/body_status_service.dart';
import '../services/nutrition_db_service.dart';
import '../models/meal_entry.dart';

class BodyStatusWidget extends StatefulWidget {
  final List<MealEntry> meals;

  const BodyStatusWidget({super.key, required this.meals});

  @override
  State<BodyStatusWidget> createState() => _BodyStatusWidgetState();
}

class _BodyStatusWidgetState extends State<BodyStatusWidget> {
  List<BodyPartScore> _scores = [];
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant BodyStatusWidget old) {
    super.didUpdateWidget(old);
    _compute();
  }

  void _compute() {
    final scores = BodyStatusService.instance.calculateScores(widget.meals);
    if (mounted) setState(() => _scores = scores);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_scores.isEmpty) return const SizedBox.shrink();

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
          Row(
            children: [
              Text(
                '今日の体のコンディション',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1a1a1a),
                ),
              ),
              const Spacer(),
              Text(
                widget.meals.isEmpty ? '食事を記録すると表示されます' : '',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_scores.map((score) => _BodyPartRow(
                score: score,
                isExpanded: _expandedId == score.id,
                primary: cs.primary,
                onTap: () => setState(() {
                  _expandedId = _expandedId == score.id ? null : score.id;
                }),
              ))),
        ],
      ),
    );
  }
}

class _BodyPartRow extends StatelessWidget {
  final BodyPartScore score;
  final bool isExpanded;
  final Color primary;
  final VoidCallback onTap;

  const _BodyPartRow({
    required this.score,
    required this.isExpanded,
    required this.primary,
    required this.onTap,
  });

  Color _barColor(double s) {
    if (s >= 0.7) return const Color(0xFF4CAF50);
    if (s >= 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    final barColor = _barColor(score.score);
    final percent = (score.score * 100).round();
    final isLow = score.score < 0.4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(score.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 44,
                  child: Text(
                    score.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score.score.clamp(0.0, 1.0),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(barColor),
                      minHeight: 7,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
                if (isLow) ...[
                  const SizedBox(width: 4),
                  const Text('⚠️', style: TextStyle(fontSize: 12)),
                ],
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: subColor,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _ExpandedDetail(score: score, subColor: subColor),
      ],
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  final BodyPartScore score;
  final Color subColor;

  const _ExpandedDetail({required this.score, required this.subColor});

  @override
  Widget build(BuildContext context) {
    final db = NutritionDbService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    final message = BodyStatusService.instance.getStatusMessage(score);

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF444444),
                ),
              ),
            ),
          if (score.missingNutrientIds.isNotEmpty) ...[
            Text(
              '不足している可能性のある成分：',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
            const SizedBox(height: 4),
            ...score.missingNutrientIds.take(4).map((id) {
              String name = id;
              List<String> topFoods = [];
              String? synergy;

              final fi = db.getFunctionalIngredientById(id);
              if (fi != null) {
                name = fi['name'] as String? ?? id;
                topFoods = List<String>.from(fi['top_foods'] as List? ?? []);
                final combos = fi['best_combinations'] as List?;
                if (combos != null && combos.isNotEmpty) {
                  final c = combos.first as Map;
                  synergy = '💡 ${c['partner']}と一緒に摂ると${c['effect']}';
                }
              } else {
                final n = db.getNutrientById(id);
                if (n != null) {
                  name = n['name'] as String? ?? id;
                  topFoods = List<String>.from(n['top_foods'] as List? ?? []);
                }
              }

              final foodStr = topFoods.take(3).join('・');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (foodStr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          '→ $foodStr',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ),
                    if (synergy != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text(
                          synergy,
                          style: TextStyle(
                            fontSize: 10,
                            color: subColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          if (score.obtainedNutrientIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '✓ 摂れているもの：',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
              ),
            ),
            Text(
              score.obtainedNutrientIds.take(4).map((id) {
                final fi = db.getFunctionalIngredientById(id);
                if (fi != null) return fi['name'] as String? ?? id;
                final n = db.getNutrientById(id);
                return n?['name'] as String? ?? id;
              }).join('・'),
              style: TextStyle(fontSize: 11, color: subColor),
            ),
          ],
        ],
      ),
    );
  }
}
