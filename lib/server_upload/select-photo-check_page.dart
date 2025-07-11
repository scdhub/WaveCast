//選択した画像をpng形式に保存し、そのpng画像をサーバへ出力する処理

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iphone_bt_epaper/theme.dart';
// import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bt_connect_page/connect_bt_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class SelectCheck extends StatefulWidget {
  final List<Uint8List?> imageData;

  const SelectCheck({Key? key, required this.imageData}) : super(key: key);

// class SelectCheck extends StatefulWidget {
//   final List<Uint8List?> imageData;
//   const SelectCheck({Key? key, required this.imageData});

  @override
  State<SelectCheck> createState() => _SelectCheckState();
}

class _SelectCheckState extends State<SelectCheck> {
  Uint8List? path; //　選択中の画像を表示する
  bool _isWriting = false; //　書き込み中確認用
  final List<File> files = [];
  // final ScrollController _scrollController = ScrollController(); // 横スクロール用コントローラー
  List<Uint8List?> selectedImages = []; // 複数選択を管理するリスト
  int count = 1; //png形式に変換する為にファイルとして、画像を保存する必要がある
  // final List<File> files = [];

  // 最初の画像を選択状態にする
  @override
  void initState() {
    super.initState();
    if (widget.imageData.isNotEmpty && widget.imageData[0] != null) {
      path = widget.imageData[0]; //前画面から渡された画像の最初の写真をよみとる
    }
    // path = widget.imageData[0]; //前画面から渡された画像の最初の写真をよみとる
    //渡されたデータを.pngファイル形式にする
    saveJpegImages();
  }

  //選択した画像に変更する
  //複数選択にて、左右アイコンをタップすると数秒画像が消えるため、スクロール処理完了後にパスを更新
  void changeImage(Uint8List selectedImage) {
    setState(() {
      path = selectedImage; // selectedImagesリストから1つの画像を選んでpathに設定
    });
  }

  // Jpeg形式に中身を変換後保存する処理
  // 保存+ファイル名を「.jpeg」にして保存している
  Future<void> saveJpegImages() async {
    // 保存先のディレクトリを取得する（アプリ側の内部ストレージ）
    final directory = await getApplicationDocumentsDirectory();
    for (int i = 0; i < widget.imageData.length; i++) {
      final Uint8List? data = widget.imageData[i];

      if (data != null) {
        // 先頭10バイトだけ抜き出す
        final headerBytes = data.sublist(0, 10);
        print('画像データ先頭バイト: $headerBytes');

        // 画像形式の判別例
        //　jpegファイルの最初にある識別子（マジックナンバー）を羅列
        if (headerBytes.length >= 8 &&
            headerBytes[0] == 137 &&
            headerBytes[1] == 80 &&
            headerBytes[2] == 78 &&
            headerBytes[3] == 71) {
          print('！！！！！！！！！！！！！！PNG画像');
        } else if (headerBytes.length >= 3 &&
            headerBytes[0] == 255 &&
            headerBytes[1] == 216 &&
            headerBytes[2] == 255) {
          print('！！！！！！！！！！！！！！JPEG画像です');
        } else {
          print('不明な画像フォーマットです');
        }
      }

      // ファイル名（.jpeg）の保存
      if (data != null) {
        // Uint8List processedData = cropImage(data);
        Uint8List processedData = data; // トリミングせずにそのまま保存
        final String fileName = 'image_$i.jpeg';
        // final String fileName = 'image_$i.png';
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(processedData);
        // filesリストに追加
        files.add(file);

        // 画像解像度確認
        Uint8List imageData = await file.readAsBytes();
        img.Image? image = img.decodeImage(imageData);
        if (image != null) {
          debugPrint(
              'File before upload: ${file.path} -> Width: ${image.width}, Height: ${image.height}');
        } else {
          debugPrint('File before upload: ${file.path} -> 画像をデコードできませんでした');
        }
      }
    }
  }

  // BTスキャン＆E-paper配信関連遷移時、位置情報取得許可
  Future<void> requestLocationPermission() async {
    // 位置情報の権限が許可されているか確認
    var status = await Permission.location.status;
    debugPrint("status.isGranted: ${status.isGranted}");
    if (!status.isGranted) {
      // 権限が許可されていない場合、リクエストする
      PermissionStatus permissionStatus =
          await Permission.locationWhenInUse.request();
      debugPrint("permissionStatus.isGranted: ${permissionStatus.isGranted}");
      debugPrint("permissionStatus.isDenied: ${permissionStatus.isDenied}");

      if (permissionStatus.isGranted) {
        // 権限が許可された場合
        debugPrint("Location permission granted");
      } else {
        // 権限が拒否された場合
        debugPrint("Location permission denied");

        if (permissionStatus.isDenied) {
          // 権限が拒否された場合
          debugPrint("Location permission is denied. Requesting again...");
        } else if (permissionStatus.isPermanentlyDenied) {
          // 権限が「永久に拒否された」場合、設定から手動で権限を変更してもらう必要があります
          debugPrint(
              "Location permission is permanently denied. Open settings to grant permission.");
          openAppSettings(); // 設定画面を開く
        }
      }
    } else {
      // すでに許可されている場合
      debugPrint("Location permission already granted");
    }
  }

  // // ダイアログを表示
  void uploadMessage() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            //  `setState` をグローバル変数に保存
            updateDialogState = setState;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // 角の丸み調整
              ),
              title: Center(
                child: _isWriting
                    ? const SizedBox() // 画像登録中はタイトルを表示しない
                    : Text(
                        '登録完了',
                        style: AppTheme.dialogTitleStyle, // タイトルのスタイル
                      ),
              ),
              content: Padding(
                // 余白の調整
                padding: const EdgeInsets.all(16.0), // ダイアログ内の余白
                child: SizedBox(
                  width: 250, // 幅を調整
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // コンテンツに合わせて高さを調整
                    children: [
                      //動作
                      if (_isWriting)
                        AppTheme
                            .customCircularProgressIndicator(), // 画像登録中にインジケーター表示
                      if (!_isWriting)
                        Text(
                          'BTスキャン＆E-paper配信関連に移りますか？',
                          style: AppTheme.dialogContentStyle, // 本文のスタイル
                        ),

                      const SizedBox(
                        height: 20,
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 「はい」ボタン
                          Expanded(
                            child: SizedBox(
                              width: 100, // ボタンの横幅を統一
                              child: ElevatedButton(
                                style: AppTheme.dialogYesButtonStyle,
                                // ボタンのスタイル
                                onPressed: _isWriting
                                    ? null // 画像登録中は無効
                                    : () async {
                                        await requestLocationPermission();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ConnectBTPage(),
                                          ),
                                        );
                                      },
                                child: const Text('はい',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10), // ボタン間に隙間を空ける
                          // 「いいえ」ボタン
                          Expanded(
                            child: SizedBox(
                              width: 100,
                              child: ElevatedButton(
                                style: AppTheme.dialogNoButtonStyle, // ボタンのスタイル
                                onPressed: _isWriting
                                    ? null // 画像登録中は無効
                                    : () {
                                        Navigator.of(context)
                                            .pop(); // ダイアログを閉じる
                                      },
                                child: const Text(
                                  'いいえ',
                                  // style: TextStyle(color: Colors.white,
                                  //     fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

// `StatefulBuilder` の `setState` を保存するためのグローバル変数
  late StateSetter updateDialogState;

// 画像アップロード処理を非同期で行う
  Future<void> _showWriteDialog() async {
    setState(() {
      _isWriting = true; // アップロード開始
    });
    uploadMessage(); // 進行中ダイアログを表示

    // サーバーに画像データを送る処理
    List<String> filePaths = files.map((file) => file.path).toList();

    try {
      await postData(filePaths);

      // アップロード完了後に状態を更新してダイアログの内容を切り替える
      setState(() {
        _isWriting = false; // アップロード完了
      });

      // // ダイアログの状態が切り替わるように更新
      // Navigator.of(context).pop(); // ダイアログを閉じる
      // uploadMessage(); // 完了ダイアログを表示（ダイアログは1回のみ）
    } catch (e) {
      setState(() {
        _isWriting = false; // アップロード失敗
      });
      Navigator.of(context).pop(); // ダイアログを閉じる
      missUploadMessage(); // アップロード失敗メッセージを表示
    }
  }

// // 画像アップロード処理を非同期で行う
//   //ここで二つ出てしまっている・・・
//   Future<void> _showWriteDialog() async {
//     setState(() {
//       _isWriting = true; // アップロード開始
//     });
//     uploadMessage(); // 1つめのダイアログを表示
//
//     // サーバーに画像データを送る処理
//     List<String> filePaths = files.map((file) => file.path).toList();
//
//     try {
//       await postData(filePaths);
//
//       // アップロード完了後に状態を更新してダイアログを閉じる
//       setState(() {
//         _isWriting = false; // アップロード完了
//       });
//
//       Navigator.of(context).pop(); // 1つめのダイアログを閉じる
//       // uploadMessage(); // ★　再度、完了ダイアログを表示
//
//     } catch (e) {
//       setState(() {
//         _isWriting = false; // アップロード失敗
//       });
//       Navigator.of(context).pop(); // ダイアログを閉じる
//       missUploadMessage(); // アップロード失敗メッセージを表示
//     }
//   }

  //サーバーとの接続確認後、登録失敗した時のメッセージを表示
  void missUploadMessage() {
    showDialog(
      barrierDismissible: false, //タップしても閉じない
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            titleTextStyle: AppTheme.errordialogTitleStyle,
            // エラーダイアログのタイトルスタイル
            contentTextStyle: AppTheme.errorContentStyle,
            // エラーダイアログの本文スタイル
            actionsAlignment: MainAxisAlignment.center,
            title: const Text(
              '登録エラー',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              '登録中に一時的な問題が発生しました。\nしばらくしてから再度お試しください。',
              // style: TextStyle(
              //   fontSize: 13,
              // ),
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              _isWriting
                  ? AppTheme.customCircularProgressIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          style: AppTheme
                              .errordialogButtonStyle, // エラーダイアログボタンスタイル
                          // TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
            ]);
      },
    );
  }

  //渡された画像を.png形式にする
  Future<void> savePrpcessedImages() async {
    final directory = await getApplicationDocumentsDirectory();

    for (int i = 0; i < widget.imageData.length; i++) {
      final Uint8List? data = widget.imageData[i];
      if (data != null) {
        final String fileName = 'image_$i.png'; // ファイル名を生成
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(data);
        files.add(file); // 保存したファイルをリストに追加
        if (kDebugMode) {
          print(files);
        }
      }
    }
  }

  //ファイルアップロード
  Future<void> postData(List<String?> uploadImages) async {
    //保存先URL
    Uri uri = Uri.parse(
        "https://3lewes86g0.execute-api.ap-northeast-1.amazonaws.com/dev/signed_url");
    //保存に必要な情報を定義
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': dotenv.get('API_KEY')
    };
    final body = {'images': uploadImages};
    // サーバーにpostする
    try {
      final response =
          await http.post(uri, headers: headers, body: jsonEncode(body));
      // 接続成功
      if (response.statusCode == 200) {
        // responseデータからデータを抜き取る
        final body = jsonDecode(response.body);
        final signedUrls = body['signed_urls'];
        for (var map in signedUrls) {
          for (var entry in map.entries) {
            if (kDebugMode) {
              print(entry);
            }
            // 画像パス
            final String imagePath = entry.key;
            // サーバーへのURL
            final String signedUrl = entry.value;
            final String filename = imagePath.split('/').last;
            putImageImpl(
                imagePath: imagePath, signedUrl: signedUrl, filename: filename);
          }
        }
        if (kDebugMode) {
          print('ファイルアップロード成功1！');
        }
      } else {
        if (kDebugMode) {
          print('ファイルアップロード失敗2: ${response.statusCode}');
        }
        setState(() {
          _isWriting = false;
          Navigator.of(context).pop();
          missAppSeverMessage(context);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      setState(() {
        _isWriting = false;
        Navigator.of(context).pop();
        missAppSeverMessage(context);
      });
    }
  }

  // 画像を保存する
  Future<void> putImageImpl(
      {required String imagePath,
      required String signedUrl,
      required String filename}) async {
    final file = File(imagePath); // Fileオブジェクトを作成
    final byteData = await file.readAsBytes(); // Fileオブジェクトからバイトデータを読み込む
    final List<int> bytes = byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

    try {
      final response = await http.put(
        Uri.parse(signedUrl),
        headers: {
          // Content-Typeを明示的にJPEGを指定
          'Content-Type': 'image/jpeg',
          // 'Content-Type': 'binary/octet-stream',
        },
        body: bytes,
      );
      print("Sending PUT request to $signedUrl");

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('ファイルアップロード成功2！');
          print('count: $count');
          count++;
        }

        // // ここで `uploadMessage();` を呼ばず、ダイアログは開いたまま更新する
        //       setState(() {
        //         _isWriting = false;
        //         Navigator.of(context).pop();
        //         UploadMessage();
        updateDialogState(() {
          _isWriting = false; // UIを更新（登録完了）
        });

        //[missUploadMessage]
        //エラーが発生した際にエラーメッセージを表示する関数であり、その目的が明確に伝わる名前にすることを意図
      } else {
        if (kDebugMode) {
          print('ファイルアップロード失敗3: ${response.statusCode}');
        }
        updateDialogState(() {
          _isWriting = false;
        });
        missUploadMessage();
      }
      //エラーメッセージ
    } catch (e) {
      updateDialogState(() {
        _isWriting = false;
      });
      missUploadMessage();
    }
  }

  // setState(() {
  //   _isWriting = false;
  //   Navigator.of(context).pop();
  //   uploadMessage();
  // });

  //     } else {
  //       if (kDebugMode) {
  //         print('ファイルアップロード失敗3: ${response.statusCode}');
  //       }
  //       setState(() {
  //         _isWriting = false;
  //         Navigator.of(context).pop();
  //         UploadMessage();
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isWriting = false;
  //       Navigator.of(context).pop();
  //       UploadMessage();
  //     });
  //   }
  // }

  // //書き込みダイアログを表示するための非同期
  // Future<void> _showWriteDialog() async {
  //   setState(() {
  //     _isWriting = true;
  //     uploadMessage();
  //   });
  //   // サーバーに画像データを送る
  //   List<String> filePaths = files.map((file) => file.path).toList();
  //   await postData(filePaths);
  // }

  // scrollImageメソッド
  Widget scrollImage(Uint8List pathN) {
    bool isSelected = selectedImages.contains(pathN); // 画像が選択されているかチェック

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.redAccent : Colors.white, // 選択された画像には赤い枠
        ),
      ),
      child: GestureDetector(
        child: Image.memory(
          pathN,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedImages.remove(pathN); // 既に選択されていたらリストから削除
            } else {
              selectedImages.add(pathN); // 新たに選択
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '画像登録確認',
          // style: TextStyle(fontSize: 20),
        ),
      ),
      body: Container(
        //CustomPaint(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        // painter: HexagonPainter(),
        child: Column(
          //SizedBox(
          mainAxisSize: MainAxisSize.min,
          // mainAxisAlignment: MainAxisAlignment.center, // 画面の幅に合わせる
          // 画面の高さに合わせるContainer(
          children: [
            //選択中の画像を表示.選択時の写真を大きく表示
            Expanded(
              //余白なくなり中央配置
              child: Center(
                child: path != null
                    ? Container(
                        width: 350, // 背景の固定サイズ（幅）
                        height: 400, // 背景の固定サイズ（高さ）
                        decoration: BoxDecoration(
                          color: Colors.black12, // 背景色

                          borderRadius: BorderRadius.circular(12),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: Colors.black26, // 影の色
                          //     blurRadius: 10, // ぼかし
                          //     offset: Offset(0, 4), // 影の位置（下にずらす）
                          //   ),
                          // ],
                        ),
                        padding: EdgeInsets.all(8),
                        child: Image.memory(
                          path!,
                          width: double.infinity, // 画面幅いっぱいにする
                          height: double.infinity, // 画面高さいっぱいにする
                          fit: BoxFit.contain, // 画像が収まるように調整
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
            // SizedBox(
            //   // color:Colors.greenAccent,
            //   width: 300, //300
            //   height: 350, //300
            //   child: Image.memory(
            //     path!, fit: BoxFit.cover,
            //   ),
            // ),

            // const SizedBox(height: 15,),

            // // 横スクロールリスト（左右ボタン付き：修正）
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     // 　「◀」　左アイコンボタン
            //     IconButton(
            //       icon: const Icon(Icons.chevron_left),
            //       onPressed: () {
            //         _scrollController.animateTo(
            //           _scrollController.position.minScrollExtent,
            //           duration: const Duration(milliseconds: 500),
            //           curve: Curves.easeInOut,
            //         ).then((_) {
            //           // スクロール完了後に画像を更新（スクロールボタン複数回連打で画像が数秒程、消えるため画像を固定）
            //           if (_scrollController.position.pixels == _scrollController.position.minScrollExtent) {
            //             setState(() {
            //               // 現在の最初の画像を選択
            //               path = widget.imageData[0];
            //             }
            //             );
            //           }
            //         }
            //         );
            //       },
            //       iconSize: 32,
            //       color: AppTheme.iconColor,
            //     ),
            //
            //     // 横スクロールする画像（修正）
            //     Flexible(
            //     child: SizedBox(
            //       height: 80, // 画像サイズに合わせる
            //       child: ListView.builder(
            //         scrollDirection: Axis.horizontal,
            //         itemCount: widget.imageData.length,
            //         physics: const BouncingScrollPhysics(),
            //         controller: _scrollController,
            //         itemBuilder: (context, index) {
            //           bool isSelected = path == widget.imageData[index];
            //
            //           return GestureDetector(
            //             onTap: () {
            //               changeImage(widget.imageData[index]!);
            //             },
            //             child: Container(
            //               decoration: BoxDecoration(
            //                 border: Border.all(
            //                   color: isSelected ? Colors.redAccent : Colors
            //                       .transparent,
            //                   width: 2,
            //                 ),
            //                 borderRadius: BorderRadius.circular(5),
            //               ),
            //               margin: const EdgeInsets.symmetric(horizontal: 4),
            //               child: Image.memory(
            //                 widget.imageData[index]!,
            //                 width: 80,
            //                 height: 80,
            //                 fit: BoxFit.cover,
            //               ),
            //             ),
            //           );
            //         },
            //       ),
            //     ),
            //     ),
            //
            //
            //
            //     // 「▶」右アイコンボタン（修正）
            //     IconButton(
            //       onPressed: () {
            //         _scrollController.animateTo(
            //           _scrollController.position.maxScrollExtent,
            //           duration: const Duration(milliseconds: 500),
            //           curve: Curves.easeInOut,
            //         ).then((_) {
            //           // スクロール完了後に画像を更新
            //           if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
            //             setState(() {
            //               // 現在の最後の画像を選択
            //               path = widget.imageData[widget.imageData.length - 1];
            //             });
            //           }
            //         });
            //       },
            //       icon: const Icon(Icons.chevron_right),
            //       iconSize: 32,
            //       color: AppTheme.iconColor,
            //     ),
            //   ],
            // ),
            //
            // const SizedBox(height: 15),
            // const Divider(),

            //横スクロールボタン（左アイコン）：過去
            // Row(children: [
            //   height: 40,
            //   width: 40,
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(30), // ここで角の丸みを指定
            //   color: Colors.grey, // 背景色
            // ),
            //
            // child: IconButton(
            //   // 押したら画像リストの最初の画像のある部分まで移動する
            //   onPressed: () {
            //     _scrollController.animateTo(
            //       _scrollController.position.minScrollExtent,
            //       duration: const Duration(seconds: 2),
            //       curve: Curves.fastOutSlowIn,
            //     );
            //   },
            //   icon: const Icon(
            //     Icons.chevron_left,
            //   ),
            // ),
            //   )],
            //   ),

            //横スクロールする画像リスト（右アイコン）：過去
            // Expanded(
            //     child: Container(
            //   width: MediaQuery.of(context).size.width,
            //   height: 100,
            //   color: Colors.white38,
            //
            //   // color: Colors.white,
            //   child: ListView.builder(
            //     scrollDirection: Axis.horizontal,
            //     //横にスクロールできるようにする
            //     itemCount: widget.imageData.length,
            //     physics: const BouncingScrollPhysics(),
            //     controller: _scrollController,
            //     itemBuilder: (context, index) {
            //       return Padding(
            //         padding: const EdgeInsets.symmetric(
            //           horizontal: 8.0,
            //           vertical: 4.0,
            //         ),
            //         child: scrollImage(widget.imageData[index]!),
            //       );
            //     },
            //   ),
            // ),
            // ),

            // 登録選択のデザイン
            // Container(
            //   height: 35,
            //   width: 35,
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(30), // ここで角の丸みを指定
            //     color: Colors.grey, // 背景色
            //   ),
            // child: IconButton(
            //   // 押したら最後の画像がある部分まで移動する
            //   onPressed: () {
            //     _scrollController.animateTo(
            //       _scrollController.position.maxScrollExtent,
            //       duration: const Duration(seconds: 2),
            //       curve: Curves.fastOutSlowIn,
            //     );
            //   },
            //   icon: const Icon(Icons.chevron_right,
            //       color: Colors.black),
            //     // ),
            //   ),
            // ),
            // const Divider(),

            //選択後のポップアップ、「登録しますか？」とボタン
            Container(
              width: double.infinity, //画面幅いっぱいに広げる
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              // decoration: const BoxDecoration(
              //   color: Color.fromARGB(221, 57, 57, 57),
              //   borderRadius: BorderRadius.only(
              //     topLeft: Radius.circular(30.0),
              //     topRight: Radius.circular(30.0),
              //     bottomLeft: Radius.circular(30.0),
              //     bottomRight: Radius.circular(30.0),
              //   ),
              // ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Text(
                    '画像をアプリに登録しますか？',
                    style: TextStyle(
                      fontSize: 18, //30
                      color: Color(0xFF29B6F6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  //padding: const EdgeInsets.all(20.0),
                  // child: Column(
                  //     mainAxisAlignment: MainAxisAlignment.spaceAround,
                  //     mainAxisSize: MainAxisSize.min,
                  //     children: [
                  //       Text('アプリに登録する',
                  //           style: TextStyle(
                  //               fontSize: 24,//30
                  //               color: Colors.white,
                  //               fontWeight: FontWeight.bold)),

                  //「登録する」ボタン
                  SizedBox(
                    width: double.infinity, //横幅
                    height: 50, //高さ
                    child: ElevatedButton(
                      onPressed: path == null
                          ? null // 何も選択していない場合は無効
                          : () {
                              _showWriteDialog();
                            },
                      //   onPressed: () {
                      //   _showWriteDialog(); // 画像アップロード処理を開始
                      // },
                      // _isWriting ? null : _showWriteDialog,
                      style: AppTheme.dialogYesButtonStyle,
                      child: const Text(
                        '登録する', //Ok
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),

                  //「登録しない」ボタン
                  SizedBox(
                    width: double.infinity, //横幅
                    height: 50, //50 高さ
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: AppTheme.dialogNoButtonStyle,
                      child: const Text(
                        '登録しない', //キャンセル
                        style: TextStyle(fontSize: 16), //28
                      ),
                    ),
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

//                                     )),
//                               ),
//                             ),
//                           ]),
//                     )),
//               ]))));
// }

// //画面上部表示中の画像のListView内での表示
// Widget scrollImage(Uint8List pathN) {
//   return Container(
//     decoration: BoxDecoration(
//         border: Border.all(
//       // 選択している画像は周りを赤くする
//       color: path == pathN ? Colors.redAccent : Colors.white,
//     )),
//     child: GestureDetector(
//       child: Image.memory(
//         pathN,
//         width: 100,
//         height: 100,
//         fit: BoxFit.cover,
//       ),
//       // タップした画像に切り替える
//       onTap: () {
//         if (path != pathN) changeImage(pathN);
//       },
//     ),
//   );
// }

//サーバーとの接続ができなかった時のエラーメッセージ表示
void missAppSeverMessage(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Center(
          child: Text(
            '登録エラー',
            style: AppTheme.errordialogTitleStyle, // エラースタイルを使用
          ),
        ),
        //エラーメッセージ
        content: Padding(
          padding: const EdgeInsets.all(8.0), // 少し余白をつけて調整
          child: SizedBox(
            width: 250, // ダイアログ内の幅を設定
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 中央揃え
              crossAxisAlignment: CrossAxisAlignment.center, // 横方向も中央揃え
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'サービスが一時的に\n利用できません。',
                  style: AppTheme.errorContentStyle, // エラースタイルを使用
                  textAlign: TextAlign.center, // テキストを中央揃え
                ),
                const SizedBox(height: 8), // 段落間に少しスペースを追加
                Text(
                  'しばらくしてから\n再度お試しください。',
                  style: AppTheme.errorContentStyle, // エラースタイルを使用
                  textAlign: TextAlign.center, // テキストを中央揃え
                ),

                // const Text
                //   (
                //   'サービスが一時的に\n利用できません。'
                //       '\nしばらくしてから\n再度お試しください。',
                //
                //   style: TextStyle(
                //     color: Colors.black,
                //     fontSize: 16,
                //   ),
                //   textAlign: TextAlign.center,
                // ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: AppTheme.errordialogButtonStyle,
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
