import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/reminders/event_reminder_store.dart';
import 'core/reminders/reminder_coordinator.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/schedule_repository.dart';
import 'features/home/pages/home_dashboard_page.dart';
import 'features/home/providers/home_dashboard_provider.dart';

class SyncFlowApp extends StatelessWidget {
  const SyncFlowApp({
    super.key,
    required this.settingsController,
    required this.reminderStore,
    required this.reminderCoordinator,
    required this.scheduleRepository,
  });

  final AppSettingsController settingsController;
  final EventReminderStore reminderStore;
  final ReminderCoordinator reminderCoordinator;
  final ScheduleRepository scheduleRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsController>.value(
            value: settingsController),
        ChangeNotifierProvider<EventReminderStore>.value(value: reminderStore),
        Provider<ReminderCoordinator>.value(value: reminderCoordinator),
        Provider<ScheduleRepository>.value(value: scheduleRepository),
        ChangeNotifierProvider<HomeDashboardProvider>(
          create: (context) => HomeDashboardProvider(
            repository: context.read<ScheduleRepository>(),
            settingsController: context.read<AppSettingsController>(),
            reminderStore: context.read<EventReminderStore>(),
            reminderCoordinator: context.read<ReminderCoordinator>(),
          )..initialize(),
        ),
      ],
      child: Consumer<AppSettingsController>(
        builder: (context, appSettings, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SyncFlow',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appSettings.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            home: const HomeDashboardPage(),
          );
        },
      ),
    );
  }
}
