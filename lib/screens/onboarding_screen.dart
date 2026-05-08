import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  double _height = 170;
  double _weight = 65;
  int _age = 25;
  int _sex = 0;
  int _activityLevel = 1;
  int _goal = 0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_page + 1) / 4,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(onNext: _next),
                  _BodyPage(
                    height: _height,
                    weight: _weight,
                    age: _age,
                    sex: _sex,
                    onChanged: (h, w, a, s) =>
                        setState(() {
                          _height = h;
                          _weight = w;
                          _age = a;
                          _sex = s;
                        }),
                    onNext: _next,
                  ),
                  _ActivityPage(
                    activityLevel: _activityLevel,
                    onChanged: (v) => setState(() => _activityLevel = v),
                    onNext: _next,
                  ),
                  _GoalPage(
                    goal: _goal,
                    onChanged: (v) => setState(() => _goal = v),
                    onDone: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _finish() async {
    final bmr = _sex == 0
        ? 13.397 * _weight + 4.799 * _height - 5.677 * _age + 88.362
        : 9.247 * _weight + 3.098 * _height - 4.330 * _age + 447.593;
    final targetKcal =
        UserProfile.calcTargetKcal(bmr, _activityLevel, _goal);
    final profile = UserProfile(
      heightCm: _height,
      weightKg: _weight,
      age: _age,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
      targetKcal: targetKcal,
      targetWaterMl: 2000,
    );
    await DatabaseService.instance.saveUserProfile(profile);
    await widget.onComplete();
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('eat.',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )),
          const SizedBox(height: 16),
          const Text('シンプルな食事管理アプリ',
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('文科省の食品データベース搭載。\n見つからない食品はWebで検索できます。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('はじめる'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyPage extends StatefulWidget {
  final double height;
  final double weight;
  final int age;
  final int sex;
  final void Function(double, double, int, int) onChanged;
  final VoidCallback onNext;

  const _BodyPage({
    required this.height,
    required this.weight,
    required this.age,
    required this.sex,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<_BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends State<_BodyPage> {
  late double _h, _w;
  late int _a, _s;

  @override
  void initState() {
    super.initState();
    _h = widget.height;
    _w = widget.weight;
    _a = widget.age;
    _s = widget.sex;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('あなたの情報を入力',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _SliderRow(
            label: '身長',
            value: _h,
            min: 100,
            max: 220,
            unit: 'cm',
            onChanged: (v) {
              setState(() => _h = v);
              widget.onChanged(_h, _w, _a, _s);
            },
          ),
          _SliderRow(
            label: '体重',
            value: _w,
            min: 30,
            max: 200,
            unit: 'kg',
            onChanged: (v) {
              setState(() => _w = v);
              widget.onChanged(_h, _w, _a, _s);
            },
          ),
          _SliderRow(
            label: '年齢',
            value: _a.toDouble(),
            min: 10,
            max: 90,
            unit: '歳',
            divisions: 80,
            onChanged: (v) {
              setState(() => _a = v.round());
              widget.onChanged(_h, _w, _a, _s);
            },
          ),
          const SizedBox(height: 16),
          const Text('性別'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('男性')),
              ButtonSegment(value: 1, label: Text('女性')),
            ],
            selected: {_s},
            onSelectionChanged: (v) {
              setState(() => _s = v.first);
              widget.onChanged(_h, _w, _a, _s);
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onNext,
              child: const Text('次へ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label),
          const Spacer(),
          Text('${value.round()} $unit',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ActivityPage extends StatelessWidget {
  final int activityLevel;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  const _ActivityPage({
    required this.activityLevel,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      ('低い', '主に座り仕事・運動ほぼなし'),
      ('普通', '軽い運動・立ち仕事あり'),
      ('高い', '激しい運動・肉体労働'),
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('活動レベル', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          ...List.generate(3, (i) {
            return Card(
              color: activityLevel == i
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                  : null,
              child: ListTile(
                title: Text(options[i].$1),
                subtitle: Text(options[i].$2),
                trailing: activityLevel == i
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => onChanged(i),
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('次へ')),
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final int goal;
  final ValueChanged<int> onChanged;
  final VoidCallback onDone;

  const _GoalPage({
    required this.goal,
    required this.onChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      ('減量', '体重を減らしたい'),
      ('維持', '今の体重を保ちたい'),
      ('増量', '体重を増やしたい'),
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('目標', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          ...List.generate(3, (i) {
            return Card(
              color: goal == i
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                  : null,
              child: ListTile(
                title: Text(options[i].$1),
                subtitle: Text(options[i].$2),
                trailing: goal == i
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => onChanged(i),
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onDone, child: const Text('はじめる')),
          ),
        ],
      ),
    );
  }
}
