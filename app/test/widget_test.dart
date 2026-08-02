// 极简冒烟测试：能正常把 App 构建起来即可（真实题库逻辑靠真机验证）。
import 'package:flutter_test/flutter_test.dart';

import 'package:qbank_search/main.dart';

void main() {
  testWidgets('App 能正常构建', (WidgetTester tester) async {
    await tester.pumpWidget(const QBankApp());
    // 默认在「搜答案」页，应能看到标题
    expect(find.text('搜答案'), findsWidgets);
  });
}
