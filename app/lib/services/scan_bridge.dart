import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/question.dart';
import 'bank_store.dart';

/// 录屏搜题桥接：把 Flutter 侧的「开始/停止」与题库序列化转给 iOS 原生 ScanBridge。
///
/// 原生侧（Swift）负责：弹出系统录屏确认、启动 PiP 悬浮窗、轮询扩展写来的
/// OCR 文本并用本地移植的相似度算法匹配答案、刷新悬浮窗。本类只做薄封装。
class ScanBridge {
  static const MethodChannel _channel = MethodChannel('qbank/scan');

  static final ScanBridge instance = ScanBridge._();
  ScanBridge._();

  /// 把当前题库序列化为 JSON 写入 App Group（原生从这里加载做匹配）。
  Future<void> prepareBank(List<Question> questions) async {
    final items = questions.map((q) => <String, String>{
      'q': q.question,
      'a': q.answerText.isNotEmpty ? q.answerText : q.answer,
      'opts': q.options,
      'type': q.type,
    }).toList();
    final json = jsonEncode(<String, dynamic>{'questions': items});
    try {
      await _channel.invokeMethod<void>('prepareBank', json);
    } on PlatformException {
      // 非 iOS / 未实现时静默忽略
    }
  }

  /// 开始扫描：先序列化题库，再通知原生弹出录屏确认并启动 PiP。
  Future<void> startScan() async {
    await prepareBank(BankStore.instance.questions);
    try {
      await _channel.invokeMethod<void>('startScan');
    } on PlatformException {
      // 静默忽略
    }
  }

  /// 停止扫描：原生会停 PiP、停定时器、停后台保活音频。
  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod<void>('stopScan');
    } on PlatformException {
      // 静默忽略
    }
  }
}
