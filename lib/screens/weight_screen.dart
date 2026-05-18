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
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => _WeightInputDialog(initialWeight: _latestWeight),
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

class _WeightInputDialog extends StatefulWidget {
  final double initialWeight;
  const _WeightInputDialog({required this.initialWeight});

  @override
  State<_WeightInputDialog> createState() => _WeightInputDialogState();
}

class _WeightInputDialogState extends State<_WeightInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialWeight.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('体重を記録'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          suffixText: 'kg',
          suffixStyle: TextStyle(fontSize: 18),
        ),
        onSubmitted: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null && parsed >= 20 && parsed <= 300) {
            Navigator.pop(context, parsed);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            final parsed = double.tryParse(_controller.text);
            if (parsed != null && parsed >= 20 && parsed <= 300) {
              Navigator.pop(context, parsed);
            }
          },
          child: const Text('記録'),
        ),
      ],
    );
  }
}
