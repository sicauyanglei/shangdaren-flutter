import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef WsMessageHandler = void Function(Map<String, dynamic> msg);

/// WebSocket 客户端封装（Android / Web 通用）
class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  bool _userClosed = false;
  bool _reportedClosed = false;

  bool get isConnected => _channel != null;

  /// 收到服务器 JSON 消息
  WsMessageHandler? onMessage;

  /// 连接断开（非用户主动关闭时回调）
  void Function(String reason)? onClosed;

  WsClient();

  /// 连接服务器；失败抛异常（由调用方捕获提示）
  Future<void> connect(String url) async {
    await close();
    _userClosed = false;
    _reportedClosed = false;

    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    try {
      await channel.ready;
    } catch (e) {
      _channel = null;
      rethrow;
    }

    _sub = channel.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String);
          if (decoded is Map<String, dynamic>) onMessage?.call(decoded);
        } catch (_) {
          // 忽略非法消息
        }
      },
      onDone: _handleDone,
      onError: (Object error) => _handleDone(),
      cancelOnError: false,
    );
  }

  void _handleDone() {
    if (_reportedClosed) return;
    _reportedClosed = true;
    final reason = _userClosed ? null : '连接已断开';
    _channel = null;
    _sub = null;
    if (reason != null) onClosed?.call(reason);
  }

  /// 发送 JSON 消息（连接断开时静默丢弃）
  void send(Map<String, dynamic> msg) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(msg));
    } catch (_) {
      // 发送失败视为连接异常，等待 onDone 回调
    }
  }

  Future<void> close() async {
    _userClosed = true;
    _reportedClosed = true;
    await _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    try {
      await channel?.sink.close();
    } catch (_) {
      // 忽略关闭异常
    }
  }
}
