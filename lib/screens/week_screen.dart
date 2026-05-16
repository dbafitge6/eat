import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/meal_entry.dart';
import '../models/weight_entry.dart';
import '../services/database_service.dart';
import '../services/share_service.dart';
import '../models/user_profile.dart';
import '../utils/date_utils.dart' as du;

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  DateTime _anchor = DateTime.now();
  List<MealEntry> _meals = [];
  List<WeightEntry> _weights = [];
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dates = du.weekDates(_anchor);
    final meals = await DatabaseService.instance.getMealsForWeek(dates.first, dates.last);
    final weights = await DatabaseService.instance.getWeights(limit: 30);
    final profile = await DatabaseService.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _weights = weights;
      _profile = profile;
      _loading = false;
    });
  }

  Map<String, double> get _dailyKcal {
    final dates = du.weekDates(_anchor);
    final map = {for (final d in dates) d: 0.0};
    for (final m in _meals) {
      if (map.containsKey(m.date)) map[m.date] = map[m.date]! + m.kcal;
    }
    return map;
  }

  double get _weeklyTotal => _meals.fold(0, (s, m) => s + m.kcal);
  double get _weeklyTarget => (_profile?.targetKcal ?? 2000) * 7;

  double get _avgDailyKcal {
    final recorded = _dailyKcal.values.where((v) => v > 0).toList();
    if (recorded.isEmpty) return 0;
    return recorded.fold(0.0, (s, v) => s + v) / recorded.length;
  }

  double get _avgProtein => _meals.isEmpty ? 0 : _meals.fold(0.0, (s, m) => s + m.protein) / _recordedDays;
  double get _avgFat => _meals.isEmpty ? 0 : _meals.fold(0.0, (s, m) => s + m.fat) / _recordedDays;
  double get _avgCarb => _meals.isEmpty ? 0 : _meals.fold(0.0, (s, m) => s + m.carb) / _recordedDays;
  int get _recordedDays => _dailyKcal.values.where((v) => v > 0).length.clamp(1, 7);

  // 1kg ≈ 7700 kcal
  String get _prediction {
    final target = _profile?.targetKcal ?? 2000;
    final goal = _profile?.goal ?? 1;
    if (goal == 1) return '維持目標中';
    if (_avgDailyKcal < 1) return 'データ不足';

    final dailyDiff = target - _avgDailyKcal; // 正=赤字(減量)、負=黒字(増量)
    if (dailyDiff.abs() < 50) return 'ほぼ目標通り';

    final weeksFor1kg = 7700 / (dailyDiff.abs() * 7);
    if (goal == 0) {
      // ダイエット
      if (dailyDiff > 0) {
        return '${weeksFor1kg.toStringAsFixed(1)}週間で約1kg減量ペース';
      } else {
        return '目標より${(-dailyDiff).round()}kcal/日オーバー';
      }
    } else {
      // 増量
      if (dailyDiff < 0) {
        return '${weeksFor1kg.toStringAsFixed(1)}週間で約1kg増量ペース';
      } else {
        return '目標より${dailyDiff.round()}kcal/日不足';
      }
    }
  }

  Future<void> _shareWeek() async {
    await ShareService.shareWeekSummary(
      weeklyKcal: _weeklyTotal,
      weeklyTarget: _weeklyTarget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final dailyKcal = _dailyKcal;
    final dates = du.weekDates(_anchor);
    final remaining = _weeklyTarget - _weeklyTotal;
    final dayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('週間サマリー'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            _anchor = _anchor.subtract(const Duration(days: 7));
            _load();
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareWeek),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              _anchor = _anchor.add(const Duration(days: 7));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(du.weekRangeLabel(_anchor),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),

                // ─ 週間合計カード ─
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今週の合計', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${_weeklyTotal.round()}',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('kcal', style: TextStyle(color: Colors.grey)),
                            ),
                            const Spacer(),
                            Text(
                              remaining >= 0
                                  ? '残り ${remaining.round()} kcal'
                                  : '${(-remaining).round()} kcal オーバー',
                              style: TextStyle(
                                  color: remaining < 0 ? Colors.red : Colors.grey,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_weeklyTotal / _weeklyTarget).clamp(0, 1),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          valueColor: AlwaysStoppedAnimation(
                              _weeklyTotal > _weeklyTarget ? Colors.red : primary),
                          backgroundColor: Colors.white12,
                        ),
                        const SizedBox(height: 12),
                        // 平均 & 予測
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                label: '平均/日',
                                value: '${_avgDailyKcal.round()} kcal',
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: '記録日数',
                                value: '$_recordedDays / 7日',
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                        if (_prediction.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.trending_down, size: 16, color: primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _prediction,
                                    style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─ 棒グラフ ─
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('カロリー推移', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (_profile?.targetKcal ?? 2000) * 1.3,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                                    '${rod.toY.round()} kcal',
                                    const TextStyle(fontSize: 11, color: Colors.white),
                                  ),
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= 7) return const SizedBox();
                                      final isToday = dates[i] == du.todayString();
                                      return Text(dayLabels[i],
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                              color: isToday ? primary : null));
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(7, (i) {
                                final kcal = dailyKcal[dates[i]] ?? 0;
                                final target = _profile?.targetKcal ?? 2000;
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: kcal,
                                      color: kcal > target ? Colors.red : primary,
                                      width: 18,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }),
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: _profile?.targetKcal ?? 2000,
                                    color: Colors.red.withValues(alpha: 0.4),
                                    strokeWidth: 1,
                                    dashArray: [5, 5],
                                    label: HorizontalLineLabel(
                                      show: true,
                                      alignment: Alignment.topRight,
                                      labelResolver: (_) => '目標',
                                      style: const TextStyle(fontSize: 10, color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─ PFCサマリー ─
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1日平均 PFC', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _PFCStat('P たんぱく質', _avgProtein, primary)),
                            Expanded(child: _PFCStat('F 脂質', _avgFat, Color.lerp(primary, secondary, 0.5)!)),
                            Expanded(child: _PFCStat('C 炭水化物', _avgCarb, secondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─ 体重推移 ─
                if (_weights.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _WeightTrendChart(weights: _weights, primary: primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─ 日別リスト ─
                Card(
                  child: Column(
                    children: List.generate(7, (i) {
                      final date = dates[i];
                      final kcal = dailyKcal[date] ?? 0;
                      final target = _profile?.targetKcal ?? 2000;
                      final isToday = date == du.todayString();
                      final diff = kcal - target;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: kcal == 0
                              ? Colors.grey.withValues(alpha: 0.15)
                              : kcal > target
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : primary.withValues(alpha: 0.15),
                          child: Text(dayLabels[i],
                              style: TextStyle(
                                  fontSize: 13,
                                  color: kcal == 0
                                      ? Colors.grey
                                      : kcal > target ? Colors.red : primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          date.substring(5).replaceAll('-', '/') + (isToday ? ' (今日)' : ''),
                          style: TextStyle(
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14),
                        ),
                        trailing: kcal == 0
                            ? const Text('未記録', style: TextStyle(color: Colors.grey, fontSize: 12))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${kcal.round()} kcal',
                                      style: TextStyle(
                                          color: kcal > target ? Colors.red : null,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Text(
                                    diff >= 0 ? '+${diff.round()}' : '${diff.round()}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: diff > 0 ? Colors.red : Colors.green),
                                  ),
                                ],
                              ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _PFCStat extends StatelessWidget {
  final String label;
  final double grams;
  final Color color;

  const _PFCStat(this.label, this.grams, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${grams.round()}g',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }
}

class _WeightTrendChart extends StatelessWidget {
  final List<WeightEntry> weights;
  final Color primary;

  const _WeightTrendChart({required this.weights, required this.primary});

  @override
  Widget build(BuildContext context) {
    final recent = weights.take(14).toList().reversed.toList();
    if (recent.isEmpty) return const SizedBox();

    final minW = recent.map((w) => w.weight).reduce((a, b) => a < b ? a : b);
    final maxW = recent.map((w) => w.weight).reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('体重推移 (直近14日)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              minY: minW - range * 0.2,
              maxY: maxW + range * 0.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: recent.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.weight)).toList(),
                  isCurved: true,
                  color: primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: primary,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: primary.withValues(alpha: 0.08),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final w = recent[s.x.toInt()];
                    return LineTooltipItem(
                      '${w.weight}kg\n${w.date.substring(5).replaceAll('-', '/')}',
                      const TextStyle(fontSize: 11, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        if (recent.length >= 2) ...[
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final diff = recent.last.weight - recent.first.weight;
            final sign = diff >= 0 ? '+' : '';
            return Text(
              '期間変化: $sign${diff.toStringAsFixed(1)}kg',
              style: TextStyle(
                fontSize: 12,
                color: diff < 0 ? Colors.green : diff > 0 ? Colors.red : Colors.grey,
              ),
            );
          }),
        ],
      ],
    );
  }
}
