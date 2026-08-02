import 'package:flutter/material.dart';
import '../services/bank_store.dart';
import '../models/question.dart';

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});
  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  final _store = BankStore.instance;
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _filter.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final kw = _filter.text.trim();
    final List<Question> list = kw.isEmpty
        ? _store.questions
        : _store.questions.where((q) => q.question.contains(kw)).toList();

    final counts = _store.typeCounts();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '筛选题目关键字',
              prefixIcon: Icon(Icons.filter_list, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (counts.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: counts.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('${e.key} ${e.value}',
                              style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('题库为空，先去「导入」页添加'))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final q = list[i];
                    return ListTile(
                      dense: true,
                      leading: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      title: Text(q.question,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        q.answerText.isEmpty ? q.answer : q.answerText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.green[800]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
