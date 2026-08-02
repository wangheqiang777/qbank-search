import 'package:flutter/material.dart';
import 'screens/import_screen.dart';
import 'screens/search_screen.dart';
import 'screens/bank_screen.dart';
import 'services/bank_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BankStore.instance.load();
  runApp(const QBankApp());
}

class QBankApp extends StatelessWidget {
  const QBankApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '题库搜答案',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _idx = 1;

  static const _titles = ['导入题库', '搜答案', '题库'];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_titles[_idx]),
          centerTitle: false,
        ),
        // IndexedStack 保活：切页签不销毁 State，搜索结果和输入不会丢
        body: IndexedStack(
          index: _idx,
          children: const [
            ImportScreen(),
            SearchScreen(),
            BankScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file),
                label: '导入'),
            NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.saved_search),
                label: '搜答案'),
            NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: '题库'),
          ],
        ),
      );
}
