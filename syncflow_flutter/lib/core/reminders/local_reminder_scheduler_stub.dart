import '../../data/models/event_model.dart';
import '../settings/user_api_settings.dart';
import 'event_reminder_store.dart';
import 'local_reminder_scheduler.dart';

class StubLocalReminderScheduler implements LocalReminderScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelEventReminder(int eventId) async {}

  @override
  Future<void> cancelPersistentOverview() async {}

  @override
  Future<void> syncEventReminder(
    EventModel event, {
    required EventReminderConfig reminder,
    required UserApiSettings defaults,
  }) async {}

  @override
  Future<void> syncPersistentOverview(EventModel? nextEvent) async {}
}

LocalReminderScheduler createPlatformReminderScheduler() => StubLocalReminderScheduler();
