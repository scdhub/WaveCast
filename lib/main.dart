
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



// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'top_page/top_page.dart';
//
// Future<void> main() async {
//   await dotenv.load(fileName: '.env'); //環境変数を使う為、設置。
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'E ink E-paper',
//       theme: ThemeData(
//         useMaterial3: true,
//         //アプリ全体に下記フォントを反映
//         fontFamily: 'NotoSansJP',
//         //アプリ全体のappBarに下記フォント、背景を反映
//         appBarTheme: AppBarTheme(
//             // color: Color(0xFF87ff99),
//             backgroundColor: Colors.white,
//             //戻るボタンとかの
//             iconTheme: IconThemeData(color: Color(0xFFF4A7B9)),
//             //
//             actionsIconTheme: IconThemeData(color: Color(0xFFF4A7B9)),
//             //アクションアイコンの色
//
//             //タイトル文字の内容
//             titleTextStyle: TextStyle(
//               color: Color(0xFFF4A7B9),
//               fontSize: 25,
//               fontFamily: 'NotoSansJP',
//             ),
//
//             centerTitle: false,
//             // centerTitle: true,
//             toolbarTextStyle: TextStyle(
//                 color: Colors.yellow[100],
//                 fontSize: 20,
//                 fontFamily: 'NotoSansJP')),
//       ),
//       home: const TopPage(title: 'E ink E-paper'),
//     );
//   }
// }
