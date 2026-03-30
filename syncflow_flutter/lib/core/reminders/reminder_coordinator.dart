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
    final reminder = store.configFor(event.id);
    if (reminder == null || !reminder.enabled || event.status != 1) {
      await scheduler.cancelEventReminder(event.id);
      return;
    }

    await scheduler.syncEventReminder(
      event,
      reminder: reminder,
      defaults: settingsController.settings,
    );
  }

  Future<void> cancelForEvent(int eventId) async {
    await scheduler.cancelEventReminder(eventId);
  }

  Future<void> restoreScheduledReminders() async {
    final reminderEntries = store.allConfigs.entries
        .where((entry) => entry.value.enabled)
        .toList(growable: false);

    if (reminderEntries.isEmpty) {
      return;
    }

    final events = await scheduleRepository.fetchActiveEventsByIds(
      reminderEntries.map((entry) => entry.key),
    );
    final now = DateTime.now();
    final eventMap = <int, EventModel>{
      for (final event in events)
        if (event.endTime.isAfter(now)) event.id: event,
    };

    for (final entry in reminderEntries) {
      final event = eventMap[entry.key];
      if (event == null) {
        await scheduler.cancelEventReminder(entry.key);
        continue;
      }

      await scheduler.syncEventReminder(
        event,
        reminder: entry.value,
        defaults: settingsController.settings,
      );
    }
  }
}
