import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iphone_bt_epaper/export-for-e-paper/e_paper_send_picture_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_body_color.dart';
import '../devices_data.dart';
import '../export-for-e-paper/export_page.dart';
// import 'package:google_fonts/google_fonts.dart';

// import '../main.dart';
// import '../top_page/top_page.dart';
// import 'trust-devices_popup.dart';
import '../theme.dart';
import 'unregistered_device.dart';

class ConnectBTPage extends StatefulWidget {
  const ConnectBTPage({super.key});

  @override
  State<ConnectBTPage> createState() => _ConnectBTPageState();
}

class _ConnectBTPageState extends State<ConnectBTPage> {
  //信頼済みデバイスデータ格納List
  List<TrustDevice> trustDevices = [];

//スキャンした時のデバイスデータを格納
  List<ScanDevice> scanDevices = [];

//スキャンした時のデバイスデータを格納
  List<ScanResult> scanResult = [];

  // スキャンしたデバイス情報を格納
  List<BluetoothDevice> devicesList = [];

  StreamSubscription<List<ScanResult>>? scanResultsSubscription;

  //信頼済みデバイスアプリ終了しても記憶できるように追加
  //データ書き込み
  saveStringList(List<TrustDevice> value) async {
    //アプリのストレージにアクセスするため。
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //setStringListでSharedPreferencesに文字列のリストを保存
    prefs.setStringList(
      'item',
      value
          .map((device) =>
              '${device.trustName}::${device.trustIpAddress}::${device.devicesData}')
          .toList(),
    );
  }

// String型からBluetoothDeviceに変換。
// remoteIdからデバイス情報を読み取る
  BluetoothDevice _getDeviceFromAddress(String address) {
    return BluetoothDevice(
      remoteId: DeviceIdentifier(address),
    );
  }

//データ読み込み
  _restoreValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      //getStringListでSharedPreferencesに文字列のリストを取得
      trustDevices = (prefs.getStringList('item') ?? []).map((item) {
        final parts = item.split('::');
        // StringからBluetoothDeviceに変換
        //remoteIdを参照させることで読み取る
        BluetoothDevice device = _getDeviceFromAddress(parts[1]);

        return TrustDevice(
          trustName: parts[0],
          trustIpAddress: parts[1],
          devicesData: device,
        );
      }).toList();
    });
  }

  //信頼済みデバイスからデータ削除
  Future<void> _removeCounterValue(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      // var deviceToRemove = trustDevices[index];
      trustDevices.removeAt(index); //登録済みデバイスリストから除外する。
      saveStringList(trustDevices); //現時点の登録済みデバイスリストを入れる
      // SharedPreferencesに保存する。
      prefs.setStringList(
          'item',
          trustDevices
              .map((device) =>
                  '${device.trustName}::${device.trustIpAddress}::${device.devicesData}')
              .toList());
    });
  }

  @override
  void initState() {
    super.initState();
    //画面描画時、登録済みデバイスを表示する為
    _restoreValues();
// Bluetooth 初期化と権限チェック
    initBluetooth();
  }

  bool isScanning = false; //スキャン開始、停止

  //下記bluetooth有効の確認を入れないと最初のスキャンで、デバイスをスキャンしない。
  void initBluetooth() async {
    // Bluetooth が有効かチェック
    var isOn =
        await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    if (!isOn) {
      // Bluetooth を有効にするようにユーザーに促す
      await FlutterBluePlus.turnOn();
    }
  }

  void deviceScan() {
    // スキャンを開始する前にリストをクリア
    scanResult.clear();
    devicesList.clear();
    scanDevices.clear();

    // BLEデバイスをスキャン
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
    // deviceScanResult();
    // スキャンした結果を格納していく
    scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResult = results;
      // スキャンした情報を格納する
      // scanResult = results;
      devicesList = results.map((r) => r.device).toList();

      // スキャン結果を反映
      scanDevices = devicesList
          .map((device) => ScanDevice(
              scanName: device.platformName,
              scanIpAddress: device.remoteId.toString(),
              scanDevicesData: device))
          .where((device) => device.scanName.isNotEmpty) // デバイス名が空のものを除外する。
          // ↓　追加するときは　　↑　isnotempty　の「 ）」を削除して追加してください。
          // && device.scanName.startsWith("wd001_ble_")) //  「wd001_ble_」 のみ取得する。
          .toList();

      if (mounted) {
        setState(() {
          isScanning = true;
        });
      }
    });


    //30s経ったら スキャンを停止する
    Future.delayed(const Duration(seconds: 30)).then((_) {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
      FlutterBluePlus.stopScan();
    });
  }

  //ユーザーが接続可能なデバイスを押下　→　rustDevicesに追加されるので、ここでデバイス名が空のものは追加しないようにする。
  void _addTrustDevice(ScanDevice device) {
    if (device.scanName.isEmpty) return; // デバイス名が空なら追加しない

    setState(() {
      trustDevices.add(TrustDevice(
        trustName: device.scanName,
        trustIpAddress: device.scanIpAddress.toString(),
        devicesData: device.scanDevicesData,
      ));
      scanDevices.remove(device);
      saveStringList(trustDevices);
    });
  }

  //スキャンを停止
  void stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.popUntil(
                  context, (Route<dynamic> route) => route.isFirst);
            }),
        title: const Text(
          //画面上に表示される
          'BLE通信',
          // 'E-paperに配信',
          style: TextStyle(
              // fontSize: 17,
              ),
        ),
      ),
      body: CustomPaint(
        painter: BackgroundPainter(),
        // painter: HexagonPainter(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(35),
              child: ElevatedButton(
                //スキャン開始or停止ボタン
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isScanning ? Color(0xFFD81B60) : Color(0xFF0D7BAA),
                  elevation: 5,
                  // elevation: 10,
                  //境界線の幅を設定。
                  side: const BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                  //ボタンの形状設定。角を丸めた長方形。
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(double.infinity, 50), // 高さを60にUP！
                ),
                onPressed: () {
                  setState(() {
                    if (isScanning) {
                      stopScan();
                    } else {
                      deviceScan();
                    }
                    // isScanning = !isScanning;
                  });
                },
                child: SizedBox(
                  width: 160,
                  child: Row(children: [
                    isScanning
                        ? const Icon(
                            Icons.stop_circle,
                            color: Colors.white,
                          )
                        : const Icon(
                            Icons.restart_alt,
                            color: Colors.white,
                          ),
                    const SizedBox(width: 10),
                    Text(isScanning ? 'スキャン停止' : 'スキャン開始',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ))
                  ]),
                ),
              ),
            ),

            Container(
              alignment: Alignment.center,
              width: MediaQuery.of(context).size.width,
              color: Color(0xFF0D7BAA),
              child: const Text('登録済みデバイス',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  )),
            ),
            SizedBox(
              height: 250,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                scrollDirection: Axis.vertical, // 縦方向のスクロール
                itemCount: trustDevices.length,
                itemBuilder: (context, index) {
                  // デバイス名が空なら非表示にする
                  // if (trustDevices[index].trustName.isEmpty) {
                  if (trustDevices[index].trustName.trim().isEmpty) {
                    return const SizedBox.shrink(); // 何も表示しない
                  }

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SendPictureSelect(
                          // builder: (_) => ExportPage(
                            // BLE 用のデバイス情報
                            deviceInfo: trustDevices[index].devicesData,
                            trustDevice: trustDevices[index].devicesData,
                            trustName: trustDevices[index].trustName,
                            // Wi-Fi 用の IP アドレス
                            // ipAddress: trustDevices[index].trustIpAddress,
                            // キャッシュマネージャーが必要なら渡す
                            // onDelete: () => _removeCounterValue(index),
                          ),

                        ),

                      );
                    },
                    onLongPress: () {
                      _longPressDialog(index); // index を渡す！
                    },

                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.all(5),
                      alignment: Alignment.center,
                      // width: double.infinity,
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.rectangle, //長方形
                        border: Border.all(
                          color: Colors.black12,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),

                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 左側にデバイスアイコンを追加
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.perm_device_info_sharp,
                                size: 25,
                                color: Colors.grey,
                              ),
                            ),

                            //デバイスリスト
                            Expanded(
                              child: Column(children: [
                                Text(
                                  trustDevices[index].trustName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black),
                                  // trustDevices[index].trustName.isEmpty
                                  //     ? 'デバイス名　不明'
                                  //     : trustDevices[index].trustName,
                                  // style: const TextStyle(
                                  //     fontWeight: FontWeight.bold,color: Colors.black),
                                ),
                                Text(
                                  trustDevices[index].trustIpAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ),


                            //　アイコンを透明化し、spacebetweenを使って位置を調節
                            Visibility(
                              visible: false, // false にすると中身は非表示に
                              maintainSize: true, // レイアウト上のサイズは維持
                              maintainAnimation:
                                  true, // アニメーションも維持（必要なければ false OK）
                              maintainState: true, // 状態も維持（必要なければ false OK）
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFE57373),
                                  size: 28,
                                ),
                              ),
                            ),
                          ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            //未登録デバイスのラベル
            Container(
              alignment: Alignment.center,
              width: MediaQuery.of(context).size.width,
              color: Color(0xFF0D7BAA),
              child: const Text(
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
                // '未登録デバイス',
                "接続可能なデバイス",
              ),
            ),
            UnregisteredDevice(
              scanDevices: scanDevices, //スキャンした未登録のデバイス一覧
              trustDevices: trustDevices, //既に登録されたデバイス一覧
              addTrustDevice: _addTrustDevice, //未登録デバイスを trustDevices に追加する処理
            ),
          ],
        ),
      ),
    );
  }

  void _longPressDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
          title: Text(
            "確認",
            style: AppTheme.dialogTitleStyle, //theme.dartのスタイルを使用
            textAlign: TextAlign.center,
          ),
          content: Column(
              mainAxisSize: MainAxisSize.min, //サイズ調節
              children: [
                Text(
                  '登録を解除しますか？',
                  style: AppTheme.dialogContentStyle, //theme.dartのスタイルを使用
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10, // ボタン間の間隔
                  runSpacing: 10, // 折り返した際の間隔
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: 100, // ボタンの横幅を制限
                      child: ElevatedButton(
                        style:
                        AppTheme.dialogYesButtonStyle, //theme.dartのスタイルを使用
                        onPressed: () async {
                          Navigator.of(context).pop(); // まずダイアログを閉じる
                          setState(() async {
                            await _removeCounterValue(index);
                          });
                          //   ScaffoldMessenger.of(context).showSnackBar(
                        },
                        child: const Text(
                          "はい",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        style:
                        AppTheme.dialogNoButtonStyle, //theme.dartのスタイルを使用
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "いいえ",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ])),
    );
  }
}
