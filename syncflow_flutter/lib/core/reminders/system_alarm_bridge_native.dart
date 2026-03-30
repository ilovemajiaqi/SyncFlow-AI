import 'package:flutter/services.dart';

import '../../data/models/event_model.dart';
import 'system_alarm_bridge.dart';

class NativeSystemAlarmBridge extends SystemAlarmBridgePlatform {
  static const MethodChannel _channel = MethodChannel('syncflow/system');

  @override
  Future<bool> openAlarmComposer(EventModel event) async {
    return await _channel.invokeMethod<bool>(
          'openAlarmComposer',
          <String, dynamic>{
            'title': event.displayTitle,
            'hour': event.startTime.hour,
            'minute': event.startTime.minute,
          },
        ) ??
        false;
  }

  @override
  Future<bool> openNotificationSettings() async {
    return await _channel.invokeMethod<bool>('openNotificationSettings') ??
        false;
  }

  @override
  Future<bool> openExactAlarmSettings() async {
    return await _channel.invokeMethod<bool>('openExactAlarmSettings') ?? false;
  }
}

SystemAlarmBridgePlatform createSystemAlarmBridge() =>
    NativeSystemAlarmBridge();
