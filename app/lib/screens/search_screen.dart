import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bank_store.dart';
import '../services/search.dart';
import '../services/scan_bridge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _store = BankStore.instance;
  List<MatchResult> _results = [];
  Timer? _debounce;
  bool _autoClip = true;
  String _lastClip = '';
  bool _scanning = false;

  Future<void> _toggleScan() async {
    if (_scanning) {
      await ScanBridge.instance.stopScan();
      if (mounted) setState(() => _scanning = false);
    } else {
      if (mounted) setState(() => _scanning = true);
      await ScanBridge.instance.startScan();
    }
  }

  Widget _scanControls() {
    if (!Platform.isIOS) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('录屏悬浮扫描仅支持 iPhone（iOS 15+）。安卓请用下方「粘贴搜题」。',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _scanning ? Colors.red.shade50 : Colors.blue.shade50,
      ),
      child: Row(
        children: [
          Icon(
            _scanning ? Icons.fiber_manual_record : Icons.play_circle_outline,
            color: _scanning ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _scanning
                  ? '正在录屏扫描：答案已浮在考试界面上，回本 App 点「停止扫描」即可'
                  : '点「开始扫描」→ 系统确认一次 → 之后自动识别屏幕题目，答案浮在考试界面',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _toggleScan,
            child: Text(_scanning ? '停止扫描' : '开始扫描'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onStore);
    _store.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStore);
    _ctrl.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() => _rerun());
  }

  /// 切回本 App 时自动读一次剪贴板：
  /// iOS 15+ 在截图上长按可直接用系统「实况文本」选中题目复制，
  /// 回到这里就已经出答案了，省掉手动粘贴那一步。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _autoClip) {
      _paste(silent: true);
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _rerun());
    });
  }

  void _rerun() {
    final idx = _store.index;
    final q = _ctrl.text.trim();
    if (idx == null || q.isEmpty) {
      _results = [];
      return;
    }
    _results = idx.search(q, topK: 3);
  }

  Future<void> _paste({bool silent = false}) async {
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final t = (d?.text ?? '').trim();
      if (t.isEmpty) return;
      if (silent && (t == _lastClip || t.length < 6)) return;
      _lastClip = t;
      _ctrl.text = t;
      if (mounted) setState(() => _rerun());
    } catch (_) {
      // 用户拒绝粘贴权限时静默忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _store.loading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          _scanControls(),
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '长按粘贴题目，边输边搜',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _results = []);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _paste(),
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('粘贴搜题'),
              ),
              const Spacer(),
              Text('${_store.count} 道',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 8),
              Switch(
                value: _autoClip,
                onChanged: (v) => setState(() => _autoClip = v),
              ),
              const Text('自动读剪贴板', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _empty()
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) => _card(_results[i], i == 0),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                _store.count == 0
                    ? '还没有题库，先去「导入」页选文件'
                    : '截图后长按选中题目复制，回到这里自动出答案',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );

  Widget _card(MatchResult r, bool primary) {
    final q = r.question;
    final pct = (r.score * 100).round();
    final good = r.score >= 0.6;
    final color = good ? Colors.green : Colors.orange;

    List<String> opts = const [];
    try {
      final decoded = jsonDecode(q.options);
      if (decoded is List) {
        opts = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: primary ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: primary ? color.withValues(alpha: 0.5) : Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$pct%',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Text(q.type,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              q.answerText.isEmpty ? q.answer : q.answerText,
              style: TextStyle(
                fontSize: primary ? 24 : 17,
                fontWeight: FontWeight.w600,
                color: color.shade800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(q.question,
                style: TextStyle(fontSize: 13, color: Colors.grey[800])),
            if (primary && opts.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(opts.length, (i) {
                if (opts[i].isEmpty) return const SizedBox.shrink();
                final letter = String.fromCharCode(65 + i);
                final hit = q.answer.toUpperCase().contains(letter);
                return Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '$letter. ${opts[i]}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: hit ? color.shade700 : Colors.grey[600],
                      fontWeight: hit ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
