import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/parser.dart';
import '../services/bank_store.dart';
import '../models/question.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _store = BankStore.instance;
  String _status = '';
  bool _busy = false;
  bool _error = false;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = false;
      _status = '解析中…';
    });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'txt'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        setState(() {
          _busy = false;
          _status = '';
        });
        return;
      }

      final f = res.files.single;
      List<int>? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) {
        setState(() {
          _busy = false;
          _error = true;
          _status = '读不到文件内容，换个位置再试（建议先存到「文件」App）';
        });
        return;
      }

      final lower = (f.name).toLowerCase();
      final List<Question> qs =
          lower.endsWith('.xlsx') ? parseXlsx(bytes) : parseCsv(bytes);

      if (qs.isEmpty) {
        setState(() {
          _busy = false;
          _error = true;
          _status = '没解析出题目。请确认表格里有「题目」和「答案」两列表头。';
        });
        return;
      }

      await _store.replaceWith(qs);
      final counts = _store.typeCounts();
      final detail =
          counts.entries.map((e) => '${e.key} ${e.value}').join(' · ');
      setState(() {
        _busy = false;
        _status = '导入成功，共 ${qs.length} 道\n$detail';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = true;
        _status = '导入失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 56, color: Colors.blue[400]),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(_busy ? '处理中…' : '选择题库文件'),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _error ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _error ? Colors.red[900] : Colors.green[900],
                      fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              '支持 .xlsx / .csv / .txt\n'
              '每次导入会整库替换，换一份题库直接重新导即可\n'
              '题库只存在本机，不上传任何服务器',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}
