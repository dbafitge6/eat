import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
import '../services/gemini_service.dart';

class AiChatScreen extends StatefulWidget {
  final List<MealEntry> todayMeals;
  final UserProfile? profile;

  const AiChatScreen({
    super.key,
    required this.todayMeals,
    this.profile,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_Msg>[];
  // history for HTTP API: role=user/model, text
  final _history = <Map<String, String>>[];
  bool _sending = false;
  String? _apiKey;
  bool _noApiKey = false;
  String _systemContext = '';
  int _todayCount = 0;
  static const _maxDaily = 15;
  static const _countKeyPrefix = 'ai_chat_count_';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _todayKey {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return '$_countKeyPrefix$today';
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _todayCount = prefs.getInt(_todayKey) ?? 0;
  }

  Future<void> _incrementCount() async {
    final prefs = await SharedPreferences.getInstance();
    _todayCount++;
    await prefs.setInt(_todayKey, _todayCount);
  }

  Future<void> _initChat() async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      setState(() => _noApiKey = true);
      return;
    }
    await _loadCount();

    final totalKcal = widget.todayMeals.fold(0.0, (s, m) => s + m.kcal);
    final totalProtein = widget.todayMeals.fold(0.0, (s, m) => s + m.protein);
    final totalFat = widget.todayMeals.fold(0.0, (s, m) => s + m.fat);
    final totalCarb = widget.todayMeals.fold(0.0, (s, m) => s + m.carb);
    final goal = widget.profile?.goal ?? 1;
    final goalNames = ['ダイエット（減量）', '維持', '増量'];
    final targetKcal = widget.profile?.targetKcal ?? 2000;

    _systemContext = '''
あなたは栄養・食事管理専門のAIアシスタント「eat.」です。
【重要ルール】食事・栄養・ダイエット・健康食品に関する質問のみ回答してください。
それ以外のトピック（政治・技術・趣味・恋愛・仕事など）には「食事・栄養に関するご相談のみ対応しています」と丁寧に断り、食事の話題に誘導してください。
返答は日本語で、わかりやすく簡潔に（3〜5文程度）。

今日のユーザー情報:
- 目標: ${goalNames[goal.clamp(0, 2)]}
- 目標カロリー: ${targetKcal.round()} kcal
- 今日の摂取: ${totalKcal.round()} kcal（P:${totalProtein.round()}g / F:${totalFat.round()}g / C:${totalCarb.round()}g）
- 今日の食事: ${widget.todayMeals.isEmpty ? 'まだ記録なし' : widget.todayMeals.map((m) => m.foodName).join('、')}
''';

    setState(() {
      _apiKey = apiKey;
      _messages.add(_Msg(
        isUser: false,
        text: '今日の食事を確認しました！栄養・ダイエット・食事について何でも聞いてください 😊',
      ));
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending || _apiKey == null) return;

    if (_todayCount >= _maxDaily) {
      setState(() => _messages.add(_Msg(
        isUser: false,
        text: '本日の相談回数（$_maxDaily回）に達しました。明日またご利用ください 🌙',
      )));
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_Msg(isUser: true, text: text));
      _sending = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      // システムコンテキストを最初のメッセージに含める
      final historyWithContext = _history.isEmpty
          ? [<String, String>{'role': 'user', 'text': _systemContext}]
          : List<Map<String, String>>.from(_history);

      final reply = await GeminiService.instance.chat(_apiKey!, historyWithContext, text);
      final replyText = reply ?? '申し訳ありません、回答できませんでした。';
      _history.add({'role': 'user', 'text': text});
      _history.add({'role': 'model', 'text': replyText});
      await _incrementCount();
      setState(() => _messages.add(_Msg(isUser: false, text: replyText)));
    } catch (e) {
      setState(() => _messages.add(_Msg(isUser: false, text: 'エラーが発生しました: $e')));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, secondary]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('AI栄養相談'),
          ],
        ),
        actions: [
          if (_apiKey != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_maxDaily - _todayCount}/$_maxDaily',
                  style: TextStyle(
                    fontSize: 12,
                    color: (_maxDaily - _todayCount) <= 3
                        ? Colors.orangeAccent
                        : Colors.white54,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _noApiKey
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.key_off, size: 64, color: Colors.grey.shade600),
                    const SizedBox(height: 16),
                    const Text(
                      'Gemini APIキーが設定されていません',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '設定 → AI食品検索 → Gemini APIキー から設定してください。\nGoogle AI Studioで無料取得できます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('戻る'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return _BubbleTyping(primary: primary);
                      }
                      final msg = _messages[i];
                      return _Bubble(msg: msg, primary: primary, secondary: secondary);
                    },
                  ),
                ),
                // Suggested questions
                if (_messages.length == 1) ...[
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        '今日の食事の評価は？',
                        '何を食べればいい？',
                        '夜食で低カロリーなおすすめは？',
                        'たんぱく質を増やすには？',
                      ].map((q) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            _inputCtrl.text = q;
                            _send();
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    top: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          maxLines: 3,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: '栄養・食事について質問...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [primary, secondary]),
                            shape: BoxShape.circle,
                          ),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Msg {
  final bool isUser;
  final String text;
  _Msg({required this.isUser, required this.text});
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final Color primary;
  final Color secondary;

  const _Bubble({required this.msg, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, secondary]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: msg.isUser
                    ? LinearGradient(colors: [primary, secondary])
                    : null,
                color: msg.isUser ? null : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _BubbleTyping extends StatelessWidget {
  final Color primary;
  const _BubbleTyping({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 14, color: primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 40,
              height: 16,
              child: _TypingDots(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) {
          final delay = i / 3;
          final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
          final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Opacity(
            opacity: opacity,
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
            ),
          );
        }),
      ),
    );
  }
}
