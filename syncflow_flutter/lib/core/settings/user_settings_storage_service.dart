import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_api_settings.dart';

class UserSettingsStorageService {
  UserSettingsStorageService({SharedPreferences? sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  static const _settingsKey = 'syncflow.user_settings';

  final SharedPreferences? _sharedPreferences;

  Future<UserApiSettings> load() async {
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final rawSettings = prefs.getString(_settingsKey);

    if (rawSettings == null || rawSettings.isEmpty) {
      return const UserApiSettings();
    }

    try {
      final decoded = jsonDecode(rawSettings) as Map<String, dynamic>;
      return UserApiSettings.fromJson(decoded,
          apiKey: (decoded['apiKey'] as String?) ?? '');
    } catch (_) {
      return const UserApiSettings();
    }
  }

  Future<void> save(UserApiSettings settings) async {
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      ...settings.toJson(),
      'apiKey': settings.apiKey.trim(),
    };
    await prefs.setString(_settingsKey, jsonEncode(payload));
  }
}
