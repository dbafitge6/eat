import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/weight_entry.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart' as du;

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<WeightEntry> _entries = [];
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseService.instance.getWeights();
    final profile = await DatabaseService.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _entries = entries.reversed.toList();
      _profile = profile;
      _loading = false;
    });
  }

  double get _latestWeight =>
      _entries.isNotEmpty ? _entries.last.weight : (_profile?.weightKg ?? 60);

  double get _bmi {
    final h = _profile?.heightCm ?? 170;
    return _latestWeight / ((h / 100) * (h / 100));
  }

  String get _bmiLabel {
    if (_bmi < 18.5) return '低体重';
    if (_bmi < 25) return '普通体重';
    if (_bmi < 30) return '肥満(1度)';
    return '肥満(2度以上)';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('体重記録')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWeightDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('体重',
                                  style: TextStyle(color: Colors.grey)),
                              Text('${_latestWeight.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BMI',
                                  style: TextStyle(color: Colors.grey)),
                              Text(_bmi.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              Text(_bmiLabel,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_profile != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('基礎代謝',
                              style: TextStyle(color: Colors.grey)),
                          Text('${_profile!.bmr.round()} kcal/日',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('目標カロリー: ${_profile!.targetKcal.round()} kcal/日',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                if (_entries.length >= 2) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(_entries.length, (i) {
                              return FlSpot(
                                  i.toDouble(), _entries[i].weight);
                            }),
                            isCurved: true,
                            color: primary,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: primary.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ..._entries.reversed.take(30).map((e) => ListTile(
                      title: Text(e.date),
                      trailing: Text('${e.weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    )),
              ],
            ),
    );
  }

  Future<void> _showAddWeightDialog() async {
    double weight = _latestWeight;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('体重を記録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${weight.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              Slider(
                value: weight,
                min: 30,
                max: 200,
                divisions: 340,
                onChanged: (v) => ss(() => weight = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, weight),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final h = _profile?.heightCm ?? 170;
      final bmi = result / ((h / 100) * (h / 100));
      await DatabaseService.instance.upsertWeight(WeightEntry(
        date: du.todayString(),
        weight: result,
        bmi: bmi,
      ));
      await _load();
    }
  }
}
