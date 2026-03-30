import 'package:flutter/material.dart';

import 'app.dart';
import 'core/reminders/event_reminder_store.dart';
import 'core/reminders/local_reminder_scheduler.dart';
import 'core/reminders/reminder_coordinator.dart';
import 'core/settings/app_settings_controller.dart';
import 'data/local/app_database.dart';
import 'data/repositories/schedule_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsController = await AppSettingsController.bootstrap();
  final appDatabase = await AppDatabase.open();
  final scheduleRepository = ScheduleRepository(database: appDatabase);
  final reminderStore = await EventReminderStore.bootstrap();
  final reminderCoordinator = ReminderCoordinator(
    store: reminderStore,
    scheduler: createLocalReminderScheduler(),
    settingsController: settingsController,
    scheduleRepository: scheduleRepository,
  );
  await reminderCoordinator.initialize();

  runApp(
    SyncFlowApp(
      settingsController: settingsController,
      reminderStore: reminderStore,
      reminderCoordinator: reminderCoordinator,
      scheduleRepository: scheduleRepository,
    ),
  );
}
