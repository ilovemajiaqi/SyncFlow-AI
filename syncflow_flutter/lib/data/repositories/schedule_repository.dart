import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/ai/generic_ai_service.dart';
import '../../core/ai/parsed_schedule.dart';
import '../local/app_database.dart';
import '../models/event_model.dart';
import '../models/intent_parse_models.dart';

class ScheduleRepository {
  ScheduleRepository({
    required AppDatabase database,
    GenericAiService? aiService,
  })  : _database = database,
        _aiService = aiService ?? GenericAiService();

  static const String _localUserId = 'local-user';

  final AppDatabase _database;
  final GenericAiService _aiService;

  Future<List<EventModel>> fetchEvents({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final rows = await _database.database.query(
        AppDatabase.eventsTable,
        where: 'status = ? AND start_time >= ? AND start_time <= ?',
        whereArgs: [
          1,
          startDate.toUtc().toIso8601String(),
          endDate.toUtc().toIso8601String(),
        ],
        orderBy: 'start_time ASC',
      );

      return rows.map(EventModel.fromDatabase).toList();
    } on DatabaseException {
      throw Exception('读取本地日程失败了，请稍后再试。');
    }
  }

  Future<List<EventModel>> fetchActiveEventsByIds(Iterable<int> eventIds) async {
    final ids = eventIds.toSet().where((id) => id > 0).toList()..sort();
    if (ids.isEmpty) {
      return <EventModel>[];
    }

    final placeholders = List<String>.filled(ids.length, '?').join(', ');

    try {
      final rows = await _database.database.query(
        AppDatabase.eventsTable,
        where: 'status = ? AND id IN ($placeholders)',
        whereArgs: <Object>[1, ...ids],
        orderBy: 'start_time ASC',
      );

      return rows.map(EventModel.fromDatabase).toList();
    } on DatabaseException {
      throw Exception('读取本地日程失败了，请稍后再试。');
    }
  }

  Future<IntentParseResponse> parseIntent(String text) async {
    try {
      final parsedSchedule = await _aiService.parseSchedule(text);
      final event = await _insertParsedSchedule(parsedSchedule);
      final timeLabel = DateFormat('M月d日 HH:mm').format(event.startTime);
      final locationLabel = event.location?.trim().isNotEmpty == true
          ? '，地点：${event.location!.trim()}'
          : '';

      return IntentParseResponse(
        success: true,
        message: '已在本地创建“${event.displayTitle}”，时间：$timeLabel$locationLabel',
        affectedEvents: [event],
      );
    } on GenericAiException catch (error) {
      throw Exception(error.message);
    } on DatabaseException {
      throw Exception('模型已经完成解析，但写入本地日程失败了。');
    } catch (_) {
      throw Exception('这次本地创建日程没有成功，请稍后再试。');
    }
  }

  Future<EventModel> updateEvent({
    required int eventId,
    required String title,
    required DateTime startTime,
    required int durationMinutes,
    String? targetKeyword,
  }) async {
    try {
      final existing = await _findEventById(eventId);
      if (existing == null) {
        throw Exception('没有找到要修改的本地日程。');
      }

      final updated = existing.copyWith(
        title: title.trim(),
        startTime: startTime,
        durationMinutes: durationMinutes,
        targetKeyword: targetKeyword,
      );

      await _database.database.update(
        AppDatabase.eventsTable,
        updated.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [eventId],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return updated;
    } on DatabaseException {
      throw Exception('更新本地日程失败了，请稍后再试。');
    }
  }

  Future<EventModel> deleteEvent(int eventId) async {
    try {
      final existing = await _findEventById(eventId);
      if (existing == null) {
        throw Exception('没有找到要删除的本地日程。');
      }

      final deleted = existing.copyWith(status: 0);
      await _database.database.update(
        AppDatabase.eventsTable,
        deleted.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [eventId],
      );

      return deleted;
    } on DatabaseException {
      throw Exception('删除本地日程失败了，请稍后再试。');
    }
  }

  Future<EventModel> _insertParsedSchedule(
      ParsedSchedule parsedSchedule) async {
    final startTime = parsedSchedule.startTime.toLocal();
    final endTime = parsedSchedule.endTime.toLocal();
    final durationMinutes = endTime.difference(startTime).inMinutes;

    if (durationMinutes <= 0) {
      throw Exception('模型返回的结束时间必须晚于开始时间。');
    }

    final draft = EventModel(
      id: 0,
      userId: _localUserId,
      title: parsedSchedule.title,
      startTime: startTime,
      durationMinutes: durationMinutes,
      targetKeyword: null,
      status: 1,
      createdAt: DateTime.now(),
      location: parsedSchedule.location,
    );

    final eventId = await _database.database.insert(
      AppDatabase.eventsTable,
      draft.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    final inserted = await _findEventById(eventId);
    if (inserted == null) {
      throw Exception('日程已写入本地数据库，但回读结果失败了。');
    }
    return inserted;
  }

  Future<EventModel?> _findEventById(int eventId) async {
    final rows = await _database.database.query(
      AppDatabase.eventsTable,
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return EventModel.fromDatabase(rows.first);
  }
}
