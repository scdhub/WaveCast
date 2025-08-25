import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../export-for-e-paper/e_paper_send_picture_page.dart';
import '../theme.dart';


class ConnectWifiPage extends StatefulWidget {

  const ConnectWifiPage({super.key});

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
  //　上限は設定していない
  List<String> savedServers = [];

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
                Navigator.push(context, MaterialPageRoute(builder: (context) =>
                    SendPictureSelect(
                      ipAddress: savedServers[index],
                    )));
              },

              //長押し
              onLongPress: () {
                _longPressDialog(index); // index をダイアログに渡す
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
    final controller = TextEditingController(); // 毎回新しいコントローラを生成

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
              controller: controller,
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
                    final inputIp = controller.text.trim();
                    // 上限10まで
                    if (savedServers.length >= 10) {
                      _upperLimitNumberDialog();
                      return;
                    }

                    //同じIPを入力していないか
                    if(savedServers.contains(inputIp)){
                      Navigator.pop(context); // 入力ダイアログを閉じる
                      // 閉じた後に新しいダイアログを表示する
                      Future.delayed(Duration(milliseconds: 100), () {
                        _ipDuplicationDaialog();
                      });
                      return;
                    }


                    if (inputIp.isNotEmpty) {
                      setState(() {
                        //　ここから登録
                        savedServers.add(inputIp);
                      });
                      _saveIpDataSharedPrefrences();
                      Navigator.pop(context);
                    }
                  }),
            ],
          );
        });
  }

  void _longPressDialog(index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          AlertDialog(
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ])),
    );
  }

  void _upperLimitNumberDialog() {
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
              'エラー',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              '登録できるIPは10件までです。登録したIPを長押しし、削除してから再度、登録してください。',
              // style: TextStyle(
              //   fontSize: 13,
              // ),
              textAlign: TextAlign.center,
            ),
                  actions: [
                  ElevatedButton(
                    style: AppTheme
                        .errordialogButtonStyle, // エラーダイアログボタンスタイル
                    // TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
        ]
        );
      },
    );
  }

  void _ipDuplicationDaialog() {
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
              'エラー',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'IPが重複しています。IP登録リストを再度、確認してください。',
              // style: TextStyle(
              //   fontSize: 13,
              // ),
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                style: AppTheme
                    .errordialogButtonStyle, // エラーダイアログボタンスタイル
                // TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ]
        );
      },
    );
  }
}

