import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../export-for-e-paper/e_paper_send_picture_page.dart';
import '../theme.dart';


class ConnectWifiPage extends StatefulWidget {
  final CacheManager cacheManager;

  const ConnectWifiPage({
    Key? key,
    required this.cacheManager,
  }) : super(key: key);

  @override
  State<ConnectWifiPage> createState() => _ConnectWifiPage();
}

final List<String> dummyWiFidata = [
  "192.168.1.6",
  "192.168.2.2",
  "192.168.2.8"
];


class _ConnectWifiPage extends State<ConnectWifiPage> {
  // ここで登録したサーバーを保存し、リストに表示させる。
  List<String> savedServers = [];
  // サーバー情報
  // static const Key = 'saved_servers';
  // TextFiledの値を更新や初期化を行う
  final _saveController = TextEditingController();


  @override
  void initState() {
    // TODO: implement initState
    _LoadIpDataSharedPrefrences();
    super.initState();
  }


  //　保存
  Future _saveIpDataSharedPrefrences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('savedServers', savedServers);
  }
  //　取得
  Future _LoadIpDataSharedPrefrences() async {
    final prefs = await SharedPreferences.getInstance();
    final servers = prefs.getStringList('savedServers') ?? [];
    setState(() {
      savedServers = servers;
    });
  }

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: const Text(
              'Wi-Fi通信',
            )),
        body: savedServers.isEmpty
            ? const Center(
          child: Text("下の+ボタンにて登録を行ってください。"),
        )
            : ListView.builder(
          //リストを生成する数を指定する
            itemCount: savedServers.length,
            itemBuilder: (BuildContext context, int index) {
              //リストの中に並べるウィジェットを返している
              return ListTile(
                leading: const Icon(
                  Icons.wifi,
                  color: Colors.white,
                ),
                title: Text(savedServers[index],
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context)
                  => SendPictureSelect(
                    // deviceInfo: widget.deviceInfo,
                    // trustDevice: widget.trustDevice,
                    // trustName: widget.trustName,
                    cacheManager: widget.cacheManager,
                    ipAddress: savedServers[index],
                  )));
                  },

                //長押し
                onLongPress: () {
                  _longPressDialog(index); // index を渡す！
                },
              );
            }
        ),
      //追加登録ボタン
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: _addServer_signup_Dialog,
      ),
    );
  }

  void _addServer_signup_Dialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              "登録",
              textAlign: TextAlign.center,
            ),
            content: TextField(
              controller: _saveController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'IPアドレス',
                hintText: '192.168.XXX.XX',
              ),
              keyboardType: TextInputType.number,
            ),
            
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                child: Text("戻る"),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(
                width: 45,
              ),
              TextButton(
                  child: Text("登録する"),
                  //登録処理をここにいれる
                  onPressed: () async {
                    final inputIp = _saveController.text.trim();
                    if (inputIp.isNotEmpty) {
                      setState(() {
                        savedServers.add(inputIp);
                      });
                      _saveIpDataSharedPrefrences();
                    }
                    Navigator.pop(context);
                  }),
            ],
          );
        });
  }

  void _longPressDialog(index) {
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
                          setState(() {
                            savedServers.removeAt(index);
                          });
                          await _saveIpDataSharedPrefrences();
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
