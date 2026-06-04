import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/body_status_service.dart';
import '../services/nutrition_db_service.dart';

class BodyStatusWidget extends StatefulWidget {
  final List<String> foodNames;

  const BodyStatusWidget({super.key, required this.foodNames});

  @override
  State<BodyStatusWidget> createState() => _BodyStatusWidgetState();
}

class _BodyStatusWidgetState extends State<BodyStatusWidget> {
  late List<BodyPartScore> _scores;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _scores = BodyStatusService.instance.calculate(widget.foodNames);
  }

  @override
  void didUpdateWidget(BodyStatusWidget old) {
    super.didUpdateWidget(old);
    if (old.foodNames != widget.foodNames) {
      setState(() {
        _scores = BodyStatusService.instance.calculate(widget.foodNames);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final secondary = cs.secondary;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                '今日の体のコンディション',
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
            '今日の食事から推定 ※個人差があります',
            style: TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          ..._scores.map((score) => _BodyPartRow(
                score: score,
                primary: primary,
                secondary: secondary,
                isExpanded: _expanded.contains(score.partId),
                onTap: () {
                  setState(() {
                    if (_expanded.contains(score.partId)) {
                      _expanded.remove(score.partId);
                    } else {
                      _expanded.add(score.partId);
                    }
                  });
                },
              )),
        ],
      ),
    );
  }
}

class _BodyPartRow extends StatelessWidget {
  final BodyPartScore score;
  final Color primary;
  final Color secondary;
  final bool isExpanded;
  final VoidCallback onTap;

  const _BodyPartRow({
    required this.score,
    required this.primary,
    required this.secondary,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = NutritionDbService.instance;
    final part = db.getBodyPart(score.partId);
    if (part == null) return const SizedBox.shrink();

    final pct = (score.score * 100).round();
    final isLow = score.score < 0.4;
    final isMid = score.score >= 0.4 && score.score < 0.7;

    Color barColor;
    if (isLow) {
      barColor = Colors.orangeAccent;
    } else if (isMid) {
      barColor = Color.lerp(primary, secondary, 0.5)!;
    } else {
      barColor = primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(part.emoji,
                      style: const TextStyle(fontSize: 16)),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    part.name,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score.score,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 12,
                      color: barColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                if (isLow)
                  const Text('⚠️', style: TextStyle(fontSize: 12))
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),
            // Expanded detail
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.score >= 0.7
                          ? part.sufficientMessage
                          : part.deficiencyMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: score.score >= 0.7
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        height: 1.4,
                      ),
                    ),
                    if (score.missingIngredientIds.isNotEmpty ||
                        score.missingNutrientIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '不足気味の成分:',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...score.missingIngredientIds.map((id) {
                            final ing = NutritionDbService.instance
                                .getIngredient(id);
                            if (ing == null) return const SizedBox.shrink();
                            return _Chip(
                                label: '${ing.emoji} ${ing.name}',
                                color: Colors.orangeAccent);
                          }),
                          ...score.missingNutrientIds.map((id) {
                            final nut =
                                NutritionDbService.instance.getNutrient(id);
                            if (nut == null) return const SizedBox.shrink();
                            return _Chip(
                                label: '${nut.emoji} ${nut.name}',
                                color: Colors.blueAccent);
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ',
                            style: TextStyle(fontSize: 11)),
                        Expanded(
                          child: Text(
                            part.tip,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
