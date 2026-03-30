import 'event_model.dart';
import 'event_conflict.dart';

class IntentParseResponse {
  IntentParseResponse({
    required this.success,
    required this.message,
    required this.affectedEvents,
    this.conflicts = const <EventConflict>[],
  });

  final bool success;
  final String message;
  final List<EventModel> affectedEvents;
  final List<EventConflict> conflicts;
}
