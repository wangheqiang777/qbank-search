import 'dart:math' as math;
import '../models/question.dart';

/// 文本归一化：转小写，去掉标点/空格/换行，仅保留中英文字符与数字。
/// 这一步是抗 OCR 噪声的第一道防线（考试截图常带全角标点、多余空格）。
String normalize(String s) {
  return s.toLowerCase().replaceAll(RegExp(r'[^0-9a-z\u4e00-\u9fff]'), '');
}

Set<String> bigrams(String s) {
  if (s.isEmpty) return <String>{};
  if (s.length == 1) return {s};
  final set = <String>{};
  for (int i = 0; i < s.length - 1; i++) {
    set.add(s.substring(i, i + 2));
  }
  return set;
}

/// 相似度 = max(Jaccard, 覆盖率×0.95)
///
/// 为什么不只用 Jaccard：截图 OCR 出来的文本往往是「题干 + 全部选项 + 题号」，
/// 比题库里存的纯题干长两三倍。此时 Jaccard 的分母（并集）被撑大，
/// 明明是同一道题相似度却掉到 0.4 以下 —— 这正是市面搜题 App「找不准」的主因之一。
/// 覆盖率 inter/|b| 衡量「题库题干有多少被查询覆盖」，对这种包含关系免疫。
double similarity(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final inter = a.intersection(b).length;
  if (inter == 0) return 0.0;
  final jac = inter / (a.length + b.length - inter);
  final containment = inter / b.length;
  return math.max(jac, containment * 0.95);
}

class MatchResult {
  final Question question;
  final double score;
  MatchResult(this.question, this.score);
}

/// 预计算索引：把全库的归一化文本与 bigram 集合缓存下来。
///
/// 没有这一层的话，每敲一个字就要对 1400+ 道题重跑 normalize + bigrams，
/// 手机上会有几百毫秒卡顿，实时搜索根本用不了。
class SearchIndex {
  final List<Question> questions;
  final List<String> _norms;
  final List<Set<String>> _grams;

  SearchIndex._(this.questions, this._norms, this._grams);

  factory SearchIndex(List<Question> qs) {
    final norms = <String>[];
    final grams = <Set<String>>[];
    for (final q in qs) {
      final n = normalize(q.question);
      norms.add(n);
      grams.add(bigrams(n));
    }
    return SearchIndex._(qs, norms, grams);
  }

  int get length => questions.length;

  List<MatchResult> search(String query, {int topK = 3}) {
    final nq = normalize(query);
    if (nq.isEmpty || questions.isEmpty) return [];
    final nb = bigrams(nq);

    final scored = <MatchResult>[];
    for (int i = 0; i < questions.length; i++) {
      final n = _norms[i];
      if (n.isEmpty) continue;

      double s;
      if (n.contains(nq)) {
        // 查询是题干的一部分（手打了前半句）
        s = 1.0;
      } else if (n.length >= 8 && nq.contains(n)) {
        // 查询包含整条题干（截图连选项一起 OCR 了）——限制题干长度避免短判断题误命中
        s = 0.99;
      } else {
        s = similarity(nb, _grams[i]);
      }
      scored.add(MatchResult(questions[i], s));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }
}
