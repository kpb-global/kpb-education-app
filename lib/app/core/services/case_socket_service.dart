import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class CaseSocketService {
  io.Socket? _socket;
  String? _currentCaseId;

  bool get isConnected => _socket?.connected ?? false;
  String? get currentCaseId => _currentCaseId;

  Future<void> connect(String caseId, {String? fullName}) async {
    await disconnect();
    _currentCaseId = caseId;

    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';

    final baseUrl = AppConfig.apiBaseUrl.replaceFirst('/api', '');

    _socket = io.io(
      '$baseUrl/cases',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({
            'token': token,
            if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
          })
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

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
    _socket?.off('message');
    _socket?.on('message', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void onCaseUpdated(void Function(Map<String, dynamic> data) callback) {
    _socket?.off('caseUpdated');
    _socket?.on('caseUpdated', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void onMessageAck(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('messageAck', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void onTyping(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('typing', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }
}
