import 'event_model.dart';

class IntentParseResponse {
  IntentParseResponse({
    required this.success,
    required this.message,
    required this.affectedEvents,
  });

  final bool success;
  final String message;
  final List<EventModel> affectedEvents;
}
