import '../../data/models/event_model.dart';
import 'system_alarm_bridge_stub.dart'
    if (dart.library.io) 'system_alarm_bridge_native.dart';

abstract class SystemAlarmBridge {
  static Future<bool> openAlarmComposer(EventModel event) =>
      SystemAlarmBridgePlatform.instance.openAlarmComposer(event);

  static Future<bool> openNotificationSettings() =>
      SystemAlarmBridgePlatform.instance.openNotificationSettings();

  static Future<bool> openExactAlarmSettings() =>
      SystemAlarmBridgePlatform.instance.openExactAlarmSettings();
}

abstract class SystemAlarmBridgePlatform {
  static SystemAlarmBridgePlatform instance = createSystemAlarmBridge();

  Future<bool> openAlarmComposer(EventModel event);
  Future<bool> openNotificationSettings();
  Future<bool> openExactAlarmSettings();
}
