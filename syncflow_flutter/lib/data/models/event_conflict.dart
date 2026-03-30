import 'event_model.dart';

class EventConflict {
  const EventConflict({
    required this.event,
    required this.conflictsWith,
  });

  final EventModel event;
  final List<EventModel> conflictsWith;

  bool get hasConflict => conflictsWith.isNotEmpty;
}
