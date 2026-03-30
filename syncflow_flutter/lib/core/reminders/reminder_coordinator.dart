import '../../data/models/event_model.dart';
import '../../data/repositories/schedule_repository.dart';
import '../settings/app_settings_controller.dart';
import 'event_reminder_store.dart';
import 'local_reminder_scheduler.dart';

class ReminderCoordinator {
  ReminderCoordinator({
    required this.store,
    required this.scheduler,
    required this.settingsController,
    required this.scheduleRepository,
  });

  final EventReminderStore store;
  final LocalReminderScheduler scheduler;
  final AppSettingsController settingsController;
  final ScheduleRepository scheduleRepository;

  Future<void> initialize() async {
    await scheduler.initialize();
    await restoreScheduledReminders();
  }

  Future<void> syncForEvent(EventModel event) async {
    final reminder = store.configFor(event.id) ?? _defaultReminder();
    if (!reminder.enabled || event.status != 1) {
      await scheduler.cancelEventReminder(event.id);
      return;
    }

    await scheduler.syncEventReminder(
      event,
      reminder: reminder,
      defaults: settingsController.settings,
    );
    await refreshPersistentOverview();
  }

  Future<void> cancelForEvent(int eventId) async {
    await scheduler.cancelEventReminder(eventId);
    await refreshPersistentOverview();
  }

  Future<void> restoreScheduledReminders() async {
    final events = await scheduleRepository.fetchUpcomingActiveEvents();
    final now = DateTime.now();

    for (final event in events) {
      if (event.endTime.isBefore(now)) {
        await scheduler.cancelEventReminder(event.id);
        continue;
      }
      final reminder = store.configFor(event.id) ?? _defaultReminder();
      if (!reminder.enabled || event.status != 1) {
        await scheduler.cancelEventReminder(event.id);
        continue;
      }
      await scheduler.syncEventReminder(
        event,
        reminder: reminder,
        defaults: settingsController.settings,
      );
    }

    await refreshPersistentOverview();
  }

  Future<void> refreshPersistentOverview() async {
    final events = await scheduleRepository.fetchUpcomingActiveEvents();
    final nextEvent = events.isEmpty ? null : events.first;
    if (nextEvent == null) {
      await scheduler.cancelPersistentOverview();
      return;
    }

    await scheduler.syncPersistentOverview(nextEvent);
  }

  EventReminderConfig _defaultReminder() {
    final settings = settingsController.settings;
    return EventReminderConfig(
      enabled: true,
      notificationCenterLeadMinutes: settings.notificationCenterLeadMinutes,
      bannerLeadMinutes: settings.bannerLeadMinutes,
      bannerRepeatIntervalMinutes: settings.bannerRepeatIntervalMinutes,
    );
  }
}
