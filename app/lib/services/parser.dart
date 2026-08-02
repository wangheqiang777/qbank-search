import 'dart:convert';
import '../models/question.dart';
import 'xlsx.dart';

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// 把字母答案(如 BCDE)展开成 "B.xxx / C.yyy"；判断题等自由文本原样返回。
String buildAnswerText(String ans, List<String> opts) {
  final letters =
      RegExp(r'[A-Ea-e]').allMatches(ans).map((m) => m.group(0)!.toUpperCase());
  if (letters.isNotEmpty && opts.isNotEmpty) {
    final parts = <String>[];
    for (final l in letters) {
      final idx = l.codeUnitAt(0) - 65;
      if (idx >= 0 && idx < opts.length && opts[idx].isNotEmpty) {
        parts.add('$l.${opts[idx]}');
      }
    }
    if (parts.isNotEmpty) return parts.join('  /  ');
  }
  return ans;
}

/// 表头识别：找出题目列、答案列、选项列。
/// 兼容「题目/题干/问题」「正确答案/答案」「选项A..E」或裸表头 A/B/C/D/E。
List<Question> _rowsToQuestions(
    List<String> header, List<List<String>> rows, String sheetName) {
  int qIdx = header.indexWhere(
      (h) => h.contains('题目') || h.contains('题干') || h.contains('问题'));
  int aIdx = header.indexWhere(
      (h) => h.contains('答案') && !h.contains('解析') && !h.contains('分析'));
  if (qIdx < 0) qIdx = 0;
  if (aIdx < 0) aIdx = header.length > 1 ? 1 : 0;

  final optIdx = <int>[];
  for (int i = 0; i < header.length; i++) {
    if (i == qIdx || i == aIdx) continue;
    final h = header[i];
    if (h.contains('选项') || RegExp(r'^[A-Ea-e]$').hasMatch(h)) optIdx.add(i);
  }
  if (optIdx.isEmpty) {
    for (int i = aIdx + 1; i < header.length; i++) {
      optIdx.add(i);
    }
  }

  String cell(List<String> row, int i) =>
      (i >= 0 && i < row.length) ? _clean(row[i]) : '';

  final out = <Question>[];
  for (final row in rows) {
    final q = cell(row, qIdx);
    if (q.isEmpty) continue;
    final ans = cell(row, aIdx);

    final opts = <String>[];
    for (final i in optIdx) {
      opts.add(cell(row, i));
    }
    while (opts.isNotEmpty && opts.last.isEmpty) {
      opts.removeLast();
    }

    out.add(Question(
      type: sheetName,
      question: q,
      answer: ans,
      answerText: buildAnswerText(ans, opts),
      options: jsonEncode(opts),
    ));
  }
  return out;
}

/// 解析 .xlsx（自动遍历全部工作表，表名当题型）
List<Question> parseXlsx(List<int> bytes) {
  final out = <Question>[];
  for (final sheet in parseXlsxSheets(bytes)) {
    final rows = sheet.rows;
    if (rows.length < 2) continue;
    final header = rows.first.map(_clean).toList();
    out.addAll(_rowsToQuestions(header, rows.sublist(1), sheet.name));
  }
  return out;
}

/// 解析 .csv / .txt（首行表头）。自带轻量 CSV 分词，支持引号包裹与转义。
List<Question> parseCsv(List<int> bytes) {
  final content = utf8.decode(bytes, allowMalformed: true);
  final rows = _splitCsv(content);
  if (rows.length < 2) return [];
  final header = rows.first.map(_clean).toList();
  return _rowsToQuestions(header, rows.sublist(1), '导入');
}

List<List<String>> _splitCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final buf = StringBuffer();
  bool inQuote = false;

  for (int i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuote) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuote = false;
        }
      } else {
        buf.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuote = true;
      } else if (ch == ',') {
        row.add(buf.toString());
        buf.clear();
      } else if (ch == '\n') {
        row.add(buf.toString());
        buf.clear();
        rows.add(row);
        row = <String>[];
      } else if (ch == '\r') {
        continue;
      } else {
        buf.write(ch);
      }
    }
  }
  if (buf.isNotEmpty || row.isNotEmpty) {
    row.add(buf.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}
