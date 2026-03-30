import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventReminderConfig {
  const EventReminderConfig({
    required this.enabled,
    required this.notificationCenterLeadMinutes,
    required this.bannerLeadMinutes,
    required this.bannerRepeatIntervalMinutes,
  });

  final bool enabled;
  final int notificationCenterLeadMinutes;
  final int bannerLeadMinutes;
  final int bannerRepeatIntervalMinutes;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'notificationCenterLeadMinutes': notificationCenterLeadMinutes,
      'bannerLeadMinutes': bannerLeadMinutes,
      'bannerRepeatIntervalMinutes': bannerRepeatIntervalMinutes,
    };
  }

  factory EventReminderConfig.fromJson(Map<String, dynamic> json) {
    return EventReminderConfig(
      enabled: json['enabled'] as bool? ?? false,
      notificationCenterLeadMinutes: json['notificationCenterLeadMinutes'] as int? ?? 120,
      bannerLeadMinutes: json['bannerLeadMinutes'] as int? ?? 15,
      bannerRepeatIntervalMinutes: json['bannerRepeatIntervalMinutes'] as int? ?? 5,
    );
  }
}

class EventReminderStore extends ChangeNotifier {
  EventReminderStore._(this._prefs, this._configs);

  static const _storageKey = 'syncflow.event_reminders';

  final SharedPreferences _prefs;
  Map<int, EventReminderConfig> _configs;

  static Future<EventReminderStore> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final configs = <int, EventReminderConfig>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          configs[int.parse(key)] = EventReminderConfig.fromJson(value as Map<String, dynamic>);
        });
      } catch (_) {
        // Ignore malformed cache and continue with empty state.
      }
    }

    return EventReminderStore._(prefs, configs);
  }

  EventReminderConfig? configFor(int eventId) => _configs[eventId];

  Map<int, EventReminderConfig> get allConfigs =>
      Map<int, EventReminderConfig>.unmodifiable(_configs);

  Future<void> saveFor(int eventId, EventReminderConfig config) async {
    _configs = <int, EventReminderConfig>{..._configs, eventId: config};
    await _persist();
    notifyListeners();
  }

  Future<void> removeFor(int eventId) async {
    if (!_configs.containsKey(eventId)) {
      return;
    }
    final next = <int, EventReminderConfig>{..._configs}..remove(eventId);
    _configs = next;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final payload = <String, dynamic>{
      for (final entry in _configs.entries) entry.key.toString(): entry.value.toJson(),
    };
    await _prefs.setString(_storageKey, jsonEncode(payload));
  }
}
