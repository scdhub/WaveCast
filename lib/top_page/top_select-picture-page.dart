import 'package:flutter/material.dart';

import '../server_upload/photo-select_page.dart';
import '../theme.dart';

class TopSelectPicturePage extends StatelessWidget {
  const TopSelectPicturePage({super.key});

  @override
  Widget build(BuildContext context) {
    // スマホ画面の幅を取得
    double screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.8, // 画面幅の80%に設定
      height: 70,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:  const Color(0xFF16A362),
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),

        onPressed: () {
            // アルバムの画像を選択する画面に遷移
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ImageSelect_Album()),
            );
        },

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'アルバムから登録',
              style: AppTheme.buttonTextStyle,
            ),
            const Icon(Icons.photo_library, size: 30.0),
          ],
        ),
      ),
    );
  }
}
