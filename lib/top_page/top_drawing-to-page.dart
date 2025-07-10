import 'package:flutter/material.dart';

import '../drawing_page/drawing_page.dart';
import '../theme.dart';

class DrawingToPage extends StatefulWidget {
  const DrawingToPage({super.key});

  @override
  State<DrawingToPage> createState() => _DrawingToPageState();
}


class _DrawingToPageState extends State<DrawingToPage> {
  @override
  Widget build(BuildContext context) {
    // スマホ画面の幅を取得
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      // decoration: BoxDecoration(
        // shape: BoxShape.rectangle,
        // color: Colors.white60,
        // border: Border.all(
        //   color: Colors.black12,
        //   width: 2,
        // ),
        // borderRadius: BorderRadius.circular(20),
        // boxShadow: const [
        //   BoxShadow(
        //     offset: Offset(2, 5),
        //     color: Colors.green,
        //   ),
        // ],
      // ),

      width: screenWidth * 0.8, // 画面幅の80%に設定
      height: 70,
      // width: 150,
      // height: 150,
      child: ElevatedButton(
          style: TextButton.styleFrom(
            // foregroundColor: Colors.black,
            backgroundColor: const Color(0xFF032703),
            side: const BorderSide(color: Colors.white, width: 2,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const DrawingPage()), //BT接続画面に遷移
            );
          },
          // child: const Column(
        child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // crossAxisAlignment: CrossAxisAlignment.center,
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('絵を描いて登録',
                  style: AppTheme.buttonTextStyle,
                  // style: TextStyle(
                    // fontFamily: 'NotoSansJP',
                    // fontWeight: FontWeight.w400,//Regular
                    // fontWeight: FontWeight.bold, //Midum
                    // fontSize: 16,//14
                    // color: Colors.white,
                  // ),
                ),
                const Icon(
                  Icons.brush,
                  size: 30.0,
                  // size: 50.0,
                  // color: Colors.white,
                ),

                // SizedBox(height: 7),
                // Text('絵を描いて登録',
                //     style: TextStyle(
                //       // fontFamily: 'NotoSansJP',
                //       // fontWeight: FontWeight.w400,//Regular
                //       fontWeight: FontWeight.bold, //Midum
                //       fontSize: 14,
                //       // color: Colors.white,
                //     ),
                // ),
              ],
          ),
      ),
    );
  }
}
