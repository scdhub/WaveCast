import 'package:flutter/material.dart';

import '../text_input_page/text_input_page.dart';
import '../theme.dart';

class TextToPage extends StatefulWidget {
  const TextToPage({super.key});

  @override
  State<TextToPage> createState() => _TextToPageState();
}

class _TextToPageState extends State<TextToPage> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(

      // decoration: BoxDecoration(
      // shape: BoxShape.rectangle,
      // border: Border.all(
      //   color: Colors.white,
      //   width: 4,
      // ),
      // borderRadius: BorderRadius.circular(10),//20
      // boxShadow: const [
      //   BoxShadow(
      //     offset: Offset(4, 5),
      //     color: Color(0xFFCEC5F0),  // ラベンダー
      //
      //   ),
      // ),

      width: screenWidth * 0.8, // 画面幅の80%に設定
      height: 70,
      // width: 150,
      // height: 150,
      child: ElevatedButton(
        style: TextButton.styleFrom(
          // foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF275315),
          side: const BorderSide(
            color: Colors.white,
            width: 2,//4
          ),
          // backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0) //20
          ),
        ),

        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TextInputPage()), //BT接続画面に遷移
          );
        },
        // child: const Column(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // crossAxisAlignment: CrossAxisAlignment.center,
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('入力して登録',
              style: AppTheme.buttonTextStyle,
              // style: TextStyle(
                // fontFamily: 'NotoSansJP',
                // fontWeight: FontWeight.w400,//Regular
              //   fontWeight: FontWeight.bold, //Midum
              //   fontSize: 16,//14
              // ),
            ),
            const Icon(
              Icons.edit_note_outlined,
              size: 40,//50
              // color: Colors.white,
            ),
            // SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}

