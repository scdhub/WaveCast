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
      // 補助情報として返す（ここではサーバー未到達なので false）
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
    // Wi-Fi モードでは呼ばれないようにガード
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
                        "■ sending to trustName=${widget.trustName}, IP=${widget.deviceInfo}");
                    sendImageType(_items[index].url); // 選択して動かす処理
                    // callNativeMethod(_items[index].url);//電子ペーパに送るときはここ
                    //sendImagePictureBle(_items[index ].url); //BLE通信をしたいときはここ
                    //sendImagePictureWifi(_items[index].url); //wifi通信をしたいときはここ
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
      {
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
                            debugPrint('[★★....selectImageCheckDialog] native wifi status: $status, info: $wifiInfo');

                            //　結果を返してもらい、ダイアログへ反映
                            if (status == 'ERROR') {
                              final msg = wifiInfo['message'] ?? 'エラー';
                              _showErrorDialog(parentContext,
                                  'Wi-Fi チェック失敗',
                                  'ネイティブの Wi-Fi チェックでエラーが発生しました:\n$msg');
                              return;
                            }

                            //　ダイアログ表示させて処理終了
                            if (status == 'WIFI_OFF') {
                              _showErrorDialog(parentContext,
                                  'Wi-FiがOFF',
                                  '端末のWi-FiがOFFになっています。Wi-FiをONにして再度お試しください。');
                              return;
                            }

                            //　接続先のIPが違っていた場合
                            if (status == 'NO_IP') {
                              final ssid = wifiInfo['ssid'] ?? '(unknown)';
                              _showErrorDialog(parentContext,
                                  'IP未取得',
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
                                _showErrorDialog(parentContext, 'サーバー接続失敗',
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

  // 選択画像をRBPへ転送する処理
  Future<void> sendImagePictureBle(String url) async {
    if (widget.trustDevice == null) return;
    final trust = widget.trustDevice!;

    setState(() => isSending = true);

    try {
      // 画像取得：指定された URL のファイルを取得
      final file = await (widget.cacheManager ?? DefaultCacheManager())
          .getSingleFile(url);
      final imageBytes = await file.readAsBytes();
      //ここで画像取得に失敗したり大きすぎる画像で落ちる可能性を救える。　リサイズしているから必要ない？
      print('[デバック] 画像取得完了: ${file.path}, サイズ: ${imageBytes.length} bytes');

      final headerBytes = imageBytes.sublist(0, 10);
      print('ファイルの先頭バイト: $headerBytes');

      //　計測開始、処理終わるところに停止を置いてるので差をprint
      final stopwatch = Stopwatch()..start();

      //　バイト列 + EOF
      final payload = imageBytes;
      // final eof = utf8.encode('<<EOF>>');
      //あとで落ちたときにどこまで遅れたか追跡ができるようにする
      print(
          '[デバック] BLE描画開始: total ${payload.length} bytes, chunkSize=$chunkSize');

      // 接続＆キャラクタリスティック取得
      final device = widget.trustDevice;
      //　接続
      await trust.connect(autoConnect: false);
      //await device.connect(autoConnect: false);

      //追加：MTUを大きくし通信速度を速める
      await trust.requestMtu(185);
      // await device.requestMtu(185);

      //serviceとキャラクタリスティックを探す
      final services = await trust.discoverServices();
      // final services = await device.discoverServices();
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
        //ここで落ちる場合もあるのでログを残す
        print('[デバック] chunk [$offset..$end) = ${chunk.length} bytes');

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
      // } catch (e) {
      //   debugPrint('送信中エラー: $e');
      //エラーが発生した際に、エラーの内容とエラーが発生した場所を出力する
    } catch (e, stack) {
      debugPrint('[エラー] 送信中に例外発生: $e');
      debugPrint(stack.toString());
    } finally {
      // 切断＆ステート更新させるとこ
      try {
        await trust.disconnect();
        // await widget.trustDevice.disconnect();
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
        final ip =
            widget.ipAddress ?? '192.168.200.58'; // デフォルト fallback を入れてもOK
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
}

void _showErrorDialog(BuildContext ctx, String title, String message) {
  showDialog(
    context: ctx,
    builder: (BuildContext context) {
      return AlertDialog(
        title:
            Center(child: Text(title, style: AppTheme.errordialogTitleStyle)),
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
