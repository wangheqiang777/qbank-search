import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'database.dart';
import 'search.dart';

/// 全局题库缓存：索引只建一次，切换页签不再重复读库+重算 bigram。
class BankStore extends ChangeNotifier {
  static final BankStore instance = BankStore._();
  BankStore._();

  SearchIndex? _index;
  bool _loading = false;

  SearchIndex? get index => _index;
  bool get loading => _loading;
  int get count => _index?.length ?? 0;
  List<Question> get questions => _index?.questions ?? const <Question>[];

  Future<void> load({bool force = false}) async {
    if (_index != null && !force) return;
    _loading = true;
    notifyListeners();
    final qs = await BankDatabase.all();
    _index = SearchIndex(qs);
    _loading = false;
    notifyListeners();
  }

  /// 导入新题库后调用：整库替换并重建索引
  Future<void> replaceWith(List<Question> qs) async {
    _loading = true;
    notifyListeners();
    await BankDatabase.clear();
    await BankDatabase.insertAll(qs);
    final fresh = await BankDatabase.all();
    _index = SearchIndex(fresh);
    _loading = false;
    notifyListeners();
  }

  Map<String, int> typeCounts() {
    final m = <String, int>{};
    for (final q in questions) {
      m[q.type] = (m[q.type] ?? 0) + 1;
    }
    return m;
  }
}
