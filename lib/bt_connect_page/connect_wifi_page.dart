import 'package:flutter/material.dart';

void main() {
  runApp(const ConnectWifiPage());
}

class ConnectWifiPage extends StatefulWidget {
  const ConnectWifiPage({super.key});

  @override
  State<ConnectWifiPage> createState() => _ConnectWifiPage();
}

final List<String> dummyWiFidata = ["192.168.1.6","192.168.2.2","192.168.2.8"];

class _ConnectWifiPage extends State<ConnectWifiPage> {
  List<String> savedServers = [];
  static const prefsKey = 'saved_servers';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Wi-Fi通信',)),
      body: ListView.builder(
        //リストを生成する数を指定する
        itemCount: dummyWiFidata.length,
        itemBuilder: (BuildContext context, int index) {
          //リストの中に並べるウィジェットを返している
          return ListTile(
            leading: const Icon(Icons.wifi),
    title: Text(dummyWiFidata[index]),
    onTap: () {
      debugPrint('${dummyWiFidata[index]}をタップ');
    },
          );
        },
      )
    );
  }
}










