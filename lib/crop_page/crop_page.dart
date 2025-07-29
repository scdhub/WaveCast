//　選択された画像をトリミングし、jpegに変換している
//　リサイズ時に関しては600*488にしておく。ラズパイ側で800*480に修正する

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import '../server_upload/select-photo-check_page.dart';

void cropImage(BuildContext context,
    {File? imageFile, AssetEntity? asset}) async {
  File? fileToCrop;

//カメラ画像なら、そのまま使う
  if (imageFile != null) {
    fileToCrop = imageFile;
  }

// アルバム画像なら、AssetEntity を File に変換する
  if (asset != null) {
    fileToCrop = await asset.file; // AssetEntity → File に変換
  }

// どっちもnulの場合は中断（ファイルが取得できなかった場合、処理を中断する）
  if (fileToCrop == null) {
    debugPrint("画像の取得に失敗しました");
    return;
  }

//画像をトリミングする(600*448のままにしておく)
  final croppedFile = await ImageCropper().cropImage(
    sourcePath: fileToCrop.path, // `File` のパスを渡す
    // aspectRatio: const CropAspectRatio(ratioX: 600, ratioY: 448),
    aspectRatio: const CropAspectRatio(ratioX: 800, ratioY: 480),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'トリミング',
        toolbarColor: Colors.black,
        toolbarWidgetColor: Colors.white,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: 'トリミング画面',
        cancelButtonTitle: 'Cancel',
        doneButtonTitle: 'Crop',
        // minimumAspectRatio: 600 / 448,
        minimumAspectRatio: 800 / 480,
        aspectRatioLockEnabled: true, // iOS でもアスペクト比を固定
      ),
    ],
  );

//トリミング後の画像を `Uint8List` に変換
  if (croppedFile != null) {
    Uint8List cropBytes = await croppedFile.readAsBytes();

    // 解像度確認
    img.Image? checkImage = img.decodeImage(cropBytes);
    if (checkImage != null) {
      debugPrint('Cropped File: ${croppedFile.path} -> Width: ${checkImage.width}, Height: ${checkImage.height}');
    } else {
      debugPrint('Cropped File: ${croppedFile
          .path} -> 画像をデコードできませんでした');
    }

    img.Image? image = img.decodeImage(cropBytes);  // 画像をデコード
    //img.Image resized = img.copyResize(image!, width: 600, height: 448);  // 解像度を指定してリサイズ
    img.Image resized = img.copyResize(image!, width: 800, height: 480);  // 解像度を指定してリサイズ
    Uint8List resizedBytes = Uint8List.fromList(img.encodeJpg(resized));

    //次の画面に渡す
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectCheck(imageData: [resizedBytes]),
      ),
    );
  }
}
