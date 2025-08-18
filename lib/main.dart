
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'top_page/top_page.dart';
import 'theme.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env'); // 環境変数をロード
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'WaveCast',
      //'E ink E-paper',
      debugShowCheckedModeBanner: false, // デバッグバナーを非表示
      theme: AppTheme.lightTheme, // `theme.dart` のテーマを適用
      themeMode: ThemeMode.system, // システムの設定に従う
      home: const TopPage(title: 'WaveCast'),
    );
  }
}
