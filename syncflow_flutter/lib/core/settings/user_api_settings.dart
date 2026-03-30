import 'dart:convert';

import 'package:flutter/material.dart';

class UserApiSettings {
  const UserApiSettings({
    this.apiKey = '',
    this.baseUrl = '',
    this.modelName = '',
    this.transcriptionModelName = '',
    this.defaultDurationMinutes = 60,
    this.themeMode = ThemeMode.system,
    this.notificationCenterLeadMinutes = 120,
    this.bannerLeadMinutes = 15,
    this.bannerRepeatIntervalMinutes = 5,
  });

  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String transcriptionModelName;
  final int defaultDurationMinutes;
  final ThemeMode themeMode;
  final int notificationCenterLeadMinutes;
  final int bannerLeadMinutes;
  final int bannerRepeatIntervalMinutes;

  bool get hasCustomApiKey => apiKey.trim().isNotEmpty;

  bool get hasCompleteAiConfig =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      modelName.trim().isNotEmpty;

  String get normalizedBaseUrl {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme) {
      return trimmed.replaceAll(RegExp(r'/+$'), '');
    }

    final segments =
        parsed.pathSegments.where((segment) => segment.isNotEmpty).toList();

    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'chat' &&
        segments.last == 'completions') {
      segments.removeLast();
      segments.removeLast();
    }

    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'audio' &&
        segments.last == 'transcriptions') {
      segments.removeLast();
      segments.removeLast();
    }

    return parsed
        .replace(pathSegments: segments, query: '', fragment: '')
        .toString()
        .replaceAll(RegExp(r'/+$'), '');
  }

  String get effectiveTranscriptionModelName {
    final trimmed = transcriptionModelName.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return modelName.trim();
  }

  UserApiSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
    String? transcriptionModelName,
    int? defaultDurationMinutes,
    ThemeMode? themeMode,
    int? notificationCenterLeadMinutes,
    int? bannerLeadMinutes,
    int? bannerRepeatIntervalMinutes,
  }) {
    return UserApiSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      transcriptionModelName:
          transcriptionModelName ?? this.transcriptionModelName,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      themeMode: themeMode ?? this.themeMode,
      notificationCenterLeadMinutes:
          notificationCenterLeadMinutes ?? this.notificationCenterLeadMinutes,
      bannerLeadMinutes: bannerLeadMinutes ?? this.bannerLeadMinutes,
      bannerRepeatIntervalMinutes:
          bannerRepeatIntervalMinutes ?? this.bannerRepeatIntervalMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'modelName': modelName,
      'transcriptionModelName': transcriptionModelName,
      'defaultDurationMinutes': defaultDurationMinutes,
      'themeMode': themeMode.name,
      'notificationCenterLeadMinutes': notificationCenterLeadMinutes,
      'bannerLeadMinutes': bannerLeadMinutes,
      'bannerRepeatIntervalMinutes': bannerRepeatIntervalMinutes,
    };
  }

  factory UserApiSettings.fromJson(
    Map<String, dynamic> json, {
    String apiKey = '',
  }) {
    return UserApiSettings(
      apiKey: apiKey,
      baseUrl: (json['baseUrl'] as String?)?.trim() ?? '',
      modelName: (json['modelName'] as String?)?.trim() ?? '',
      transcriptionModelName:
          (json['transcriptionModelName'] as String?)?.trim() ?? '',
      defaultDurationMinutes: (json['defaultDurationMinutes'] as int?) ?? 60,
      themeMode: _themeModeFromName(json['themeMode'] as String?),
      notificationCenterLeadMinutes:
          (json['notificationCenterLeadMinutes'] as int?) ?? 120,
      bannerLeadMinutes: (json['bannerLeadMinutes'] as int?) ?? 15,
      bannerRepeatIntervalMinutes:
          (json['bannerRepeatIntervalMinutes'] as int?) ?? 5,
    );
  }

  String encodeJson() => jsonEncode(toJson());

  static ThemeMode _themeModeFromName(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
