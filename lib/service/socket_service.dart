// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef OnDisplayDone = void Function(String message);

class SocketService {
  late IO.Socket _socket;

  void connect(OnDisplayDone onDisplayDone) {
    _socket = IO.io(
      'http://192.168.200.58:5000', // サーバによって変える
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      },
    );

    _socket.onConnect((_) {
      print('✅ Socket connected');
    });
    _socket.on('display_done', (data) {
      final msg = data['message'] as String? ?? 'done';
      print('🔔 display_done received: $msg');
      onDisplayDone(msg);
    });
    _socket.onDisconnect((_) => print('❌ Socket disconnected'));

    _socket.connect();
  }

  void disconnect() {
    _socket.disconnect();
    _socket.destroy();
  }
}
