import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/meal_entry.dart';
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
    final meals = await DatabaseService.instance
        .getMealsForWeek(dates.first, dates.last);
    final profile = await DatabaseService.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _meals = meals;
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

  Future<void> _shareWeek() async {
    await ShareService.shareWeekSummary(
      weeklyKcal: _weeklyTotal,
      weeklyTarget: _weeklyTarget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dailyKcal = _dailyKcal;
    final dates = du.weekDates(_anchor);
    final remaining = _weeklyTarget - _weeklyTotal;
    final dayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('週間カロリー'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            _anchor = _anchor.subtract(const Duration(days: 7));
            _load();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareWeek,
          ),
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
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今週の合計',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${_weeklyTotal.round()} kcal',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            remaining >= 0
                                ? '残り ${remaining.round()} kcal'
                                : '${(-remaining).round()} kcal オーバー',
                            style: TextStyle(
                                color:
                                    remaining < 0 ? Colors.red : Colors.grey)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_weeklyTotal / _weeklyTarget).clamp(0, 1),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                          valueColor: AlwaysStoppedAnimation(
                              _weeklyTotal > _weeklyTarget
                                  ? Colors.red
                                  : primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (_profile?.targetKcal ?? 2000) * 1.3,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= 7) return const SizedBox();
                              return Text(dayLabels[i],
                                  style: const TextStyle(fontSize: 12));
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
                              width: 20,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: _profile?.targetKcal ?? 2000,
                            color: Colors.red.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(7, (i) {
                  final date = dates[i];
                  final kcal = dailyKcal[date] ?? 0;
                  final target = _profile?.targetKcal ?? 2000;
                  final isToday = date == du.todayString();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          kcal > target ? Colors.red.withOpacity(0.2) : primary.withOpacity(0.1),
                      child: Text(dayLabels[i],
                          style: TextStyle(
                              color: kcal > target ? Colors.red : primary,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                        date.substring(5).replaceAll('-', '/') +
                            (isToday ? ' (今日)' : ''),
                        style: TextStyle(
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    trailing: Text('${kcal.round()} kcal',
                        style: TextStyle(
                            color: kcal > target ? Colors.red : null,
                            fontWeight: FontWeight.bold)),
                  );
                }),
              ],
            ),
    );
  }
}
