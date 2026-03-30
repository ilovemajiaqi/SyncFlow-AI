import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/event_model.dart';
import '../settings/user_api_settings.dart';
import 'event_reminder_store.dart';
import 'local_reminder_scheduler.dart';

class NativeLocalReminderScheduler implements LocalReminderScheduler {
  NativeLocalReminderScheduler();

  static const _channelId = 'syncflow_event_reminders_v2';
  static const _channelName = 'SyncFlow Event Alerts';
  static const _channelDescription =
      'Heads-up and notification center reminders for upcoming events.';
  static const _overviewChannelId = 'syncflow_upcoming_overview_v1';
  static const _overviewChannelName = 'SyncFlow Upcoming Event';
  static const _overviewChannelDescription =
      'Persistent reminder for the next upcoming event.';
  static const _androidIcon = '@mipmap/ic_launcher';
  static const _overviewNotificationId = 990001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    _configureLocalTimeZone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_androidIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _overviewChannelId,
        _overviewChannelName,
        description: _overviewChannelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  @override
  Future<void> syncEventReminder(
    EventModel event, {
    required EventReminderConfig reminder,
    required UserApiSettings defaults,
  }) async {
    await initialize();
    await _requestNotificationPermissionIfNeeded();
    await cancelEventReminder(event.id);

    if (!reminder.enabled || event.status != 1) {
      return;
    }

    final centerTime = event.startTime.subtract(
      Duration(minutes: reminder.notificationCenterLeadMinutes),
    );
    if (!centerTime.isBefore(DateTime.now())) {
      await _scheduleNotification(
        id: _notificationId(event.id, 0),
        scheduledTime: centerTime,
        title: '即将开始',
        body: '${event.displayTitle} · ${DateTimeFormatter.time(event.startTime)}',
      );
    }

    final bannerStart = event.startTime.subtract(
      Duration(minutes: reminder.bannerLeadMinutes),
    );
    final interval = Duration(minutes: reminder.bannerRepeatIntervalMinutes);

    int sequence = 1;
    DateTime current = bannerStart;
    while (!current.isAfter(event.startTime)) {
      if (!current.isBefore(DateTime.now())) {
        final remainingMinutes = event.startTime.difference(current).inMinutes;
        final title = remainingMinutes > 0 ? '还有 $remainingMinutes 分钟' : '现在开始';
        await _scheduleNotification(
          id: _notificationId(event.id, sequence),
          scheduledTime: current,
          title: title,
          body: event.displayTitle,
        );
        sequence += 1;
      }

      if (interval.inMinutes <= 0) {
        break;
      }
      current = current.add(interval);
      if (current.isAfter(event.startTime) && reminder.bannerLeadMinutes > 0) {
        break;
      }
      if (reminder.bannerLeadMinutes == 0) {
        break;
      }
    }
  }

  @override
  Future<void> cancelEventReminder(int eventId) async {
    await initialize();
    for (int index = 0; index < 40; index++) {
      await _plugin.cancel(id: _notificationId(eventId, index));
    }
  }

  @override
  Future<void> syncPersistentOverview(EventModel? nextEvent) async {
    await initialize();
    if (nextEvent == null) {
      await cancelPersistentOverview();
      return;
    }

    final startLabel = DateTimeFormatter.full(nextEvent.startTime);
    final endLabel = DateTimeFormatter.time(nextEvent.endTime);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _overviewChannelId,
        _overviewChannelName,
        channelDescription: _overviewChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.status,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _plugin.show(
      id: _overviewNotificationId,
      title: '下一个事件：${nextEvent.displayTitle}',
      body: '$startLabel 开始，$endLabel 结束',
      notificationDetails: details,
    );
  }

  @override
  Future<void> cancelPersistentOverview() async {
    await initialize();
    await _plugin.cancel(id: _overviewNotificationId);
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _scheduleNotification({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
        ticker: 'SyncFlow Reminder',
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  void _configureLocalTimeZone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final timeZoneName = now.timeZoneName.toUpperCase();

    final candidates = <String>[];
    if (offset == const Duration(hours: 8) && timeZoneName.contains('CST')) {
      candidates.add('Asia/Shanghai');
    }
    if (offset == Duration.zero) {
      candidates.add('UTC');
    }
    if (offset.inMinutes % 60 == 0) {
      final hours = offset.inHours;
      if (hours != 0) {
        final sign = hours > 0 ? '-' : '+';
        candidates.add('Etc/GMT$sign${hours.abs()}');
      }
    }
    candidates.add('UTC');

    for (final candidate in candidates) {
      try {
        tz.setLocalLocation(tz.getLocation(candidate));
        return;
      } catch (_) {
        continue;
      }
    }
  }

  int _notificationId(int eventId, int slot) => eventId * 100 + slot;
}

class DateTimeFormatter {
  static String time(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String full(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$month-$day ${time(dateTime)}';
  }
}

LocalReminderScheduler createPlatformReminderScheduler() =>
    NativeLocalReminderScheduler();
