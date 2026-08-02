class Question {
  final int? id;
  final String type; // 单选题 / 多选题 / 判断题 / 导入
  final String question;
  final String answer; // 原始答案: A / BCDE / 正确
  final String answerText; // 展开: A.恶心呕吐
  final String options; // JSON 编码的选项列表

  Question({
    this.id,
    required this.type,
    required this.question,
    required this.answer,
    required this.answerText,
    required this.options,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'question': question,
        'answer': answer,
        'answer_text': answerText,
        'options': options,
      };

  factory Question.fromMap(Map<String, dynamic> m) => Question(
        id: m['id'],
        type: m['type'],
        question: m['question'],
        answer: m['answer'],
        answerText: m['answer_text'],
        options: m['options'],
      );
}
