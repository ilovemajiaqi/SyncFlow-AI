import '../../data/models/event_model.dart';
import 'system_alarm_bridge.dart';

class StubSystemAlarmBridge extends SystemAlarmBridgePlatform {
  @override
  Future<bool> openAlarmComposer(EventModel event) async => false;

  @override
  Future<bool> openExactAlarmSettings() async => false;

  @override
  Future<bool> openNotificationSettings() async => false;
}

SystemAlarmBridgePlatform createSystemAlarmBridge() =>
    StubSystemAlarmBridge();
