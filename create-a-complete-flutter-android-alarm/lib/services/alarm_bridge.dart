import 'package:flutter/services.dart';
import 'dart:async';

class AlarmBridge {
  static const _channel = MethodChannel('com.mistressalarm/alarms');
  static final _alarmEvents = StreamController<String>.broadcast();
  static bool _handlerInstalled = false;
  static Stream<String> get alarmEvents {
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'alarmFired' && call.arguments is String) _alarmEvents.add(call.arguments as String);
      });
    }
    return _alarmEvents.stream;
  }
  static Future<void> save(String alarmsJson) async => _channel.invokeMethod<void>('saveAlarms', {'alarms': alarmsJson});
  static Future<bool> exactPermission() async => await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;
  static Future<bool> notificationPermission() async => await _channel.invokeMethod<bool>('hasNotificationPermission') ?? false;
  static Future<bool> fullScreenPermission() async => await _channel.invokeMethod<bool>('hasFullScreenIntentPermission') ?? false;
  static Future<void> requestExactPermission() => _channel.invokeMethod<void>('requestExactAlarmPermission');
  static Future<void> requestNotificationPermission() => _channel.invokeMethod<void>('requestNotificationPermission');
  static Future<void> requestFullScreenPermission() => _channel.invokeMethod<void>('requestFullScreenIntentPermission');
  static Future<void> dismiss() => _channel.invokeMethod<void>('stopRinging');
  static Future<void> snooze() => _channel.invokeMethod<void>('snooze', {'minutes': 5});
  static Future<String?> initialAlarm() => _channel.invokeMethod<String>('getInitialAlarm');
}
