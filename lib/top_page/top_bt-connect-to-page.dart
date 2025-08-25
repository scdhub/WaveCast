import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:iphone_bt_epaper/bt_connect_page/connect_wifi_page.dart';
import '../bt_connect_page/connect_bt_page.dart';
import '../theme.dart';
import 'package:permission_handler/permission_handler.dart';

class BlueToothConnectToPage extends StatefulWidget {
  const BlueToothConnectToPage({super.key});

  @override
  State<BlueToothConnectToPage> createState() => _BlueToothConnectToPageState();
}

class _BlueToothConnectToPageState extends State<BlueToothConnectToPage> {
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

  @override
  Widget build(BuildContext context) {
    const data = 'E-paperに配信';

    // スマホ画面の幅を取得
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.8, // 画面幅の80%に設定
      height: 70,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF26CC76),
          side: const BorderSide(
            color: Colors.white,
            width: 2,
          ),
          //ボタンの形状設定。角を丸めた長方形。
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),

        //　ここで選択肢を出し、wifi通信/BLE通信を選べるように修正する
        onPressed: () async {
          // 位置情報のパーミッションを投げる
          await requestLocationPermission();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return SimpleDialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 40.0),
                  title: const Center(
                    child: Text(
                      '通信方法を選択',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  children: [
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context); // ダイアログを閉じて…
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConnectWifiPage(
                              // cacheManager: DefaultCacheManager(),
                            ),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
                            children: [
                              Icon(Icons.wifi, size: 24.0, color: Colors.green),
                              SizedBox(width: 12), // アイコンとテキストの間にスペース
                              Text(
                                'Wi-Fi通信',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.black, fontSize: 17),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ConnectBTPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // 余計な余白を消す
                            mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
                            children: [
                              Icon(
                                Icons.bluetooth_outlined,
                                size: 24.0,
                                color: Colors.blueAccent,
                              ),
                              SizedBox(width: 12), // アイコンとテキストの間にスペース
                              Text(
                                'BLE通信',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.black, fontSize: 17),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(), // 区切り線を入れる
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context); // 閉じるだけ
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('閉じる',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black)),
                      ),
                    )
                  ]);
            },
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              data,
              style: AppTheme.buttonTextStyle,
            ),
            const Icon(
              Icons.bluetooth_outlined,
              size: 30.0,
            ),
          ],
        ),
      ),
    );
  }
}
