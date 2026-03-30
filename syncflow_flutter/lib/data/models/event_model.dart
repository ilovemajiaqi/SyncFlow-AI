import 'package:intl/intl.dart';

class EventModel {
  EventModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    required this.durationMinutes,
    required this.targetKeyword,
    required this.status,
    required this.createdAt,
    required this.location,
  });

  final int id;
  final String userId;
  final String? title;
  final DateTime startTime;
  final int durationMinutes;
  final String? targetKeyword;
  final int status;
  final DateTime createdAt;
  final String? location;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as int,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      targetKeyword: json['target_keyword'] as String?,
      status: json['status'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      location: json['location'] as String?,
    );
  }

  factory EventModel.fromDatabase(Map<String, Object?> row) {
    return EventModel(
      id: row['id'] as int,
      userId: row['user_id'] as String? ?? '',
      title: row['title'] as String?,
      startTime: DateTime.parse(row['start_time'] as String).toLocal(),
      durationMinutes: row['duration_minutes'] as int? ?? 0,
      targetKeyword: row['target_keyword'] as String?,
      status: row['status'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      location: row['location'] as String?,
    );
  }

  EventModel copyWith({
    String? title,
    DateTime? startTime,
    int? durationMinutes,
    String? targetKeyword,
    int? status,
    String? location,
  }) {
    return EventModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      targetKeyword: targetKeyword ?? this.targetKeyword,
      status: status ?? this.status,
      createdAt: createdAt,
      location: location ?? this.location,
    );
  }

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': id == 0 ? null : id,
      'user_id': userId,
      'title': displayTitle,
      'start_time': startTime.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'target_keyword': targetKeyword,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'location': location,
    };
  }

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  String get displayTitle =>
      title?.trim().isNotEmpty == true ? title!.trim() : '未命名日程';

  String get startLabel => DateFormat('HH:mm').format(startTime);

  String get durationLabel => '$durationMinutes 分钟';

  bool occursOn(DateTime date) {
    return startTime.year == date.year &&
        startTime.month == date.month &&
        startTime.day == date.day &&
        status == 1;
  }
}
