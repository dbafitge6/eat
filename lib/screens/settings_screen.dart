import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../themes/app_theme.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _profile;
  bool _notificationsEnabled = false;
  bool _loading = true;
  String _geminiApiKey = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController(text: _geminiApiKey);
    bool obscure = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Gemini APIキー'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'AIza...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => ss(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Google AI Studio（aistudio.google.com）で無料取得できます。\nキーはこの端末にのみ保存されます。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            if (_geminiApiKey.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  GeminiService.instance.saveApiKey('');
                  setState(() => _geminiApiKey = '');
                },
                child: const Text('削除', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = ctrl.text.trim();
                Navigator.pop(ctx);
                GeminiService.instance.saveApiKey(key);
                setState(() => _geminiApiKey = key);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final profile = await DatabaseService.instance.getUserProfile();
    final apiKey = await GeminiService.instance.getApiKey();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _geminiApiKey = apiKey ?? '';
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
                const _SectionHeader('テーマ'),
                ...AppThemeType.values.map((t) {
                  final current = appState?.currentTheme ?? AppThemeType.purpleViolet;
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
                    subtitle: Text(
                      AppThemes.themeKeywords[t.index],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.white)
                        : null,
                    onTap: () {
                      appState?.setTheme(t);
                      setState(() {});
                    },
                  );
                }),
                const Divider(),
                const _SectionHeader('AI食品検索'),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Gemini APIキー'),
                  subtitle: Text(
                    _geminiApiKey.isEmpty
                        ? '未設定（AI提案は使用できません）'
                        : '設定済み ✓',
                    style: TextStyle(
                      fontSize: 12,
                      color: _geminiApiKey.isEmpty ? Colors.grey : Colors.greenAccent,
                    ),
                  ),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: _showApiKeyDialog,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Google AI Studio（aistudio.google.com）で無料取得できます。入力するとAI食品提案機能が使えます。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const Divider(),
                const _SectionHeader('水分リマインダー'),
                SwitchListTile(
                  title: const Text('水分補給リマインダー'),
                  subtitle: const Text('定期的に通知します'),
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    if (v) {
                      await NotificationService.instance
                          .scheduleWaterReminders([8, 10, 12, 14, 16, 18, 20]);
                    } else {
                      await NotificationService.instance.cancelAll();
                    }
                  },
                ),
                const Divider(),
                const _SectionHeader('データ'),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('CSVエクスポート'),
                  subtitle: const Text('食事記録をCSVでエクスポート'),
                  onTap: _exportCsv,
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
                    trailing:
                        Text('${_profile!.heightCm.round()} cm'),
                  ),
                  ListTile(
                    title: const Text('体重'),
                    trailing:
                        Text('${_profile!.weightKg.toStringAsFixed(1)} kg'),
                  ),
                  ListTile(
                    title: const Text('目標カロリー'),
                    trailing:
                        Text('${_profile!.targetKcal.round()} kcal'),
                    onTap: _editTargetKcal,
                  ),
                  ListTile(
                    title: const Text('目標水分量'),
                    trailing:
                        Text('${_profile!.targetWaterMl.round()} ml'),
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
