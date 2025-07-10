import 'package:flutter/material.dart';
import '../import_type_select_page/take-photo_page.dart';
import '../theme.dart';

class TopTakeAPicturePage extends StatelessWidget {
  const TopTakeAPicturePage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.8, // 画面幅の80%に設定
      height: 70,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25804C),
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          getImageFromCamera(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '撮影して登録',
              style: AppTheme.buttonTextStyle,
            ),
            const Icon(Icons.camera_alt, size: 30.0),
          ],
        ),
      ),
    );
  }
}
