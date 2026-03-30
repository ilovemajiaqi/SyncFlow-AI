import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../settings/user_api_settings.dart';
import '../settings/user_settings_storage_service.dart';
import 'parsed_schedule.dart';

class GenericAiService {
  GenericAiService({
    UserSettingsStorageService? settingsStorage,
    http.Client? httpClient,
    Duration? timeout,
  })  : _settingsStorage = settingsStorage ?? UserSettingsStorageService(),
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 30);

  static const String _scheduleSystemPrompt = '''
你是 SyncFlow AI 的日程解析器。你必须把用户输入解析成一个且仅一个 JSON 对象。返回内容必须严格是 JSON 本体，绝对不能包含 Markdown 代码块、解释性文字、前后缀、备注。
JSON 必须且只能包含以下四个字段：
{
  "title": "string",
  "start_time": "ISO 8601 datetime string",
  "end_time": "ISO 8601 datetime string",
  "location": "string"
}
如果地点未知，请返回空字符串 ""。
''';

  static final RegExp _relativeWeekdayPattern = RegExp(
    r'(下周|下星期|本周|这周|这星期|周|星期)(一|二|三|四|五|六|日|天)',
  );

  final UserSettingsStorageService _settingsStorage;
  final http.Client _httpClient;
  final Duration _timeout;

  Future<ParsedSchedule> parseSchedule(String userInput) async {
    final trimmedInput = userInput.trim();
    if (trimmedInput.isEmpty) {
      throw const GenericAiException('请输入一段要解析的日程内容。');
    }

    final normalizedInput = _annotateRelativeDateTerms(trimmedInput);
    final settings = await _settingsStorage.load();
    _validateBaseSettings(settings);

    final uri = _buildChildUri(settings.normalizedBaseUrl, 'chat/completions');
    final payload = <String, dynamic>{
      'model': settings.modelName.trim(),
      'messages': <Map<String, String>>[
        {
          'role': 'system',
          'content': _buildScheduleSystemPrompt(),
        },
        {'role': 'user', 'content': normalizedInput},
      ],
      'temperature': 0,
    };

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: <String, String>{
              HttpHeaders.authorizationHeader:
                  'Bearer ${settings.apiKey.trim()}',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final responseJson = _decodeJsonObject(response.body);
      _throwIfHttpError(response, responseJson);

      final choices = responseJson['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const FormatException('模型响应缺少 choices 字段。');
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        throw const FormatException('choices[0] 结构不正确。');
      }

      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        throw const FormatException('模型响应缺少 message 字段。');
      }

      final content = _extractMessageContent(message['content']);
      if (content.startsWith('```')) {
        throw const FormatException('模型返回了 Markdown 代码块，不符合纯 JSON 约束。');
      }

      final scheduleJson = _normalizeScheduleJson(
        _decodeJsonObject(content),
        settings,
      );
      return ParsedSchedule.fromJson(scheduleJson);
    } on TimeoutException {
      throw const GenericAiException('连接模型服务超时了，请检查网络后再试。');
    } on SocketException {
      throw const GenericAiException(
        '当前设备无法连接到模型服务，请检查网络、Base URL，或确认服务在当前网络下可访问。',
      );
    } on FormatException catch (error) {
      throw GenericAiException('模型返回内容无法解析：${error.message}');
    } on GenericAiException {
      rethrow;
    } catch (_) {
      throw const GenericAiException('这次模型调用失败了，请稍后再试。');
    }
  }

  Future<String> transcribeAudio(File audioFile) async {
    final settings = await _settingsStorage.load();
    _validateBaseSettings(settings);

    final transcriptionModel = settings.effectiveTranscriptionModelName;
    if (transcriptionModel.isEmpty) {
      throw const GenericAiException('请先在设置页填写语音转写模型。');
    }
    if (!await audioFile.exists()) {
      throw const GenericAiException('这次录音文件没有成功保存，请再试一次。');
    }

    final request = http.MultipartRequest(
      'POST',
      _buildChildUri(settings.normalizedBaseUrl, 'audio/transcriptions'),
    )
      ..headers[HttpHeaders.authorizationHeader] =
          'Bearer ${settings.apiKey.trim()}'
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..fields['model'] = transcriptionModel
      ..fields['language'] = 'zh'
      ..fields['response_format'] = 'json';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        filename: p.basename(audioFile.path),
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final responseJson = _decodeJsonObject(response.body);
      _throwIfHttpError(response, responseJson);

      final text = responseJson['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const FormatException('语音转写响应缺少 text 字段。');
      }

      return text.trim();
    } on TimeoutException {
      throw const GenericAiException('语音转写超时了，请稍后再试。');
    } on SocketException {
      throw const GenericAiException('当前设备无法连接到语音转写服务，请检查网络后再试。');
    } on FormatException catch (error) {
      throw GenericAiException('语音转写结果无法解析：${error.message}');
    } on GenericAiException {
      rethrow;
    } catch (_) {
      throw const GenericAiException('语音转写失败了，请稍后再试。');
    }
  }

  String _buildScheduleSystemPrompt() {
    final now = DateTime.now().toLocal();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetText =
        '$sign${absOffset.inHours.toString().padLeft(2, '0')}:${(absOffset.inMinutes % 60).toString().padLeft(2, '0')}';
    final nowText = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    return '''
$_scheduleSystemPrompt

当前设备本地时间：$nowText
当前设备时区偏移：$offsetText

解析规则：
1. 必须基于上面的当前本地时间来解释“今天、今晚、明天、后天、周一、下周一”等相对时间。
2. start_time 和 end_time 必须使用当前设备所在时区的完整 ISO 8601 时间字符串，并带上时区偏移。
3. 除非用户明确提到别的年份，否则不要擅自改成过去年份。
4. 如果用户给了持续时长，请据此计算 end_time。
5. 如果用户没有给持续时长，允许返回 start_time 后顺延一段合理默认时长。
''';
  }

  String _annotateRelativeDateTerms(String input) {
    final now = DateTime.now().toLocal();
    final matches = _relativeWeekdayPattern.allMatches(input).toList();
    if (matches.isEmpty) {
      return input;
    }

    final notes = <String>{};
    for (final match in matches) {
      final raw = match.group(0);
      final prefix = match.group(1);
      final weekdayLabel = match.group(2);
      if (raw == null || prefix == null || weekdayLabel == null) {
        continue;
      }

      final resolvedDate = _resolveWeekdayReference(
        now: now,
        prefix: prefix,
        weekdayLabel: weekdayLabel,
      );
      if (resolvedDate == null) {
        continue;
      }

      notes.add('$raw = ${DateFormat('yyyy-MM-dd').format(resolvedDate)}');
    }

    if (notes.isEmpty) {
      return input;
    }

    final sortedNotes = notes.toList()..sort();
    return '$input\n\n时间参考：${sortedNotes.join('；')}。请严格按这些日期解析。';
  }

  DateTime? _resolveWeekdayReference({
    required DateTime now,
    required String prefix,
    required String weekdayLabel,
  }) {
    final weekday = _chineseWeekdayToInt(weekdayLabel);
    if (weekday == null) {
      return null;
    }

    final today = DateTime(now.year, now.month, now.day);
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));

    if (prefix == '下周' || prefix == '下星期') {
      return currentWeekMonday.add(Duration(days: 7 + weekday - 1));
    }

    if (prefix == '本周' || prefix == '这周' || prefix == '这星期') {
      return currentWeekMonday.add(Duration(days: weekday - 1));
    }

    if (prefix == '周' || prefix == '星期') {
      final thisWeekTarget =
          currentWeekMonday.add(Duration(days: weekday - 1));
      if (!thisWeekTarget.isBefore(today)) {
        return thisWeekTarget;
      }
      return thisWeekTarget.add(const Duration(days: 7));
    }

    return null;
  }

  int? _chineseWeekdayToInt(String weekdayLabel) {
    switch (weekdayLabel) {
      case '一':
        return DateTime.monday;
      case '二':
        return DateTime.tuesday;
      case '三':
        return DateTime.wednesday;
      case '四':
        return DateTime.thursday;
      case '五':
        return DateTime.friday;
      case '六':
        return DateTime.saturday;
      case '日':
      case '天':
        return DateTime.sunday;
    }
    return null;
  }

  Map<String, dynamic> _normalizeScheduleJson(
    Map<String, dynamic> json,
    UserApiSettings settings,
  ) {
    final title = (json['title'] as String?)?.trim() ?? '';
    final location = (json['location'] as String?)?.trim() ?? '';
    final startTimeRaw = (json['start_time'] as String?)?.trim() ?? '';
    final endTimeRaw = (json['end_time'] as String?)?.trim() ?? '';

    if (title.isEmpty) {
      throw const FormatException('title 不能为空。');
    }

    final startTime = DateTime.tryParse(startTimeRaw);
    if (startTime == null) {
      throw const FormatException('start_time 不是合法的 ISO 8601 时间。');
    }

    final parsedEndTime = DateTime.tryParse(endTimeRaw);
    final fallbackMinutes = settings.defaultDurationMinutes > 0
        ? settings.defaultDurationMinutes
        : 60;
    final normalizedEndTime =
        parsedEndTime != null && parsedEndTime.isAfter(startTime)
            ? parsedEndTime
            : startTime.add(Duration(minutes: fallbackMinutes));

    return <String, dynamic>{
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': normalizedEndTime.toIso8601String(),
      'location': location,
    };
  }

  void _validateBaseSettings(UserApiSettings settings) {
    if (settings.apiKey.trim().isEmpty) {
      throw const GenericAiException('请先在设置页填写 API Key。');
    }
    if (settings.baseUrl.trim().isEmpty) {
      throw const GenericAiException('请先在设置页填写 Base URL。');
    }
    if (settings.modelName.trim().isEmpty) {
      throw const GenericAiException('请先在设置页填写聊天模型。');
    }

    final parsedBaseUrl = Uri.tryParse(settings.normalizedBaseUrl);
    final isValidBaseUrl = parsedBaseUrl != null &&
        parsedBaseUrl.hasScheme &&
        (parsedBaseUrl.scheme == 'http' || parsedBaseUrl.scheme == 'https');
    if (!isValidBaseUrl) {
      throw const GenericAiException('Base URL 格式不正确，请填写完整的 http/https 地址。');
    }
  }

  Uri _buildChildUri(String baseUrl, String childPath) {
    final baseUri = Uri.parse(baseUrl);
    final childSegments = childPath
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    final pathSegments = <String>[
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ...childSegments,
    ];
    return baseUri.replace(pathSegments: pathSegments);
  }

  void _throwIfHttpError(
    http.Response response,
    Map<String, dynamic> responseJson,
  ) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const GenericAiException('模型服务拒绝了这次请求，请检查 API Key 是否正确。');
    }
    if (response.statusCode == 404) {
      throw const GenericAiException('目标接口不存在，请检查 Base URL 和模型能力是否正确。');
    }
    if (response.statusCode == 415) {
      throw const GenericAiException('模型服务不接受当前音频格式，请换一个支持音频转写的服务或模型。');
    }
    if (response.statusCode == 429) {
      throw const GenericAiException('模型服务返回了限流，请稍等片刻后再试。');
    }
    if (response.statusCode >= 500) {
      throw GenericAiException(
        '模型服务暂时不可用（HTTP ${response.statusCode}），请稍后再试。',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = _extractErrorMessage(responseJson);
      throw GenericAiException(
        errorMessage ??
            '模型服务返回了错误结果（HTTP ${response.statusCode}），请检查当前配置是否可用。',
      );
    }
  }

  Map<String, dynamic> _decodeJsonObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('返回内容不是 JSON 对象。');
    }
    return decoded;
  }

  String _extractMessageContent(dynamic rawContent) {
    if (rawContent is String && rawContent.trim().isNotEmpty) {
      return rawContent.trim();
    }

    if (rawContent is List) {
      final buffer = StringBuffer();
      for (final item in rawContent) {
        if (item is Map<String, dynamic> && item['type'] == 'text') {
          final text = item['text'];
          if (text is String) {
            buffer.write(text);
          }
        }
      }

      final merged = buffer.toString().trim();
      if (merged.isNotEmpty) {
        return merged;
      }
    }

    throw const FormatException('模型响应缺少可解析的 content 字段。');
  }

  String? _extractErrorMessage(Map<String, dynamic> responseJson) {
    final error = responseJson['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    final message = responseJson['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return null;
  }
}

class GenericAiException implements Exception {
  const GenericAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
