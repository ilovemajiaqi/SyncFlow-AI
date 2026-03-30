import '../../data/models/event_model.dart';
import '../settings/user_api_settings.dart';
import 'event_reminder_store.dart';
import 'local_reminder_scheduler_stub.dart'
    if (dart.library.io) 'local_reminder_scheduler_native.dart';

abstract class LocalReminderScheduler {
  Future<void> initialize();
  Future<void> syncEventReminder(
    EventModel event, {
    required EventReminderConfig reminder,
    required UserApiSettings defaults,
  });
  Future<void> cancelEventReminder(int eventId);
  Future<void> syncPersistentOverview(EventModel? nextEvent);
  Future<void> cancelPersistentOverview();
}

LocalReminderScheduler createLocalReminderScheduler() => createPlatformReminderScheduler();
