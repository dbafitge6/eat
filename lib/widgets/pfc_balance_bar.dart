import 'package:flutter/material.dart';
import '../utils/pfc_score.dart';
import '../services/diet_type_service.dart';

class PFCBalanceBar extends StatelessWidget {
  final double protein;
  final double fat;
  final double carb;

  const PFCBalanceBar({
    super.key,
    required this.protein,
    required this.fat,
    required this.carb,
  });

  @override
  Widget build(BuildContext context) {
    final diet = DietTypeService.instance.current;
    final score = PFCScore.calculate(protein, fat, carb, diet);
    final color = PFCScore.color(score);
    final label = PFCScore.label(score);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
