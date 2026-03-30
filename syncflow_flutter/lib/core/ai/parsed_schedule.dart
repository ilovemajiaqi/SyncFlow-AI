class ParsedSchedule {
  const ParsedSchedule({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
  });

  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;

  factory ParsedSchedule.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    final startTimeRaw = (json['start_time'] as String?)?.trim() ?? '';
    final endTimeRaw = (json['end_time'] as String?)?.trim() ?? '';
    final location = (json['location'] as String?)?.trim() ?? '';

    if (title.isEmpty) {
      throw const FormatException('title 不能为空');
    }

    final startTime = DateTime.tryParse(startTimeRaw);
    final endTime = DateTime.tryParse(endTimeRaw);
    if (startTime == null || endTime == null) {
      throw const FormatException('start_time 或 end_time 不是合法的 ISO 8601 时间');
    }
    if (!endTime.isAfter(startTime)) {
      throw const FormatException('end_time 必须晚于 start_time');
    }

    return ParsedSchedule(
      title: title,
      startTime: startTime,
      endTime: endTime,
      location: location,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
    };
  }
}
