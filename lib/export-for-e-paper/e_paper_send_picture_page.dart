// 画像を送信して電子ペーパーに送る処理
// wifi,ble通信

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/server_get-image.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/server_image_delete_check_popup.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/sever_data_bind.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'bluetooth_connection_state.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http/http.dart' as http; // ← MultipartRequest
import 'package:http_parser/http_parser.dart'; // ← MediaType
import 'package:path/path.dart' as path;

import '../theme.dart';

class SendPictureSelect extends StatefulWidget {
  final BluetoothDevice deviceInfo;
  final BluetoothDevice trustDevice;

  final String trustName;

  final CacheManager? cacheManager;
  const SendPictureSelect(
      {super.key,
      required this.deviceInfo,
      required this.trustDevice,
      required this.trustName,
      this.cacheManager});

  @override
  State<StatefulWidget> createState() => _SendPictureSelect();
}

//サーバーへデータを送るところ
class _SendPictureSelect extends State<SendPictureSelect> {
  List<ImageItem> imageItems = []; // サーバーデータ
  List<ImageItem> _items = []; // 表示使用用画像リスト
  List<ImageItem> _deleteItems = []; // 削除用選択リスト
  List<BluetoothService> services = []; //接続したデバイスのサービス情報を読み取る
  final List<bool> selectedMode = [true, false]; // 画像操作Button用リスト
  String? sortItemLis = 'new'; // 画像順表示名　初期：新しい順
  int selectedModeIndex = 1;
  bool deleteMode = false; // 画面操作状態、削除状態切り替え
  bool selectedItem = false; // 画像選択状態
  bool isLoading = true; // 画像読込状態
  bool isConnected = false; // BLE処理状態
  double? progressPercent = 0.0; // LinearProgressIndicator(value)
  bool isSending = false; // LinearProgressIndicator()表示状態
  String? resultTitle; // sdk異常終了時エラーメッセージタイトル
  String? resultContext; // sdk異常終了時エラーメッセージ内容
  String connectionState = "disconnect"; // BL接続状態
  // メッセージに基づく処理をマッピングするための Map
  late final Map<String, Future<void> Function(Map<String, dynamic>)>
      _messageHandlers;

  List<ReversedData> reverseData = []; //サーバーデータ：新しい順 // 未使用
  List<DateSort> dateSort = []; //日付並び替え  // 未使用

  //********************* BLE通信を行う場合 *************************
  //_createImageTapの遷移先をsendImagePictureBLEに変更
  //チャンクサイズ
  int chunkSize = 180;

  //　チャンネル登録中（URL）
  //1.PibLE-Bluezero
  // final Guid service_UUID = Guid("12345678-1234-5678-1234-56789abcdef0");
  // final Guid char_UUID = Guid("12345678-1234-5678-1234-56789abcdef1");

  //1.PibLE-Bluezero
  final Guid service_UUID = Guid("12345678-1234-5678-1234-55555abcdef0");
  final Guid char_UUID = Guid("12345678-1234-5678-1234-55555abcdef1");
  int totalSentBytes = 0;
  //****************************************************************

  //********************* Wi-Fi通信を行う場合 ***************************
  //_createImageTapの遷移先をsendImagePictureWifiに変更
  // 今後修正（固定値になっているので）
  final String server_Url = "http://192.168.200.58:5000/upload";
  // final String server_Url = "http://192.168.200.36:5000/upload";
  bool _showIndicator = false;
  DateTime? _startTime;
  //進捗インジケータUI
  // Timer? _countdownTimer;
  // int _remainingSeconds = 30;
  //*****************************************************************


  //　チャンネル登録中（URL）
  static const platform = MethodChannel('com.example.iphone_bt_epaper/channel');

  // SDKcallback_message
  static const BasicMessageChannel<String> _channel =
      BasicMessageChannel<String>(
          'com.example.iphone_bt_epaper/channel', StringCodec());

  @override
  void initState() {
    super.initState();
    initialize();
    // //　全画面表示してナビゲーションバー非表示にし、かぶらないようにする
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // メッセージに基づいて処理をマッピング
    _messageHandlers = {
      "onSetupSDKFailed": _handleSetupSDKFailed,
      "onBLEDeviceConnectComplete": _handleBLEDeviceConnectComplete,
      "onBLEDeviceConnectFailed": _handleBLEDeviceConnectFailed,
      "onBLEDeviceDisconnect": _handleBLEDeviceDisconnect,
      "onBLEDeviceCancelFailed": _handleBLEDeviceCancelFailed,
      "onSendImageToDeviceComplete": _handleSendImageToDeviceComplete,
      "onSendImageToDeviceFailed": _handleSendImageToDeviceFailed,
      "onSendImageToDeviceProgress": _handleSendImageToDeviceProgress,
      "onBLEDeviceConnectCanceled": _handleBLEDeviceConnectCanceled,
    };

    // メッセージを受信するリスナーを設定
    _channel.setMessageHandler((String? message) async {
      debugPrint("receiveMessage: $message");
      await handleReceivedMessage(message);
      return "";
    });
  }

  // メッセージ受信後の処理
  Future<void> handleReceivedMessage(String? message) async {
    if (message != null) {
      // 受信した JSON を `Map<String, dynamic>` に変換
      final Map<String, dynamic> decodedData = jsonDecode(message);
      // メッセージのcallbackNameを取得
      final String? callbackName = decodedData["callbackName"];

      if (callbackName != null) {
        // マッピングされた処理を実行
        final handler = _messageHandlers[callbackName];
        if (handler != null) {
          await handler(decodedData);
        } else {
          debugPrint("Unknown message callbackName: $callbackName");
        }
      } else {
        debugPrint("Error: No 'callbackName' field in message");
      }
    }
  }

  // 各メッセージ受信後処理関数
  Future<void> _handleSetupSDKFailed(Map<String, dynamic> data) async {
    setState(() {
      isConnected = false;
    });
    callSdkMessage(data);
  }

  Future<void> _handleBLEDeviceConnectComplete(
      Map<String, dynamic> data) async {
    connectionState = "connected";
  }

  Future<void> _handleBLEDeviceConnectFailed(Map<String, dynamic> data) async {
    setState(() {
      isConnected = false;
    });
    callSdkMessage(data);
  }

  Future<void> _handleBLEDeviceDisconnect(Map<String, dynamic> data) async {
    connectionState = "disconnect";
    setState(() {
      isConnected = false;
    });
  }

  Future<void> _handleBLEDeviceCancelFailed(Map<String, dynamic> data) async {
    callSdkMessage(data);
  }

  Future<void> _handleSendImageToDeviceComplete(
      Map<String, dynamic> data) async {
    progressPercent = 0.0;
    setState(() {
      isSending = false;
    });
  }

  Future<void> _handleSendImageToDeviceFailed(Map<String, dynamic> data) async {
    progressPercent = 0.0;
    setState(() {
      isSending = false;
    });
    callSdkMessage(data);
  }

  Future<void> _handleSendImageToDeviceProgress(
      Map<String, dynamic> data) async {
    setState(() {
      isSending = true;
      progressPercent = 0.0;
      // progressPercent = (data['progressPercent'] ?? 0) / 100;
      debugPrint("LinearProgressIndicator progressPercent: $progressPercent");
    });
  }

  Future<void> _handleBLEDeviceConnectCanceled(
      Map<String, dynamic> data) async {
    connectionState = "disconnect";
    setState(() {
      isConnected = false;
    });
    callSdkMessage(data);
  }

  // Future<void> _handleSendImageToDeviceCanceled(
  //     Map<String, dynamic> data) async {
  //   progressPercent = 0.0;
  //   setState(() {
  //     isSending = false;
  //   });
  //   callSdkMessage(data);
  // }

  Future<void> initialize() async {
    // 画像取得
    await getImage(
      context: context,
      imageItems: imageItems,
      reverseData: reverseData, // 未使用
      dateSort: dateSort, // 未使用
    );
    setState(() {
      // 画像順ソート new->old
      imageItems.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      isLoading = false;
      _items = imageItems;
    });
  }

  //サーバー接続（★★ここかな？？？）
  Future onDiscoverServicesPressed({required String sendImage}) async {
    debugPrint('登録処理');
    //目的UUID
    // BluetoothCharacteristic? targetCharacteristic;
    try {
      // デバイスと接続する
      await widget.deviceInfo.connect();

      if (kDebugMode) {
        print('コネクト成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('コネクト失敗：$e');
      }
    }
    try {
      // デバイスのサービス情報を読み取る
      services = await widget.deviceInfo.discoverServices();
/*
       //E-Paperの画像を書き込むUUIDを見つける
       for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == "目的のCharacteristicのUUID") {
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) break;
      }
  */
      if (kDebugMode) {
        print('サービス情報を読み取り成功');
        print('$services');
        print(sendImage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('サービス情報を読み取り失敗:$e');
      }
    }
    /*
   //ここでSDKサーバーに画像配信要求(画像ID）を発行する。
   //リクエストに指定する画像IDは「sendImage」で取得できます
   //　以下のWriteは応答後に行う。
    //E-Paperの特定のcharacteristicに書き込む
     try{
       if (targetCharacteristic != null) {
      // ここは応答時に実行するコード（書き込むデータはサーバーから取得した変換後のデータを指定）
         await targetCharacteristic.write('', withoutResponse: false);
       }
     }catch(e){
       print('目的のCharacteristicが見つかりませんでした');
     }
    */
    //デバイスとの接続を切る
    await widget.deviceInfo.disconnect();
  }

  // BL接続　ボタン押下時にここから送信画面に進んでいく
  void callNativeMethod(url) {
    debugPrint("send image url: ${url}");
    try {
      debugPrint("call Kotlin");
      platform.invokeMethod('callSdk',
          {'deviceName': '${widget.trustName}', 'imageUrl': '${url}'});
    } on PlatformException catch (e) {
      debugPrint("Failed to call native method: '${e.message}'.");
    }
  }

  // 削除時に画像一覧を更新する関数
  Future<void> fetchData(status) async {
    if (mounted) {
      setState(() {
        // 削除成功時、サーバーから再取得しないで初期取得Listから削除->再描画
        // 削除失敗時、削除リストのみ初期化(✓マークリセットの再描画)
        // キャッシュをクリアして画像を削除
        if (status == 200) {
          for (int i = 0; i < _deleteItems.length; i++) {
            _items.removeWhere((v) => v.id == _deleteItems[i].id);

            // 画像キャッシュ削除
            DefaultCacheManager().removeFile(_items[i].url);
            CachedNetworkImage.evictFromCache(_items[i].url);
          }
        }
        _deleteItems.clear();
        _items = List.from(imageItems); //更
      });
      _deleteItems.clear();
      // imageCache.clear();
      // imageCache.clearLiveImages();
      // initialize();  // initialize() を呼び出して、再度画像リストを取得
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Stack(children: [
      Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('配信用登録画像一覧'),
          actions: [
            Container(
              child: BluetoothConnection(connectionState), // BL接続状況表示
            )
          ],
        ),
        body: Column(
          children: [
            // AppBar下の固定バー
            Container(
              height: AppBar().preferredSize.height,
              width: MediaQuery.of(context).size.width,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ToggleButtons(
                    color: Colors.blue,
                    fillColor: Colors.blue[300],
                    borderColor: Colors.blue[100],
                    splashColor: Colors.blue[300],
                    selectedBorderColor: Colors.blue[800],
                    selectedColor: Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    constraints: BoxConstraints(
                        minHeight: AppBar().preferredSize.height * 0.65,
                        minWidth: MediaQuery.of(context).size.width / 5),
                    isSelected: selectedMode,
                    onPressed: (int index) {
                      setState(() {
                        if (index == 0) {
                          selectedMode[0] = true;
                          selectedMode[1] = false;
                          deleteMode = false;
                        } else {
                          selectedMode[0] = false;
                          selectedMode[1] = true;
                          deleteMode = true;
                        }
                        if (!deleteMode) {
                          _deleteItems.clear();
                        }
                      });
                    },
                    children: const [
                      Row(
                        children: [Icon(Icons.ios_share), Text('  配信')],
                      ),
                      Row(
                        children: [Icon(Icons.delete), Text('  削除')],
                      )
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        '表示順：',
                        style: TextStyle(
                          color: Colors.blue,
                        ),
                      ),
                      DropdownButton(
                        // 画像ソート順選択
                        items: const [
                          DropdownMenuItem(
                            value: 'new',
                            child: Text(
                              '新しい順',
                              style: TextStyle(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'old',
                            child: Text(
                              '古い順',
                              style: TextStyle(
                                color: Colors.blue,
                              ),
                            ),
                          )
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            if (sortItemLis != value) {
                              sortItemLis = value; // 画像順ソートドロップダウンtitle
                              _items = _items.reversed.toList();
                              _deleteItems.clear();
                            }
                          });
                        },
                        value: sortItemLis,
                        underline: Container(
                          height: 1,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
                child: Center(
                    child: isLoading
                        ? AppTheme
                            .customCircularProgressIndicator() // ローディング中はインジケーターを表示
                        : Container(
                            child: _items.isEmpty
                                ? NonServerPictureMess()
                                : _createGridView())))
          ],
        ),
        persistentFooterButtons: deleteMode
            ? (_deleteItems.isNotEmpty)
                ? [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _deleteItems = List.from(_items); // すべて選択
                        });
                      },
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(90, 50), //幅,高
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF29B6F6)),
                      child: const Text('全選択',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _deleteItems.clear(); // すべて解除
                        });
                      },
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(125, 50),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF29B6F6)),
                      child: const Text('全選択解除',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        for (var item in _deleteItems) {
                          if (kDebugMode) {
                            print(
                                'ID: ${item.id}, URL: ${item.url}, Last Modified: ${item.lastModified}');
                          }
                        }
                        await showDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (context) => ServerImageDelCheckPopup(
                              selectDelImage: _deleteItems,
                              fetchData: fetchData),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(50, 50),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF29B6F6)),
                      child: const Text('削除',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ]
                : null
            : null,
      ),
      if (isConnected)
        const Positioned.fill(
            child: ModalBarrier(
          color: Colors.black54,
          dismissible: false, // ユーザー操作をブロック
        )),
      if (isConnected && !isSending)
        Center(child: AppTheme.customCircularProgressIndicator()),
      if (isConnected && isSending)
        Center(
          child: Container(
            width: 300,
            height: 15,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (progressPercent ?? 0.0) * 0.95,
                backgroundColor: Colors.transparent, //透明
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60DD72)),
              ),
            ),
          ),
        ),
    ]);
  }

  // 画像表示View
  Widget _createGridView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisSpacing: 3.0, // 縦の空間
        mainAxisSpacing: 4.0, // 横の空間
        crossAxisCount: 3,
      ),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        bool isSelected = false;
        return _createImageTap(index, isSelected);
      },
    );
  }

  // 画像onTap操作
  Widget _createImageTap(index, isSelected) {
    return GestureDetector(
      onTap: deleteMode
          ? () {
              // 画像削除時複数選択処理
              // 画像選択/解除判定　削除リストに追加されているか確認
              isSelected = _deleteItems.any((v) => v.id == _items[index].id);
              // 選択✓マーク表示のためsetState()
              setState(() {
                if (isSelected) {
                  // 選択解除処理
                  // 削除リストから削除
                  _deleteItems.removeWhere((v) => v.id == _items[index].id);
                } else {
                  // 選択処理
                  // 削除リストに追加
                  _deleteItems.add(_items[index]);
                }
              });
            }
          : () {
              // 画像登録処理
              selectImageCheckDialog(
                  context: context,
                  imageUrl: _items[index].url,
                  onSendOK: () {
                    debugPrint(
                        "■ sending to trustName=${widget.trustName}, IP=${widget.deviceInfo}");
                    // callNativeMethod(_items[index].url);//電子ペーパに送るときはここ
                     //sendImagePictureBle(_items[index ].url); //BLE通信をしたいときはここ
                    sendImagePictureWifi(_items[index].url); //wifi通信をしたいときはここ
                  });
            },
      child: _createCheckMark(index, isSelected),
    );
  }

  // 画像表示
  Widget _createCheckMark(index, isSelected) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26, width: 1), // 青色の枠線
      ),
      child: Stack(children: <Widget>[
        CachedNetworkImage(
          key: ValueKey(_items[index].url),
          //キャッシュを更新するためのキー
          imageUrl: _items[index].url,
          cacheManager: DefaultCacheManager(),
          //キャッシュマネージャーを統一
          width: 200,
          height: 200,
          errorWidget: (context, url, error) => const Icon(Icons.error),
          // 画像エラー時のウィジェット
          fit: BoxFit.contain,
        ),
        // ✓マーク表示
        if (isSelected = _deleteItems.any((v) => v.id == _items[index].id))
          Stack(
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              Positioned.fill(
                  child: Padding(
                padding: EdgeInsets.all(isSelected ? 10.0 : 0.0),
                child: CachedNetworkImage(
                  imageUrl: _items[index].url,
                ),
              )),
              Positioned.fill(
                  child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Icon(Icons.check_circle,
                          size: 30, color: Colors.white //.withOpacity(0.8),
                          )))
            ],
          )
      ]),
    );
  }

// class DialogHelper{
  void selectImageCheckDialog(
      {required BuildContext context,
      required String imageUrl,
      required Function onSendOK}) {
    showDialog(
      barrierDismissible: false, //dialog以外の部分をタップしても消えないようにする。
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Align(
            alignment: Alignment.center, // タイトルを中央に寄せる
            child: Text(
              '選択画像を配信しますか？',
              style: AppTheme.dialogContentStyle, // 本文のスタイル
            ),
          ),
          // content: Column(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 250,
                height: 200,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12, width: 2)),
                child: FadeInImage.memoryNetwork(
                  placeholder: kTransparentImage,
                  image: imageUrl,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
                  // mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: 100, // ボタンの横幅を統一
                        child: ElevatedButton(
                          style: AppTheme.dialogYesButtonStyle,
                          onPressed: () {
                            onSendOK();
                            setState(() {
                              isConnected = true;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("はい",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: SizedBox(
                      width: 100,
                      child: ElevatedButton(
                          style: AppTheme.dialogNoButtonStyle,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("いいえ")),
                    ))
                  ]),
            ],
          ),
        );
      },
    );
  }

  void callSdkMessage(Map<String, dynamic> data) {
    resultTitle = data['callbackName'];
    resultContext = data['message'];
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              titleTextStyle: AppTheme.errordialogTitleStyle,
              // エラーダイアログのタイトルスタイル
              contentTextStyle: AppTheme.errorContentStyle,
              // エラーダイアログの本文スタイル
              actionsAlignment: MainAxisAlignment.center,
              title: Text(
                resultTitle ?? "",
                textAlign: TextAlign.center,
              ),
              content: Text(
                resultContext ?? "",
                textAlign: TextAlign.center,
              ),
              actions: <Widget>[
                ElevatedButton(
                  style: AppTheme.errordialogButtonStyle, // エラーダイアログボタンスタイル
                  // TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ]);
        });
  }

  // 選択画像をRBPへ転送する処理
  Future<void> sendImagePictureBle(String url) async {
    setState(() => isSending = true);

    try {
      // 画像取得：指定された URL のファイルを取得
      final file = await (widget.cacheManager ?? DefaultCacheManager())
          .getSingleFile(url);
      final imageBytes = await file.readAsBytes();

      final headerBytes = imageBytes.sublist(0, 10);
      print('ファイルの先頭バイト: $headerBytes');

      //　計測開始、処理終わるところに停止を置いてるので差をprint
      final stopwatch = Stopwatch()..start();

      //　バイト列 + EOF
      final payload = imageBytes;
      // final eof = utf8.encode('<<EOF>>');

      // 接続＆キャラクタリスティック取得
      final device = widget.trustDevice;
      //　接続
      await device.connect(autoConnect: false);

      //追加：MTUを大きくし通信速度を速める
      await device.requestMtu(185);

      //serviceとキャラクタリスティックを探す
      final services = await device.discoverServices();
      final char = services
          .firstWhere((s) => s.uuid == service_UUID)
          .characteristics
          .firstWhere((c) => c.uuid == char_UUID);

      // 分割送信をおこなう　chunksizeは180
      for (int offset = 0; offset < payload.length; offset += chunkSize) {
        final int end = (offset + chunkSize < payload.length)
            ? offset + chunkSize
            : payload.length;
        final chunk = payload.sublist(offset, end);

        //　バイト数計算
        await char.write(chunk, withoutResponse: true);
        totalSentBytes += chunk.length;

        // 進捗更新（doubleへのキャストが必要）
        setState(() => progressPercent = end / payload.length);

        print('chunk [$offset..$end) = ${chunk.length} bytes');
        await Future.delayed(const Duration(milliseconds: 1));
      }


      // 合計バイト数表示
      // print('合計送信バイト数: $totalSentBytes bytes');

      // タイマー停止
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsed.inMilliseconds;
      final minutes = elapsedMs ~/ 60000;
      final seconds = (elapsedMs % 60000) ~/ 1000;
      debugPrint('送信完了までの時間: ${minutes}分${seconds}秒（${elapsedMs} ms）');
    } catch (e) {
      debugPrint('送信中エラー: $e');
    } finally {
      // 切断＆ステート更新させるとこ
      try {
        await widget.trustDevice.disconnect();
      } catch (_) {}
      setState(() {
        isSending = false;
        // インジゲーターが止まる処理
        isConnected = false;
        connectionState = 'disconnect';
        progressPercent = 0.0;
      });
    }
  }

// wifi通信を行う際の処理
  void sendImagePictureWifi(String imageUrl) async {
    _startTime = DateTime.now();
    setState(() {
      isConnected = true;
      isSending = true;
      progressPercent = 0.0;
    });

    const duration = Duration(milliseconds: 100);
    int counter = 0;
    const maxCount = 340;

    Timer.periodic(duration, (Timer timer) {
      counter++;
      setState(() {
        progressPercent = (counter / maxCount).clamp(0.0, 1.0);
      });

      if (counter >= maxCount) {
        timer.cancel();
        setState(() {
          progressPercent = 0.0; // ★ここでリセット
        });
      }
    });

    try {
      // まずimageUrl を使ってキャッシュからファイル取得
      final file = await (widget.cacheManager ?? DefaultCacheManager())
          .getSingleFile(imageUrl);
      final imageBytes = await file.readAsBytes();

      // ファイル名を抽出する際は明示的にしないと送信の際に形式が変わってしまうケースがある。
      final String fileName = 'image_${DateTime.now().toIso8601String()}.jpg';
      //　こっちだと形式が正しく表示されず間違った形式で送信された。
      // final String fileName = path.basename(file.path);

      // リクエストの組み立て
      final uri = Uri.parse(server_Url);
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: fileName, // 明示的に .jpg をつけないとandroidは.octet-streamで飛ばされる
             // contentType: MediaType('image', 'bmp'),
            contentType: MediaType('image', 'jpg'),
          ),
        );

      // 画像を送信する（リクエスト送信）
      final streamedResponse = await request.send();

      //以下は成功失敗、インジケーターの停止などのUI側処理
      // ステースチェックを行う
      if (streamedResponse.statusCode == 200) {
        debugPrint(" Wi‑Fi通信に成功しました");
      } else {
        debugPrint(" Wi‑Fi通信に失敗しました: ${streamedResponse.statusCode}");
      }
    } catch (e) {
      debugPrint(" Wi‑Fi 通信エラー: $e");
      // _countdownTimer?.cancel();
      // setState(() => _showIndicator = false);｝｝
    } finally {
      setState(() => isSending = false);
    }
    try {
      await widget.trustDevice.disconnect();
    } catch (_) {}
    setState(() {
      isSending = false;
      isConnected = false;
      connectionState = 'disconnect';
      // progressPercent = 0.0;
    });
  }
}

class NonServerPictureMess extends StatelessWidget {
  const NonServerPictureMess({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Stack(alignment: Alignment.center, children: [
        Icon(
          Icons.warning_amber_outlined,
          color: Colors.white38,
          size: 300,
        ),
        Text(
          '　　登録画像がありません\n\nまずは画像を登録しましょう！',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ]),
    );
  }
}
