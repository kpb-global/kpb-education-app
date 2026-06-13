import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

class CaseSocketService {
  io.Socket? _socket;
  String? _currentCaseId;

  // Registered listeners are kept so they can be re-attached to a freshly
  // created socket whenever connect() runs again (disconnect() disposes the
  // previous socket and would otherwise drop them).
  void Function(Map<String, dynamic> data)? _onMessage;
  void Function(Map<String, dynamic> data)? _onMessageAck;
  void Function(Map<String, dynamic> data)? _onTyping;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String caseId) async {
    await disconnect();
    _currentCaseId = caseId;

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'kpb.auth.accessToken') ?? '';

    final baseUrl = AppConfig.apiBaseUrl
        .replaceFirst('/api', '');

    _socket = io.io(
      '$baseUrl/cases',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    // Re-attach any listeners registered before/after a previous connection.
    _bindHandlers();

    _socket!.onConnect((_) {
      debugPrint('[WS] Connected to case namespace');
      _socket!.emit('joinCase', {'caseId': caseId});
    });

    _socket!.onDisconnect((_) {
      debugPrint('[WS] Disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('[WS] Connection error: $error');
    });
  }

  Future<void> disconnect() async {
    if (_socket != null && _currentCaseId != null) {
      _socket!.emit('leaveCase', {'caseId': _currentCaseId});
    }
    _socket?.dispose();
    _socket = null;
    _currentCaseId = null;
  }

  void sendMessage(String caseId, String body) {
    _socket?.emit('newMessage', {'caseId': caseId, 'body': body});
  }

  void sendTyping(String caseId, bool isTyping) {
    _socket?.emit('typing', {'caseId': caseId, 'isTyping': isTyping});
  }

  void onMessage(void Function(Map<String, dynamic> data) callback) {
    _onMessage = callback;
    _attach('message', callback);
  }

  void onMessageAck(void Function(Map<String, dynamic> data) callback) {
    _onMessageAck = callback;
    _attach('messageAck', callback);
  }

  void onTyping(void Function(Map<String, dynamic> data) callback) {
    _onTyping = callback;
    _attach('typing', callback);
  }

  /// Binds the stored listeners onto the current socket. Called from connect()
  /// so listeners registered before a (re)connection are not lost.
  void _bindHandlers() {
    if (_onMessage != null) _attach('message', _onMessage!);
    if (_onMessageAck != null) _attach('messageAck', _onMessageAck!);
    if (_onTyping != null) _attach('typing', _onTyping!);
  }

  void _attach(
    String event,
    void Function(Map<String, dynamic> data) callback,
  ) {
    final socket = _socket;
    if (socket == null) return;
    // Avoid stacking duplicate handlers if re-registered on the same socket.
    socket.off(event);
    socket.on(event, (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }
}
