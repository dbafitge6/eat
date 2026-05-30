import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meal_entry.dart';

class NutrientScreen extends StatefulWidget {
  final List<MealEntry> meals;
  const NutrientScreen({super.key, required this.meals});

  @override
  State<NutrientScreen> createState() => _NutrientScreenState();
}

class _NutrientScreenState extends State<NutrientScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  double _sum(double Function(MealEntry) f) =>
      widget.meals.fold(0, (s, m) => s + f(m));

  @override
  Widget build(BuildContext context) {
    final protein = _sum((m) => m.protein);
    final fat = _sum((m) => m.fat);
    final carb = _sum((m) => m.carb);
    final fiber = _sum((m) => m.fiber);
    final sodium = _sum((m) => m.sodium);
    final calcium = _sum((m) => m.calcium);
    final iron = _sum((m) => m.iron);
    final kcal = _sum((m) => m.kcal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('栄養素詳細'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '3大栄養素'),
            Tab(text: '5大栄養素'),
            Tab(text: '詳細'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _Tab3(protein: protein, fat: fat, carb: carb, kcal: kcal),
          _Tab5(
              protein: protein,
              fat: fat,
              carb: carb,
              fiber: fiber,
              sodium: sodium),
          _TabDetail(
              protein: protein,
              fat: fat,
              carb: carb,
              fiber: fiber,
              sodium: sodium,
              calcium: calcium,
              iron: iron,
              kcal: kcal),
        ],
      ),
    );
  }
}

class _NutrientBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color color;

  const _NutrientBar({
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                  '${value.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max > 0 ? (value / max).clamp(0, 1) : 0,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            valueColor: AlwaysStoppedAnimation(color),
            backgroundColor: color.withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}

class _Tab3 extends StatelessWidget {
  final double protein, fat, carb, kcal;
  const _Tab3(
      {required this.protein,
      required this.fat,
      required this.carb,
      required this.kcal});

  @override
  Widget build(BuildContext context) {
    final total = protein * 4 + fat * 9 + carb * 4;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('合計 ${kcal.round()} kcal',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _NutrientBar(
            label: 'たんぱく質',
            value: protein,
            max: 65,
            unit: 'g',
            color: Colors.blue),
        _NutrientBar(
            label: '脂質', value: fat, max: 60, unit: 'g', color: Colors.orange),
        _NutrientBar(
            label: '炭水化物',
            value: carb,
            max: 320,
            unit: 'g',
            color: Colors.green),
        const SizedBox(height: 16),
        if (total > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PieSlice('P', protein * 4 / total, Colors.blue),
              _PieSlice('F', fat * 9 / total, Colors.orange),
              _PieSlice('C', carb * 4 / total, Colors.green),
            ],
          ),
      ],
    );
  }
}

class _PieSlice extends StatelessWidget {
  final String label;
  final double ratio;
  final Color color;
  const _PieSlice(this.label, this.ratio, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration:
              BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(ratio * 100).round()}%'),
      ],
    );
  }
}

class _Tab5 extends StatelessWidget {
  final double protein, fat, carb, fiber, sodium;
  const _Tab5(
      {required this.protein,
      required this.fat,
      required this.carb,
      required this.fiber,
      required this.sodium});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NutrientBar(
            label: 'たんぱく質',
            value: protein,
            max: 65,
            unit: 'g',
            color: Colors.blue),
        _NutrientBar(
            label: '脂質', value: fat, max: 60, unit: 'g', color: Colors.orange),
        _NutrientBar(
            label: '炭水化物',
            value: carb,
            max: 320,
            unit: 'g',
            color: Colors.green),
        _NutrientBar(
            label: '食物繊維',
            value: fiber,
            max: 21,
            unit: 'g',
            color: Colors.brown),
        _NutrientBar(
            label: 'ナトリウム',
            value: sodium / 1000,
            max: 6,
            unit: 'g',
            color: Colors.purple),
      ],
    );
  }
}

class _TabDetail extends StatelessWidget {
  final double protein, fat, carb, fiber, sodium, calcium, iron, kcal;
  const _TabDetail(
      {required this.protein,
      required this.fat,
      required this.carb,
      required this.fiber,
      required this.sodium,
      required this.calcium,
      required this.iron,
      required this.kcal});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Row('エネルギー', '${kcal.round()} kcal'),
        _Row('たんぱく質', '${protein.toStringAsFixed(1)} g'),
        _Row('脂質', '${fat.toStringAsFixed(1)} g'),
        _Row('炭水化物', '${carb.toStringAsFixed(1)} g'),
        _Row('食物繊維', '${fiber.toStringAsFixed(1)} g'),
        _Row('ナトリウム', '${sodium.round()} mg'),
        _Row('カルシウム', '${calcium.round()} mg'),
        _Row('鉄', '${iron.toStringAsFixed(1)} mg'),
        const SizedBox(height: 16),
        const Text(
          '※ データベースに登録されている食品のみ集計されます',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('参考文献', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/eiyou/syokuji_kijyun.html');
            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: const Text(
            '・厚生労働省「日本人の食事摂取基準」',
            style: TextStyle(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://fooddb.mext.go.jp/');
            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: const Text(
            '・文部科学省 食品成分データベース',
            style: TextStyle(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
