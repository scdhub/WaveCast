import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:iphone_bt_epaper/top_page/top_text-to-page.dart';
// import '../app_body_color.dart';
import '../theme.dart';
import 'top_bt-connect-to-page.dart';
import 'top_drawing-to-page.dart';
// import 'top_import-type-select-to-popup.dart';
import 'top_take-a-picture-page.dart';  // カメラボタン追加
import 'top_select-picture-page.dart'; // アルバムボタン追加


class TopPage extends StatefulWidget {
  final String title;
  const TopPage({super.key, required this.title});

  @override
  State<TopPage> createState() => _TopPageState();
}

class _TopPageState extends State<TopPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WaveCast',
              style: TextStyle(
                color: AppTheme.appBarTextColor,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8), // テキストとアイコンの間隔
            // Image.asset(
            //   'assets/assets_CanvasEP_image/CanvasEP_01.png',
            //   height: 45, // アイコンサイズはお好みで
            // ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
      ),
      body: SafeArea(
        child: Column(
            children: [
        const Spacer(),
      //         Text(
      //           widget.title,
      //           textAlign: TextAlign.center,
      //           style: const TextStyle(
      //             color: Colors.white,
      //             fontSize: 60,
      //             fontWeight: FontWeight.bold,
      //             letterSpacing: 1,
      //           ),
      //         ),
              // const SizedBox(height: 25),//タイトルとボタンの余白

              // const Text('下記から画像をアップロードしてください。',
              //   textAlign: TextAlign.center,
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     fontSize: 15,
              //     // fontSize: 20,
              //   ),
              // ),
              // const Text('(Ver.20231201.001)',
              //     style: TextStyle(
              //       fontSize: 8
              //       // fontSize: 15,
              //     )),
              //ボタン縦並び　ここをmargin

        const Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,

          children: [
              Center(child: BlueToothConnectToPage()), //BTボタン
              SizedBox(height: 10),

              Center(child: TopSelectPicturePage()), // アルバムボタン
              SizedBox(height: 10),

              Center(child: TopTakeAPicturePage()), // カメラボタン
              SizedBox(height: 10),

              Center(child: TextToPage()), //文字入力ボタン
              SizedBox(height: 10),

              Center(child: DrawingToPage()), //絵を描くボタン
            ],
          ),
          // ),

          // const SizedBox(height: 10),
          // //中央にボタンを配置
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     //bt接続画面に遷移するボタン
          //     BlueToothConnectToPage(),
          //     SizedBox(width: 10,),
          //     //スマホ画像種類選択画面に遷移するボタン
          //     // ImportTypeSelectToPopup(),
          //     //
          //   ],
          // ),
          // const SizedBox(height: 10,),
          //
          //
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     //ドローイング画面に遷移するボタン
          //     DrawingToPage(),
          //     SizedBox(width: 10,),
          //     //テキスト入力画面に遷移するボタン
          //     TextToPage(),
          //   ],
          // )
        const Spacer(), // ボタンと下側の余白を均等にする
          const Padding(
            padding: EdgeInsets.only(bottom: 5), // 下に余白をつける
            child: Column(
              children: [
                Text('最新インストールツール',
                  style: TextStyle(
                    fontSize: 14,
                  color: Colors.white),
                ),
                Text('(Ver.20231201.001)',
                  style: TextStyle(
                    fontSize: 12,
                      color: Colors.white),
                ),
            ],
        ),
      ),
      ],
    ),
    ),
    );
  }
}
// fontSize: 20,)),
//                 SizedBox(
//                 ),
//                 const Text('最新インストールツール',
//                     style: TextStyle(
//                       fontSize: 10
//                       // fontSize: 20,
//                     )),
//                 const Text('(Ver.20231201.001)',
//                     style: TextStyle(
//                       fontSize: 8
//                       // fontSize: 15,
//                     )),
//               ]),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
