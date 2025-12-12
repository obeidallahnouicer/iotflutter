import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'crypto.dart';
import '../config.dart';

class WSClient {
  WebSocketChannel? _channel;
  Timer? _reconnect;
  final _destinationController = StreamController<Map<String, dynamic>>.broadcast();
  final _speedLimitController = StreamController<double>.broadcast();

  Stream<Map<String, dynamic>> get destinationStream => _destinationController.stream;
  Stream<double> get speedLimitStream => _speedLimitController.stream;

  void connect() {
    final url = backendWsUrl.isNotEmpty ? backendWsUrl : '';
    if (url.isEmpty) {
      print('❌ Backend WS URL not configured');
      return;
    }

    print('🔌 Connecting to WebSocket: $url');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      print('✓ WebSocket channel created');
    } catch (e) {
      print('❌ Failed to create WebSocket channel: $e');
      _scheduleReconnect();
      return;
    }

    _channel!.stream.listen((message) {
      // Parse incoming messages from backend (plain JSON)
      try {
        final str = message.toString();
        print('📩 WS message received (${str.length} chars)');
        
        final data = json.decode(str);
        if (data is Map<String, dynamic>) {
          final type = data['type'];
          final payload = data['payload'];
          
          if (type == 'destination' && payload is Map<String, dynamic>) {
            print('🎯 DESTINATION: ${payload['lat']}, ${payload['lng']}');
            _destinationController.add(payload);
          } else if (type == 'speedLimit' && payload is Map<String, dynamic>) {
            final limit = payload['speedLimit'];
            if (limit is num) {
              print('🚦 SPEED LIMIT: $limit km/h');
              _speedLimitController.add(limit.toDouble());
            }
          } else {
            print('📨 Received message type: $type');
          }
        }
      } catch (e) {
        print('❌ WS parse error: $e');
      }
    }, onDone: () {
      print('⚠ WebSocket connection closed - reconnecting...');
      _channel = null;
      _scheduleReconnect();
    }, onError: (err) {
      print('❌ WebSocket error: $err - reconnecting...');
      _channel = null;
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (_reconnect != null) return;
    print('⏱ Scheduling reconnect in 2 seconds...');
    _reconnect = Timer(Duration(seconds: 2), () {
      _reconnect = null;
      print('🔄 Attempting to reconnect...');
      connect();
    });
  }

  void sendLocation(Map<String, dynamic> payload) {
    if (_channel == null) {
      print('❌ Cannot send location - WebSocket not connected');
      return;
    }
    final envelope = {
      'type': 'location',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    };
    
    // Send as plain JSON for now (encryption can be added later)
    try {
      _channel!.sink.add(json.encode(envelope));
      print('✓ Sent location: ${payload['lat']}, ${payload['lng']}');
    } catch (e) {
      print('❌ Failed to send location: $e');
    }
  }

  void dispose() {
    _reconnect?.cancel();
    _channel?.sink.close();
    _destinationController.close();
    _speedLimitController.close();
  }
}

final wsClient = WSClient();
