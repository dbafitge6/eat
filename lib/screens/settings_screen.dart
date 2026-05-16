import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../themes/app_theme.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/diet_type_service.dart';
import '../services/purchase_service.dart';
import '../utils/pfc_score.dart';
import '../models/user_profile.dart';
import 'premium_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SupplementReminder {
  final String name;
  final int hour;
  final int minute;
  _SupplementReminder({required this.name, required this.hour, required this.minute});
  Map<String, dynamic> toJson() => {'name': name, 'hour': hour, 'minute': minute};
  factory _SupplementReminder.fromJson(Map<String, dynamic> j) =>
      _SupplementReminder(name: j['name'], hour: j['hour'], minute: j['minute']);
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _profile;
  bool _notificationsEnabled = false;
  int _waterIntervalMinutes = 10;
  bool _loading = true;
  List<_SupplementReminder> _supplements = [];
  static const _suppKey = 'supplement_reminders';
  static const _waterIntervalKey = 'water_reminder_interval';
  static const _maxFreeSupp = 2;
  int get _maxSupp => PurchaseService.instance.isPremium ? 999 : _maxFreeSupp;
  DietType _dietType = DietTypeService.instance.current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  static String _intervalLabel(int minutes) {
    if (minutes < 60) return '$minutes分';
    if (minutes == 60) return '1時間';
    return '${minutes ~/ 60}時間';
  }

  Future<void> _showDietSelection() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DietSelectionSheet(
        current: _dietType,
        onSelected: (type) async {
          await DietTypeService.instance.save(type);
          if (mounted) setState(() => _dietType = type);
        },
      ),
    );
  }

  Future<void> _load() async {
    final profile = await DatabaseService.instance.getUserProfile();
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = prefs.getBool('water_notification') ?? false;
    final suppJson = prefs.getStringList(_suppKey) ?? [];
    final supps = suppJson.map((s) {
      try { return _SupplementReminder.fromJson(jsonDecode(s) as Map<String, dynamic>); }
      catch (_) { return null; }
    }).whereType<_SupplementReminder>().toList();
    final waterInterval = prefs.getInt(_waterIntervalKey) ?? 60;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _notificationsEnabled = notifEnabled;
      _waterIntervalMinutes = waterInterval;
      _supplements = supps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = EatApp.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Premium banner
                if (!PurchaseService.instance.isPremium)
                  ListTile(
                    leading: const Icon(Icons.star_rounded, color: Colors.amber),
                    title: const Text('eat. プレミアム',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('¥500/月 · 全機能解放'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen())),
                  ),
                if (!PurchaseService.instance.isPremium) const Divider(),
                ExpansionTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Builder(builder: (ctx) {
                    final current = appState?.currentTheme ?? AppThemeType.purpleViolet;
                    return Text('テーマ  ${AppThemes.themeNames[current.index]}');
                  }),
                  children: [
                    // フリー: ライト・ダークのみ
                    ...const [AppThemeType.lightMode, AppThemeType.darkMode]
                        .map((t) {
                      final current =
                          appState?.currentTheme ?? AppThemeType.purpleViolet;
                      final isSelected = current == t;
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppThemes.accentGradient(t),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                        title: Text(AppThemes.themeNames[t.index]),
                        subtitle: Text(AppThemes.themeKeywords[t.index],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.white)
                            : null,
                        onTap: () {
                          appState?.setTheme(t);
                          setState(() {});
                        },
                      );
                    }),
                    // プレミアム: カラーテーマ（ロック表示 or 選択可能）
                    ...AppThemeType.values
                        .where((t) =>
                            t != AppThemeType.lightMode &&
                            t != AppThemeType.darkMode)
                        .map((t) {
                      final isPremium = PurchaseService.instance.isPremium;
                      final current =
                          appState?.currentTheme ?? AppThemeType.purpleViolet;
                      final isSelected = current == t;
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppThemes.accentGradient(t),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                        title: Text(AppThemes.themeNames[t.index],
                            style: TextStyle(
                                color: isPremium ? null : Colors.grey)),
                        subtitle: Text(AppThemes.themeKeywords[t.index],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        trailing: isPremium
                            ? (isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.white)
                                : null)
                            : const Icon(Icons.lock_outline,
                                size: 16, color: Colors.grey),
                        onTap: isPremium
                            ? () {
                                appState?.setTheme(t);
                                setState(() {});
                              }
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PremiumScreen())),
                      );
                    }),
                  ],
                ),
                const Divider(),
                const _SectionHeader('ダイエット方法'),
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: const Text('ダイエット方法'),
                  subtitle: Text(
                    _dietType == DietType.keto ? 'ケトジェニック' : 'カロリー制限',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: _showDietSelection,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '選んだダイエット方法に合わせてPFCバランスバーの色が変わります。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const Divider(),
                const _SectionHeader('水分リマインダー'),
                SwitchListTile(
                  title: const Text('水分補給リマインダー'),
                  subtitle: Text(_notificationsEnabled
                      ? '${_intervalLabel(_waterIntervalMinutes)}おきに通知'
                      : '通知をオンにすると設定できます'),
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('water_notification', v);
                    if (v) {
                      await NotificationService.instance.scheduleWaterReminders(
                          intervalMinutes: _waterIntervalMinutes);
                    } else {
                      await NotificationService.instance.cancelWaterReminders();
                    }
                  },
                ),
                if (_notificationsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('通知間隔',
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [5, 10, 15, 30, 60, 120].map((min) {
                            final selected = _waterIntervalMinutes == min;
                            return ChoiceChip(
                              label: Text(_intervalLabel(min)),
                              selected: selected,
                              onSelected: (_) async {
                                setState(
                                    () => _waterIntervalMinutes = min);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setInt(
                                    _waterIntervalKey, min);
                                await NotificationService.instance
                                    .scheduleWaterReminders(
                                        intervalMinutes: min);
                              },
                            );
                          }).toList(),
                        ),
                        if (_waterIntervalMinutes < 15)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '※ 5〜10分おきはiOSの制限により8時〜13時ごろのみカバーされます',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[300]),
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                const _SectionHeader('サプリリマインダー'),
                ..._supplements.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final timeStr =
                      '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
                  return ListTile(
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(s.name),
                    subtitle: Text('毎日 $timeStr に通知'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteSupplement(i),
                    ),
                  );
                }),
                if (_supplements.length < _maxSupp)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('サプリを追加'),
                    subtitle: PurchaseService.instance.isPremium
                        ? null
                        : Text('あと ${_maxSupp - _supplements.length} 件追加できます'),
                    onTap: _addSupplement,
                  )
                else if (!PurchaseService.instance.isPremium)
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('サプリ通知を追加'),
                    subtitle: const Text('無料プランでは最大2件まで'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen())),
                  ),
                const Divider(),
                const _SectionHeader('データ'),
                ListTile(
                  leading: Icon(Icons.download,
                      color: PurchaseService.instance.isPremium
                          ? null
                          : Colors.grey),
                  title: const Text('CSVエクスポート'),
                  subtitle: Text(PurchaseService.instance.isPremium
                      ? '食事記録をCSVでエクスポート'
                      : 'プレミアム機能'),
                  trailing: PurchaseService.instance.isPremium
                      ? null
                      : const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                  onTap: PurchaseService.instance.isPremium
                      ? _exportCsv
                      : () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PremiumScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('古いデータを削除'),
                  subtitle: const Text('3ヶ月以上前のデータを削除'),
                  onTap: _deleteOldData,
                ),
                const Divider(),
                const _SectionHeader('プロフィール'),
                if (_profile != null) ...[
                  ListTile(
                    title: const Text('身長'),
                    trailing: Text('${_profile!.heightCm.round()} cm'),
                    onTap: _editHeight,
                  ),
                  ListTile(
                    title: const Text('体重'),
                    trailing: Text('${_profile!.weightKg.toStringAsFixed(1)} kg'),
                  ),
                  ListTile(
                    title: const Text('年齢'),
                    trailing: Text('${_profile!.age} 歳'),
                    onTap: _editAge,
                  ),
                  // 性別
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('性別'),
                        const SizedBox(width: 16),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('男性')),
                            ButtonSegment(value: 1, label: Text('女性')),
                          ],
                          selected: {_profile!.sex},
                          onSelectionChanged: (s) => _updateGoalFields(sex: s.first),
                        ),
                      ],
                    ),
                  ),
                  // 活動レベル
                  ListTile(
                    title: const Text('活動レベル'),
                    subtitle: Text(
                      UserProfile.activityLabels[_profile!.activityLevel.clamp(0, 4)],
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _ActivitySelectionSheet(
                          current: _profile!.activityLevel,
                          bmr: _profile!.bmr,
                          goal: _profile!.goal,
                          onSelected: (level) => _updateGoalFields(activityLevel: level),
                        ),
                      );
                    },
                  ),
                  // 目標
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('目標', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('ダイエット')),
                            ButtonSegment(value: 1, label: Text('維持')),
                            ButtonSegment(value: 2, label: Text('増量')),
                          ],
                          selected: {_profile!.goal},
                          onSelectionChanged: (s) => _updateGoalFields(goal: s.first),
                        ),
                      ],
                    ),
                  ),
                  // ダイエット強度（目標=減量のときのみ表示）
                  if (_profile!.goal == 0) ...[
                    ListTile(
                      leading: const Icon(Icons.speed_outlined),
                      title: const Text('ダイエット強度'),
                      subtitle: Text(
                        UserProfile.intensityLabels[_profile!.dietIntensity.clamp(0, 3)],
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _IntensitySelectionSheet(
                            current: _profile!.dietIntensity,
                            tdee: _profile!.bmr * UserProfile.activityFactors[_profile!.activityLevel.clamp(0, 4)],
                            bmr: _profile!.bmr,
                            onSelected: (i) => _updateGoalFields(dietIntensity: i),
                          ),
                        );
                      },
                    ),
                  ],
                  // BMR & 目標kcal
                  ListTile(
                    title: const Text('基礎代謝 (BMR)'),
                    trailing: Text('${_profile!.bmr.round()} kcal'),
                    subtitle: const Text('Mifflin-St Jeor式', style: TextStyle(fontSize: 11)),
                  ),
                  ListTile(
                    title: const Text('目標カロリー'),
                    trailing: Text('${_profile!.targetKcal.round()} kcal'),
                    subtitle: const Text('タップして手動変更', style: TextStyle(fontSize: 11)),
                    onTap: _editTargetKcal,
                  ),
                  ListTile(
                    title: const Text('目標水分量'),
                    trailing: Text('${_profile!.targetWaterMl.round()} ml'),
                    onTap: _editTargetWater,
                  ),
                ],
                const Divider(),
                const _SectionHeader('アプリについて'),
                const ListTile(
                  title: Text('バージョン'),
                  trailing: Text('1.0.0'),
                ),
                ListTile(
                  title: const Text('プライバシーポリシー'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {},
                ),
              ],
            ),
    );
  }

  Future<void> _editHeight() async {
    if (_profile == null) return;
    double height = _profile!.heightCm;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('身長を変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${height.round()} cm',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              Slider(
                value: height,
                min: 140,
                max: 210,
                divisions: 70,
                onChanged: (v) => ss(() => height = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, height), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (result != null) {
      final newProfile = UserProfile(
        heightCm: result,
        weightKg: _profile!.weightKg,
        age: _profile!.age,
        sex: _profile!.sex,
        activityLevel: _profile!.activityLevel,
        goal: _profile!.goal,
        targetKcal: _profile!.targetKcal,
        targetWaterMl: _profile!.targetWaterMl,
      );
      await DatabaseService.instance.saveUserProfile(newProfile);
      setState(() => _profile = newProfile);
    }
  }

  Future<void> _updateGoalFields({int? sex, int? activityLevel, int? goal, int? dietIntensity}) async {
    if (_profile == null) return;
    final newSex = sex ?? _profile!.sex;
    final newActivity = activityLevel ?? _profile!.activityLevel;
    final newGoal = goal ?? _profile!.goal;
    final newIntensity = dietIntensity ?? _profile!.dietIntensity;
    final tempProfile = UserProfile(
      heightCm: _profile!.heightCm,
      weightKg: _profile!.weightKg,
      age: _profile!.age,
      sex: newSex,
      activityLevel: newActivity,
      goal: newGoal,
      dietIntensity: newIntensity,
      targetKcal: 0,
      targetWaterMl: _profile!.targetWaterMl,
    );
    final newProfile = UserProfile(
      heightCm: _profile!.heightCm,
      weightKg: _profile!.weightKg,
      age: _profile!.age,
      sex: newSex,
      activityLevel: newActivity,
      goal: newGoal,
      dietIntensity: newIntensity,
      targetKcal: UserProfile.calcTargetKcal(tempProfile.bmr, newActivity, newGoal, newIntensity),
      targetWaterMl: _profile!.targetWaterMl,
    );
    await DatabaseService.instance.saveUserProfile(newProfile);
    setState(() => _profile = newProfile);
  }

  Future<void> _editAge() async {
    if (_profile == null) return;
    int age = _profile!.age;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('年齢を変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$age 歳', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              Slider(
                value: age.toDouble(),
                min: 10,
                max: 90,
                divisions: 80,
                onChanged: (v) => ss(() => age = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, age), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (result != null) {
      final newProfile = UserProfile(
        heightCm: _profile!.heightCm,
        weightKg: _profile!.weightKg,
        age: result,
        sex: _profile!.sex,
        activityLevel: _profile!.activityLevel,
        goal: _profile!.goal,
        targetKcal: _profile!.targetKcal,
        targetWaterMl: _profile!.targetWaterMl,
      );
      await DatabaseService.instance.saveUserProfile(newProfile);
      setState(() => _profile = newProfile);
    }
  }

  Future<void> _exportCsv() async {
    final csv = await DatabaseService.instance.exportMealsCsv();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'eat_export.csv'));
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'eat. 食事記録');
  }

  Future<void> _deleteOldData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('古いデータを削除'),
        content: const Text('3ヶ月以上前の食事記録を削除します。よろしいですか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deleteOldMeals();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('削除しました')));
      }
    }
  }

  Future<void> _saveSupplements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _suppKey,
      _supplements.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<void> _addSupplement() async {
    final nameCtrl = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 8, minute: 0);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('サプリを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'サプリ名',
                  hintText: 'ビタミンC、鉄分など',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('通知時刻: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: time,
                      );
                      if (picked != null) ss(() => time = picked);
                    },
                    child: Text(
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final slot = _supplements.length;
      final newSupp = _SupplementReminder(name: name, hour: time.hour, minute: time.minute);
      setState(() => _supplements.add(newSupp));
      await _saveSupplements();
      await NotificationService.instance.scheduleSupplementReminder(
        slot: slot,
        name: name,
        hour: time.hour,
        minute: time.minute,
      );
    }
  }

  Future<void> _deleteSupplement(int index) async {
    await NotificationService.instance.cancelSupplementReminder(index);
    setState(() => _supplements.removeAt(index));
    await _saveSupplements();
    // Re-schedule remaining supplements with correct slot IDs
    for (int i = 0; i < _supplements.length; i++) {
      final s = _supplements[i];
      await NotificationService.instance.scheduleSupplementReminder(
        slot: i,
        name: s.name,
        hour: s.hour,
        minute: s.minute,
      );
    }
  }

  Future<void> _editTargetKcal() async {
    if (_profile == null) return;
    double target = _profile!.targetKcal;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('目標カロリーを変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${target.round()} kcal',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Slider(
                value: target,
                min: 1000,
                max: 4000,
                divisions: 60,
                onChanged: (v) => ss(() => target = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, target),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final updated = UserProfile(
        heightCm: _profile!.heightCm,
        weightKg: _profile!.weightKg,
        age: _profile!.age,
        sex: _profile!.sex,
        activityLevel: _profile!.activityLevel,
        goal: _profile!.goal,
        targetKcal: result,
        targetWaterMl: _profile!.targetWaterMl,
      );
      await DatabaseService.instance.saveUserProfile(updated);
      await _load();
    }
  }

  Future<void> _editTargetWater() async {
    if (_profile == null) return;
    double target = _profile!.targetWaterMl;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('目標水分量を変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${target.round()} ml',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Slider(
                value: target,
                min: 500,
                max: 4000,
                divisions: 70,
                onChanged: (v) => ss(() => target = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, target),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final updated = UserProfile(
        heightCm: _profile!.heightCm,
        weightKg: _profile!.weightKg,
        age: _profile!.age,
        sex: _profile!.sex,
        activityLevel: _profile!.activityLevel,
        goal: _profile!.goal,
        targetKcal: _profile!.targetKcal,
        targetWaterMl: result,
      );
      await DatabaseService.instance.saveUserProfile(updated);
      await _load();
    }
  }
}

class _IntensitySelectionSheet extends StatefulWidget {
  final int current;
  final double tdee;
  final double bmr;
  final void Function(int) onSelected;
  const _IntensitySelectionSheet({
    required this.current,
    required this.tdee,
    required this.bmr,
    required this.onSelected,
  });

  @override
  State<_IntensitySelectionSheet> createState() => _IntensitySelectionSheetState();
}

class _IntensitySelectionSheetState extends State<_IntensitySelectionSheet> {
  late int _selected;

  static const _icons = [Icons.spa_outlined, Icons.trending_down, Icons.fitness_center, Icons.local_fire_department];
  static const _colors = [Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFFF44336)];
  static const _descriptions = [
    '無理なく長く続けたい',
    'バランスよく着実に落とす',
    'しっかり結果を出したい',
    '短期集中で絞り込む',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('ダイエット強度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('強度に応じて目標カロリーが変わります', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: UserProfile.intensityLabels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final deficit = UserProfile.intensityDeficits[i];
                  final targetKcal = (widget.tdee + deficit).clamp(widget.bmr * 0.85, widget.tdee);
                  final monthly = UserProfile.intensityMonthlyKg[i];
                  final isSelected = _selected == i;
                  final color = _colors[i];
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected ? color.withValues(alpha: 0.06) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: isSelected ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_icons[i], color: color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(UserProfile.intensityLabels[i],
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(_descriptions[i],
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                Text('${deficit.abs()} kcal/日 赤字',
                                    style: TextStyle(fontSize: 10, color: color)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${targetKcal.round()}',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold,
                                      color: isSelected ? color : Colors.grey)),
                              Text('kcal/日', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                              Text('月-${monthly}kg目安',
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? color : Colors.grey.shade400, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '※ 運動習慣や体質によって実際の増減幅は変わります。活動レベルも合わせて設定してください。',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: ElevatedButton(
                onPressed: () { widget.onSelected(_selected); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('この強度に設定', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySelectionSheet extends StatefulWidget {
  final int current;
  final double bmr;
  final int goal;
  final void Function(int) onSelected;
  const _ActivitySelectionSheet({
    required this.current,
    required this.bmr,
    required this.goal,
    required this.onSelected,
  });

  @override
  State<_ActivitySelectionSheet> createState() => _ActivitySelectionSheetState();
}

class _ActivitySelectionSheetState extends State<_ActivitySelectionSheet> {
  late int _selected;

  static const _items = [
    _ActivityItem(
      icon: Icons.computer,
      label: 'デスクワーク中心',
      description: 'ほぼ座りっぱなし・運動なし',
      examples: '事務職、在宅ワーク',
      factor: 1.2,
    ),
    _ActivityItem(
      icon: Icons.directions_walk,
      label: '軽い活動',
      description: '週1〜2回の軽い運動またはウォーキング',
      examples: '通勤で少し歩く、週末に散歩',
      factor: 1.375,
    ),
    _ActivityItem(
      icon: Icons.directions_run,
      label: '適度な活動',
      description: '週3〜5回の運動、または立ち仕事',
      examples: '接客・販売・教員・看護師',
      factor: 1.55,
    ),
    _ActivityItem(
      icon: Icons.fitness_center,
      label: '活発な活動',
      description: '毎日運動、または体をよく使う仕事',
      examples: '配達・工場・建設・トレーナー',
      factor: 1.725,
    ),
    _ActivityItem(
      icon: Icons.sports,
      label: 'アスリート・肉体労働',
      description: '1日2回トレーニングまたは激しい肉体労働',
      examples: '競技アスリート、土木・農業',
      factor: 1.9,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current.clamp(0, 4);
  }

  int _targetKcal(int level) {
    final tdee = widget.bmr * _items[level].factor;
    switch (widget.goal) {
      case 0: return (tdee - 500).round();
      case 2: return (tdee + 300).round();
      default: return tdee.round();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('活動レベルを選ぶ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('目標カロリーが自動で調整されます', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final isSelected = _selected == i;
                  final kcal = _targetKcal(i);
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? primary : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected ? primary.withValues(alpha: 0.06) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isSelected ? primary : Colors.grey).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon,
                                color: isSelected ? primary : Colors.grey, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(item.description,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Text(item.examples,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$kcal',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? primary : Colors.grey)),
                              Text('kcal/日',
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? primary : Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: ElevatedButton(
                onPressed: () {
                  widget.onSelected(_selected);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('この活動レベルに設定', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String label;
  final String description;
  final String examples;
  final double factor;
  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.examples,
    required this.factor,
  });
}

class _DietSelectionSheet extends StatefulWidget {
  final DietType current;
  final void Function(DietType) onSelected;
  const _DietSelectionSheet({required this.current, required this.onSelected});

  @override
  State<_DietSelectionSheet> createState() => _DietSelectionSheetState();
}

class _DietSelectionSheetState extends State<_DietSelectionSheet> {
  late DietType _selected;

  static const _caloriePros = [
    '好きな食品を食べながら続けられる',
    '筋肉量を維持しやすい',
    '外食・付き合いに対応しやすい',
    '科学的なエビデンスが豊富',
    '長期的に無理なく続けられる',
  ];
  static const _caloriesCons = [
    '毎食カロリー計算が必要',
    '空腹感を感じやすい',
    '初期の体重減少がゆっくり',
    '食事の満足感が下がりやすい',
    '意志力が必要で挫折しやすい',
  ];
  static const _ketoPros = [
    '脂質・タンパク質で満腹感が続く',
    '血糖値スパイクが抑えられる',
    '初期の体重減少が速い',
    '脳エネルギーが安定し集中力UP',
    'インスリン感受性が改善しやすい',
  ];
  static const _ketoCons = [
    '糖質をほぼゼロにする制限が厳しい',
    '導入初期に倦怠感・頭痛が出やすい',
    '外食・付き合いが難しい',
    '長期的な安全性に議論がある',
    '炭水化物に依存した食文化と合わない',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('ダイエット方法を選ぶ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('自分に合った方法でPFCバーの色が変わります', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _DietCard(
                    type: DietType.calorie,
                    selected: _selected == DietType.calorie,
                    title: 'カロリー制限',
                    subtitle: '高タンパク・低脂質の食品を\nグリーンで表示',
                    icon: Icons.local_fire_department_outlined,
                    pros: _caloriePros,
                    cons: _caloriesCons,
                    primaryColor: primary,
                    onTap: () => setState(() => _selected = DietType.calorie),
                  ),
                  const SizedBox(height: 12),
                  _DietCard(
                    type: DietType.keto,
                    selected: _selected == DietType.keto,
                    title: 'ケトジェニック',
                    subtitle: '高脂質・低糖質の食品を\nグリーンで表示',
                    icon: Icons.egg_outlined,
                    pros: _ketoPros,
                    cons: _ketoCons,
                    primaryColor: const Color(0xFFFF9800),
                    onTap: () => setState(() => _selected = DietType.keto),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSelected(_selected);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('この方法で始める', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietCard extends StatelessWidget {
  final DietType type;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> pros;
  final List<String> cons;
  final Color primaryColor;
  final VoidCallback onTap;

  const _DietCard({
    required this.type,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pros,
    required this.cons,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2.5 : 1,
          ),
          color: selected ? primaryColor.withValues(alpha: 0.06) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: primaryColor, size: 22)
                  else
                    Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ProConColumn(label: 'メリット', items: pros, color: const Color(0xFF4CAF50))),
                  const SizedBox(width: 12),
                  Expanded(child: _ProConColumn(label: 'デメリット', items: cons, color: const Color(0xFFF44336))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProConColumn extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  const _ProConColumn({required this.label, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 11))),
            ],
          ),
        )),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }
}
