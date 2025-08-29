// 画像を送信して電子ペーパーに送る処理
// wifi,ble通信を選択。

import 'dart:async';
import 'dart:convert';
// import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/server_get-image.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/server_image_delete_check_popup.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/sever_data_bind.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// import '../service/socket_service.dart';
import 'bluetooth_connection_state.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http/http.dart' as http; // MultipartRequest
import 'package:http_parser/http_parser.dart'; // MediaType
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart' show Dio, FormData, MultipartFile;

import '../theme.dart';

// SendPictureSelect() を使っているすべての箇所で、それぞれの引数を渡さないとエラー になる
// wifi通信とBLE通信を切り分ける際に、引数で判別するように修正する。
// class SendPictureSelect extends StatefulWidget {
// final BluetoothDevice deviceInfo;
// final BluetoothDevice trustDevice;
// final String trustName;
// final CacheManager? cacheManager;

// const SendPictureSelect(
// {super.key,
// required this.deviceInfo,
// required this.trustDevice,
// required this.trustName,
// this.cacheManager});

class SendPictureSelect extends StatefulWidget {
  // BLE通信で必要なもの
  final BluetoothDevice? deviceInfo;
  final BluetoothDevice? trustDevice;
  final String? trustName;
  // wifi通信で必要なもの
  final String? ipAddress;
  //　画像などの削除を行う際に必要なキャッシュ削除
  final CacheManager? cacheManager;

  SendPictureSelect({
    Key? key,
    this.deviceInfo,
    this.trustDevice,
    this.trustName,
    this.ipAddress,
    this.cacheManager,
  }) : super(key: key) {
    // どんな情報が渡されているのかをチェック、ipaddress=nullで他もすべてnullならエラーで返す
    if ((ipAddress == null) &&
        (deviceInfo == null || trustDevice == null || trustName == null)) {
      throw ArgumentError(
          'Either ipAddress (Wi-Fi) or deviceInfo+trustDevice+trustName (BLE) must be provided.');
    }
  }

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
  int totalSentBytes = 0;

  //1.PibLE-Bluezero
  // final Guid service_UUID = Guid("12345678-1234-5678-1234-56789abcdef0");
  // final Guid char_UUID = Guid("12345678-1234-5678-1234-56789abcdef1");

  //2.PibLE-Bluezero2
  final Guid service_UUID = Guid("12345678-1234-5678-1234-55555abcdef0");
  final Guid char_UUID = Guid("12345678-1234-5678-1234-55555abcdef1");

//*****************************************************************

  //　チャンネル登録中（URL）
  static const platform = MethodChannel('com.example.iphone_bt_epaper/channel');
  static const wifiplatform = MethodChannel('com.example.wifi/helper');

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

  // Wi-Fi 状態を問い合わせる
  Future<Map<String, dynamic>> checkWifiStatusNative() async {
    try {
      final res = await wifiplatform.invokeMethod<dynamic>('checkWifiReady');
      if (res == null) return {'status': 'UNKNOWN'};

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      // まれに JSON 文字列が返る場合があるためフォールバックを使用
      if (res is String) {
        try {
          return jsonDecode(res) as Map<String, dynamic>;
        } catch (_) {
          return {'status': 'UNKNOWN', 'raw': res};
        }
      }
      return {'status': 'UNKNOWN'};
    } on PlatformException catch (e) {
      debugPrint('[checkWifiStatusNative] PlatformException: ${e.message}');
      return {'status': 'ERROR', 'message': e.message};
    } catch (e) {
      debugPrint('[checkWifiStatusNative] error: $e');
      return {'status': 'ERROR', 'message': e.toString()};
    }
  }

  // サーバへのソケット接続を試み、結果と失敗時はエラーメッセージを返す
  Future<Map<String, dynamic>> checkServerReachable(String ip,
      {int port = 5000,
        Duration timeout = const Duration(milliseconds: 350)}) async {
    try {
      //　socket.connectでソケット通信を行う
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return {'ok': true};
    } on SocketException catch (e) {
      return {
        'ok': false,
        'error': 'SocketException: ${e.message}',
        'type': 'socket'
      };
    } on TimeoutException catch (e) {
      return {
        'ok': false,
        'error': 'TimeoutException: ${e.message}',
        'type': 'timeout'
      };
    } catch (e) {
      return {'ok': false, 'error': e.toString(), 'type': 'unknown'};
    }
  }

  // ネイティブ経由で Wi-Fi ON/OFF を取得する（引数無し）
  Future<bool> checkWifiEnabled() async {
    try {
      final result = await wifiplatform.invokeMethod<bool>('isWifiEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[デバック] PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[デバック] unknown error: $e');
      return false;
    }
  }

  Future<bool> checkWifiReady(String ipAddress) async {
    if (ipAddress.isEmpty) return false;

    // 最初、直接ソケットでサーバー に接続を試みる
    try {
      debugPrint(
          '[checkWifiReady] direct connect try: $ipAddress:5000 (350ms)');
      //　ソケット通信中
      final socket = await Socket.connect(
        ipAddress,
        5000,
        timeout: const Duration(milliseconds: 350),
      );
      //　ソケット通信を閉じる
      socket.destroy();
      debugPrint('[checkWifiReady] direct connect OK (350ms)');
      return true;
    } catch (e) {
      debugPrint('[checkWifiReady] direct connect failed (350ms): $e');
    }

    // サーバーに到達できなかった場合、補助的に接続タイプを取得
    try {
      final status = await Connectivity().checkConnectivity();
      debugPrint('[checkWifiReady2] connectivity_plus result: $status');
      //ここではサーバー未到達なのでfalseを返す
      return false;
    } catch (e) {
      debugPrint('[checkWifiReady2] connectivity_plus check error: $e');
      return false;
    }
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

  @override
  void dispose() {
    super.dispose();
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

  //サーバー接続
  Future onDiscoverServicesPressed({required String sendImage}) async {
    // Wi-Fi モードでは呼ばれないようにガードしておく
    if (widget.deviceInfo == null || widget.trustDevice == null) return;

    // 以降は必ず non-null なので `!` で取得
    final device = widget.deviceInfo!;
    final trust = widget.trustDevice!;

    debugPrint('登録処理');
    //目的UUID
    // BluetoothCharacteristic? targetCharacteristic;
    try {
      // デバイスと接続する
      // await widget.deviceInfo.connect();
      await device.connect();

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
      // services = await widget.deviceInfo.discoverServices();
      services = await device.discoverServices();
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
    //デバイスとの接続を切る
    //await widget.deviceInfo.disconnect();
    await device.disconnect();
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
    //　モードを切り替える
    final bool isWifiMode = widget.ipAddress != null;

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
                width: MediaQuery
                    .of(context)
                    .size
                    .width,
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
                          minWidth: MediaQuery
                              .of(context)
                              .size
                              .width / 5),
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
          // persistentFooterButtons: deleteMode ? (_deleteItems.isNotEmpty)
          //         ? [
          persistentFooterButtons:
          !isWifiMode && deleteMode && _deleteItems.isNotEmpty
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
                        'ID: ${item.id}, URL: ${item.url}, Last Modified: ${item
                            .lastModified}');
                  }
                }
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (context) =>
                      ServerImageDelCheckPopup(
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
        // : null,
      ),
      // if (isConnected)
      if (isSending)
        const Positioned.fill(
            child: ModalBarrier(
              color: Colors.black54,
              dismissible: false, // ユーザー操作をブロック
            )),
      // if (isConnected && !isSending)
      //   Center(child: AppTheme.customCircularProgressIndicator()),
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
                value: progressPercent ?? 0.0,
                // value: (progressPercent ?? 0.0) * 0.95,
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
            parentContext: context, // ← 画面の context を渡す
            // context: context,
            imageUrl: _items[index].url,
            onSendOK: () {
              debugPrint(
                  "■ sending to trustName=${widget.trustName}, IP=${widget
                      .deviceInfo}");
              sendImageType(_items[index].url); // 選択して動かす処理
              // callNativeMethod(_items[index].url);//電子ペーパに送るときはここ
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
  void selectImageCheckDialog({
    // required BuildContext context,
    required String imageUrl,
    required Function onSendOK,
    required BuildContext parentContext}) {
    showDialog(
      barrierDismissible: false, //dialog以外の部分をタップしても消えないようにする。
      context: parentContext, // 親の context を使ってダイアログを開く
      // context: context,
      builder: (BuildContext dialogContext) {
        // builder: (context) {
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
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();

                            // 現在のモード判定（IPがセットされているか確認する。BLEはスキップする）
                            final bool isWifiMode = (widget.ipAddress != null &&
                                widget.ipAddress!.isNotEmpty);

                            // wifiのreturnがfalseで返ってくる
                            if (!isWifiMode) {
                              // wifiなし
                              debugPrint(
                                  '[デバック] BLE mode: Wi-Fiのチェックをせず、そのまま送信');
                              onSendOK();
                              //　非同期の場合、画面が破棄されていないかここでチェックする
                              if (!mounted) return;
                              setState(() => isConnected = true);
                              return;
                            }

                            // ネイティブに Wi-Fi 状態を問い合わせて、接続できるか確認する
                            final wifiInfo = await checkWifiStatusNative();
                            final status =
                            (wifiInfo['status'] ?? 'UNKNOWN').toString();
                            debugPrint(
                                '[★★....selectImageCheckDialog] native wifi status: $status, info: $wifiInfo');

                            //　結果を返してもらい、ダイアログへ反映
                            if (status == 'ERROR') {
                              final msg = wifiInfo['message'] ?? 'エラー';
                              _showErrorDialog(
                                  parentContext, 'Wi-Fi チェック失敗',
                                  'ネイティブの Wi-Fi チェックでエラーが発生しました:\n$msg');
                              return;
                            }

                            //　ダイアログ表示させて処理終了
                            if (status == 'WIFI_OFF') {
                              _showErrorDialog(parentContext, 'Wi-FiがOFF',
                                  '端末のWi-FiがOFFになっています。Wi-FiをONにして再度お試しください。');
                              return;
                            }

                            //　接続先のIPが違っていた場合
                            if (status == 'NO_IP') {
                              final ssid = wifiInfo['ssid'] ?? '(unknown)';
                              _showErrorDialog(parentContext, 'IP未取得',
                                  '端末はSSID $ssid に接続していますが IP を取得できていません。DHCP やルーター設定を確認してください。');
                              return;
                            }

                            // wi-fiiがONでIPが取得できた場合
                            if (status == 'READY' || status == 'OK') {
                              final ip = widget.ipAddress ?? '';
                              //ソケット通信でサーバの状態を確認
                              final serverCheck =
                              await checkServerReachable(ip);
                              if (serverCheck['ok'] == true) {
                                // 結果が返ってきて、接続が成功すると、送信開始
                                onSendOK();
                                if (!mounted) return;
                                setState(() => isConnected = true);
                                return;
                              } else {
                                // サーバー接続失敗。原因をユーザーに見せる（SocketException / Timeout 等）
                                final err = serverCheck['error'] ?? '接続失敗';
                                _showErrorDialog(
                                    parentContext, 'サーバー接続失敗',
                                    'サーバー ($ip:5000) へ接続できませんでした。\n\n原因: $err\n端末のネットワークまたはサーバー側を確認してください。');
                                return;
                              }
                            }

                            // それ以外（UNKNOWN 等）
                            _showErrorDialog(parentContext, 'Wi-Fi 状態不明',
                                'Wi-Fi の状態を判定できませんでした。端末設定を確認してください。');
                            // Navigator.pop(context);
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

// 計測開始
  String _ts() => DateTime.now().toIso8601String();

// 接続（UUID取得）
  Future<BluetoothCharacteristic> getCharacteristicWithRetry({
    required dynamic trust,
    required Guid serviceUUID,
    required Guid charUUID,
  }) async {
    int attempt = 0;
    while (true) {
      final attemptStart = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[TIME][discover] attempt ${attempt + 1} start: ${_ts()}');
      try {
        // per-attempt timeout を短めに（ここは既に 3s）
        final services = await trust.discoverServices().timeout(Duration(seconds: 3));
        final attemptEnd = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[TIME][discover] attempt ${attempt + 1} success: ${_ts()} (elapsed ${attemptEnd - attemptStart} ms)');

        final service = services.firstWhere(
              (s) => s.uuid == serviceUUID,
          orElse: () => throw Exception('サービスUUIDが見つかりません'),
        );
        final char = service.characteristics.firstWhere(
              (c) => c.uuid == charUUID,
          orElse: () => throw Exception('キャラクタリスティックが見つかりません'),
        );
        return char;
      } catch (e, st) {
        final attemptEnd = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[TIME][discover] attempt ${attempt + 1} failed: ${_ts()} (elapsed ${attemptEnd - attemptStart} ms) error: $e');
        debugPrint(st.toString());
        if (attempt >= 1) {
          debugPrint('[TIME][discover] giving up after ${attempt + 1} attempts');
          rethrow;
        }
        attempt++;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

// BLEデバイスの接続完了を待つ関数
  //connect() を呼び出して接続を開始
  //デバイスが提供する state / connectionState の Stream を監視できる
  //イベントを受け取るまで待機
  Future<bool> waitForDeviceConnected(dynamic trust, { Duration timeout = const Duration(seconds: 4) }) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[TIME][connect] connect() begin: ${_ts()}');
    try {
      await trust.connect(autoConnect: false);
    } catch (e) {
      debugPrint('[TIME][connect] connect() threw immediately: $e');
    }

    //接続中に例外が発生した場合も false を返し、処理が止まらないよう安全に制御する
    try {
      if (trust is dynamic && trust.state is Stream) {
        final s = await trust.state
            .firstWhere((s) => s.toString().toLowerCase().contains('connected'))
            .timeout(timeout);

        final end = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[TIME][connect] connected event received: ${_ts()} (elapsed ${end - start} ms)');
        return true;

      } else if (trust is dynamic && trust.connectionState is Stream) {
        final s = await trust.connectionState
            .firstWhere((s) => s.toString().toLowerCase().contains('connected'))
            .timeout(timeout);

        final end = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[TIME][connect] connected event received (connectionState): ${_ts()} (elapsed ${end - start} ms)');
        return true;

      } else {
        debugPrint('[TIME][connect] no state stream; waiting timeout (${timeout.inSeconds}s)');
        await Future.delayed(timeout);

        final end = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[TIME][connect] fallback wait done: ${_ts()} (elapsed ${end - start} ms)');
        return false;
      }

    } on TimeoutException {
      final end = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[TIME][connect] timed out after ${timeout.inSeconds}s: ${_ts()} (elapsed ${end - start} ms)');
      return false;

    } catch (e, st) {
      final end = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[TIME][connect] error while waiting for state: $e (${end - start} ms)');
      debugPrint(st.toString());
      return false;
    }
  }

// sendImagePictureBle（計測付き、summary 出力）
  Future<void> sendImagePictureBle(String url) async {
    if (widget.trustDevice == null) return;
    final trust = widget.trustDevice!;
    final metrics = <String, dynamic>{}; // 計測結果を集める

    if (mounted) setState(() { isSending = true; progressPercent = 0.0; });

    bool didConnectHere = false;
    int totalSentBytes = 0;
    final overallStart = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[TIME][overall] send start: ${_ts()}');

    try {
      // ファイル取得計測
      final tFileStart = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[TIME][file] getSingleFile start: ${_ts()}');
      final file = await (widget.cacheManager ?? DefaultCacheManager())
          .getSingleFile(url)
          .timeout(const Duration(seconds: 3));
      final imageBytes = await file.readAsBytes();
      final tFileEnd = DateTime.now().millisecondsSinceEpoch;
      metrics['file_ms'] = tFileEnd - tFileStart;
      debugPrint('[TIME][file] getSingleFile done: ${_ts()} (elapsed ${metrics['file_ms']} ms)');

      if (imageBytes.isEmpty) throw Exception('画像データが空です。');

      final payload = imageBytes;
      debugPrint('[TIME][overall] payload length=${payload.length}');

      // connect 計測
      final tConnectStart = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[TIME][connect] waitForDeviceConnected start: ${_ts()}');
      final connected = await waitForDeviceConnected(trust, timeout: Duration(seconds: 5));
      final tConnectEnd = DateTime.now().millisecondsSinceEpoch;
      metrics['connect_ms'] = tConnectEnd - tConnectStart;
      debugPrint('[TIME][connect] waitForDeviceConnected end: ${_ts()} (elapsed ${metrics['connect_ms']} ms)');

      if (!connected) {
        if (mounted) setState(() { isSending = false; isConnected = false; progressPercent = 0.0; });
        await _showBleErrorAfterState('接続エラー', 'BLEデバイスに接続できませんでした。\n再度お試しください。');
        return;
      }
      didConnectHere = true;
      if (mounted) setState(() => isConnected = true);

      // MTU 測定（試行）
      final tMtuStart = DateTime.now().millisecondsSinceEpoch;
      try {
        await trust.requestMtu(185).timeout(Duration(seconds: 2));
        final tMtuEnd = DateTime.now().millisecondsSinceEpoch;
        metrics['mtu_ms'] = tMtuEnd - tMtuStart;
        debugPrint('[TIME][mtu] requestMtu done: ${_ts()} (elapsed ${metrics['mtu_ms']} ms)');
      } catch (e) {
        final tMtuEnd = DateTime.now().millisecondsSinceEpoch;
        metrics['mtu_ms'] = tMtuEnd - tMtuStart;
        debugPrint('[TIME][mtu] requestMtu failed: $e (elapsed ${metrics['mtu_ms']} ms)');
      }

      // discover + characteristic 計測
      final tDiscStart = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[TIME][discover] getCharacteristicWithRetry start: ${_ts()}');
      late BluetoothCharacteristic char;
      try {
        char = await getCharacteristicWithRetry(trust: trust, serviceUUID: service_UUID, charUUID: char_UUID);
        final tDiscEnd = DateTime.now().millisecondsSinceEpoch;
        metrics['discover_ms'] = tDiscEnd - tDiscStart;
        debugPrint('[TIME][discover] getCharacteristicWithRetry done: ${_ts()} (elapsed ${metrics['discover_ms']} ms)');
      } on Exception catch (e, st) {
        final tDiscEnd = DateTime.now().millisecondsSinceEpoch;
        metrics['discover_ms'] = tDiscEnd - tDiscStart;
        debugPrint('[TIME][discover] failed: $e (elapsed ${metrics['discover_ms']} ms)');
        debugPrint(st.toString());
        if (mounted) setState(() { isSending = false; isConnected = false; progressPercent = 0.0; });
        await _showBleErrorAfterState('取得失敗エラー', 'UUIDの取得に失敗しました。\n接続先を確認してください。');
        return;
      }

      // 送信ループ計測（各チャンクごと）
      final writes = <Map<String, dynamic>>[];
      for (int offset = 0; offset < payload.length; offset += chunkSize) {
        final int end = (offset + chunkSize < payload.length) ? offset + chunkSize : payload.length;
        final chunk = payload.sublist(offset, end);
        debugPrint('[TIME][write] chunk start offset=$offset end=$end ${_ts()}');

        final writeStart = DateTime.now().millisecondsSinceEpoch;
        int writeAttempt = 0;
        bool wrote = false;
        while (!wrote) {
          try {
            await char.write(chunk, withoutResponse: true).timeout(Duration(seconds: 2));
            final writeEnd = DateTime.now().millisecondsSinceEpoch;
            final elapsed = writeEnd - writeStart;
            writes.add({'offset': offset, 'len': chunk.length, 'attempt': writeAttempt + 1, 'ms': elapsed, 'ok': true});
            totalSentBytes += chunk.length;
            wrote = true;
          } on TimeoutException catch (te) {
            final writeEnd = DateTime.now().millisecondsSinceEpoch;
            final elapsed = writeEnd - writeStart;
            writes.add({'offset': offset, 'len': chunk.length, 'attempt': writeAttempt + 1, 'ms': elapsed, 'ok': false, 'error': 'timeout'});
            debugPrint('[TIME][write] timeout at offset $offset attempt ${writeAttempt + 1}: ${_ts()} (elapsed ${elapsed} ms)');
            if (writeAttempt >= 1) {
              if (mounted) setState(() { isSending = false; isConnected = false; progressPercent = 0.0; });
              await _showBleErrorAfterState('送信タイムアウト', '書き込みタイムアウトが発生しました。');
              return;
            }
          } catch (e, st) {
            final writeEnd = DateTime.now().millisecondsSinceEpoch;
            final elapsed = writeEnd - writeStart;
            writes.add({'offset': offset, 'len': chunk.length, 'attempt': writeAttempt + 1, 'ms': elapsed, 'ok': false, 'error': e.toString()});
            debugPrint('[TIME][write] error at offset $offset attempt ${writeAttempt + 1}: $e (elapsed ${elapsed} ms)');
            debugPrint(st.toString());
            if (writeAttempt >= 1) {
              if (mounted) setState(() { isSending = false; isConnected = false; progressPercent = 0.0; });
              await _showBleErrorAfterState('送信エラー', '画像送信中にエラーが発生しました。\n再接続して再試行してください。');
              return;
            }
          }
          writeAttempt++;
          if (!wrote) await Future.delayed(Duration(milliseconds: 150 * writeAttempt));
        }

        if (mounted) setState(() => progressPercent = end / payload.length);
        await Future.delayed(Duration(milliseconds: 12));
      }

      metrics['writes'] = writes;
      metrics['totalSentBytes'] = totalSentBytes;

      // 送信完了
      final overallEnd = DateTime.now().millisecondsSinceEpoch;
      metrics['overall_ms'] = overallEnd - overallStart;
      debugPrint('[TIME][summary] metrics: ${metrics.toString()}');

      // UI 更新（完了を見せる）
      if (mounted) {
        setState(() {
          progressPercent = 1.0;
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e, st) {
      debugPrint('[ERROR] send exception: $e');
      debugPrint(st.toString());
      if (mounted) setState(() { isSending = false; isConnected = false; progressPercent = 0.0; });
      await _showBleErrorAfterState('送信エラー', '画像送信中にエラーが発生しました。\n再接続して再試行してください。');
      return;
    } finally {
      if (didConnectHere) {
        try { await trust.disconnect(); } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (mounted) setState(() { isSending = false; isConnected = false; connectionState = 'disconnect'; progressPercent = 0.0; });
      debugPrint('[TIME][overall] send finished: ${_ts()}');
    }
  }


// wifi通信を行う際の処理
  void sendImagePictureWifi(String imageUrl) async {
    setState(() {
      isSending = true;
      progressPercent = 0.0;
    });
    _upload(imageUrl).then((_) => _startPolling());
  }

  // 画像のアップロードだけを担当
  Future<void> _upload(String imageUrl) async {
    final dio = Dio();
    final file = await (widget.cacheManager ?? DefaultCacheManager())
        .getSingleFile(imageUrl);
    final bytes = await file.readAsBytes();
    print('[デバック] Wi-Fiアップロード開始: ${file.path}');

    // IPアドレスからURLを動的に組み立てる
    final serverUrl = "http://${widget.ipAddress}:5000/upload";
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: path.basename(file.path),
        contentType: MediaType('image', 'jpg'),
      ),
    });

    //　完了を待つ
    await dio.post(
      serverUrl,
      // server_Url,
      data: form,
      onSendProgress: (sent, total) {
        setState(() {
          progressPercent = total > 0 ? (sent / total) * 0.9 : 0.0;
        });
      },
    );
  }

  // 完了ステータスのポーリングだけを担当
  void _startPolling() {
    //Timer.periodic(Duration(seconds: 1), (timer) async {
    Timer.periodic(Duration(milliseconds: 100), (timer) async {
      try {
        //　返答待ち
        //final resp = await Dio().get('http://192.168.200.58:5000/status');
        final ip = widget.ipAddress ?? '192.168.200.58';
        // widget.ipAddress ?? '192.168.200.45';
        final statusUrl = 'http://$ip:5000/status';

        final resp = await Dio().get(statusUrl);
        final data = resp.data as Map<String, dynamic>;
        // statusでserverの現状態を取り出す
        final status = data['status'] as String;
        final elapsed = (data['elapsed_time'] ?? 0.0) as double;
        print('[デバック] サーバーステータス: $status, elapsed: $elapsed');
        if (status == 'done' || status == 'error') {
          timer.cancel();
          _onDisplayDone(elapsed);
        }
      } catch (e, stack) {
        //　ここで進捗インジケータを非表示
        timer.cancel();
        setState(() => isSending = false);
        debugPrint('[エラー] 送信中に例外発生: $e');
        debugPrint(stack.toString());
      }
    });
  }

  // 描画プログレスと最終クリアを担当
  void _onDisplayDone(double elapsedSec) {
    // ① まず即座にバーを100%に
    setState(() {
      progressPercent = 1.0;
      isSending = false;
    });

    //　必要ではないかも
    // Future.delayed(Duration(milliseconds: 10), () {
    //   setState(() {
    //     isSending = false;
    //   });
    // });
  }

  // wifiかBLEか
  void sendImageType(String imageUrl) {
    // 通信の判定
    final bool wifi = widget.ipAddress != null;
    if (wifi) {
      sendImagePictureWifi(imageUrl);
    } else {
      // ipadressがnullだった場合、BLE通信
      sendImagePictureBle(imageUrl);
    }
  }

  //wi-fiにつながっているか確認するところ
  //ソケット通信
  Future<bool> checkConnection(String? ipAddress) async {
    if (ipAddress == null || ipAddress.isEmpty) return false;
    // 内部は上の checkWifiReady と同じ挙動に合わせる
    return await checkWifiReady(ipAddress);
  }


  // ダイアログを"確実に"ポストフレームで表示する
  void _showDialogPostFrame(Future<void> Function() showFn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 非同期の showFn をそのまま呼ぶ（戻り値は待たない）
      showFn();
    });
  }

  // ルートナビゲータでエラーダイアログを出す（ModalBarrier 等の影響を受けにくい）
  Future<void> _showBleErrorDialogRoot(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (BuildContext dctx) {
        return AlertDialog(
          title: Center(child: Text(title, style: AppTheme.errordialogTitleStyle)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: AppTheme.errorContentStyle, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: AppTheme.errordialogButtonStyle,
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //「setState を反映してからダイアログ」を出す小ヘルパー（推奨）
  Future<void> _showBleErrorAfterState(String title, String message) async {
    if (!mounted) return;
    // setState の描画を反映させてからダイアログを出す
    await Future.delayed(Duration.zero);
    await _showBleErrorDialogRoot(title, message);
  }

  void _showErrorDialog(BuildContext ctx, String title, String message) {
    const unifiedTitle = 'エラー'; // エラーで固定させているが、不要なら消す
    showDialog(
      context: ctx,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
              child: Text(unifiedTitle, style: AppTheme.errordialogTitleStyle)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message,
                    style: AppTheme.errorContentStyle,
                    textAlign: TextAlign.center),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: AppTheme.errordialogButtonStyle,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
