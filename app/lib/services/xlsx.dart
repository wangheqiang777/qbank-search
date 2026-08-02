import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 一张工作表：名称 + 二维单元格文本
class SheetData {
  final String name;
  final List<List<String>> rows;
  SheetData(this.name, this.rows);
}

/// 纯 Dart 解析 .xlsx（本质是 zip + OOXML）。
///
/// 不使用 excel 包：它 4.x 的 CellValue 是密封类且跨小版本有 breaking change，
/// 云端 CI 构建时极易因版本解析到不同 API 而编译失败。这里只取单元格显示文本，
/// 题库场景完全够用，且依赖只有 archive + xml 两个长期稳定的包。
List<SheetData> parseXlsxSheets(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final entries = <String, List<int>>{};
  for (final f in archive.files) {
    if (f.isFile) {
      final c = f.content;
      if (c is List<int>) entries[f.name] = c;
    }
  }

  String? readText(String path) {
    final data = entries[path];
    if (data == null) return null;
    return utf8.decode(data, allowMalformed: true);
  }

  // 1) 共享字符串表：绝大多数文本单元格的内容都存在这里
  final shared = <String>[];
  final ssXml = readText('xl/sharedStrings.xml');
  if (ssXml != null) {
    for (final si in XmlDocument.parse(ssXml).findAllElements('si')) {
      final buf = StringBuffer();
      for (final t in si.findAllElements('t')) {
        buf.write(t.innerText);
      }
      shared.add(buf.toString());
    }
  }

  // 2) rId -> 工作表文件路径
  final relMap = <String, String>{};
  final relXml = readText('xl/_rels/workbook.xml.rels');
  if (relXml != null) {
    for (final r in XmlDocument.parse(relXml).findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final tgt = r.getAttribute('Target');
      if (id != null && tgt != null) relMap[id] = tgt;
    }
  }

  // 3) workbook.xml 里拿工作表名与顺序
  final sheets = <SheetData>[];
  final wbXml = readText('xl/workbook.xml');
  if (wbXml == null) return sheets;

  int seq = 0;
  for (final s in XmlDocument.parse(wbXml).findAllElements('sheet')) {
    seq++;
    final name = s.getAttribute('name') ?? 'Sheet$seq';
    final rid = s.getAttribute('r:id') ?? s.getAttribute('id');
    String? target = rid == null ? null : relMap[rid];

    String path;
    if (target == null) {
      path = 'xl/worksheets/sheet$seq.xml';
    } else if (target.startsWith('/')) {
      path = target.substring(1);
    } else if (target.startsWith('xl/')) {
      path = target;
    } else {
      path = 'xl/$target';
    }
    if (!entries.containsKey(path)) {
      path = 'xl/worksheets/sheet$seq.xml';
    }

    final wsXml = readText(path);
    if (wsXml == null) continue;
    sheets.add(SheetData(name, _parseSheet(wsXml, shared)));
  }
  return sheets;
}

List<List<String>> _parseSheet(String xmlStr, List<String> shared) {
  final doc = XmlDocument.parse(xmlStr);
  final out = <List<String>>[];

  for (final row in doc.findAllElements('row')) {
    final cells = <int, String>{};
    int maxCol = -1;
    int fallbackCol = 0;

    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      final col = ref == null ? fallbackCol : _colIndex(ref);
      fallbackCol = col + 1;
      final t = c.getAttribute('t');

      String text = '';
      if (t == 'inlineStr') {
        final buf = StringBuffer();
        for (final e in c.findAllElements('t')) {
          buf.write(e.innerText);
        }
        text = buf.toString();
      } else {
        final vs = c.findElements('v');
        if (vs.isNotEmpty) {
          final raw = vs.first.innerText;
          if (t == 's') {
            final i = int.tryParse(raw);
            if (i != null && i >= 0 && i < shared.length) text = shared[i];
          } else {
            text = raw;
          }
        }
      }

      cells[col] = text;
      if (col > maxCol) maxCol = col;
    }

    out.add(List<String>.generate(maxCol + 1, (i) => cells[i] ?? ''));
  }
  return out;
}

/// "AB12" -> 列号 27（0 起）
int _colIndex(String ref) {
  int n = 0;
  for (int i = 0; i < ref.length; i++) {
    final ch = ref.codeUnitAt(i);
    if (ch >= 65 && ch <= 90) {
      n = n * 26 + (ch - 64);
    } else if (ch >= 97 && ch <= 122) {
      n = n * 26 + (ch - 96);
    } else {
      break;
    }
  }
  return n <= 0 ? 0 : n - 1;
}
