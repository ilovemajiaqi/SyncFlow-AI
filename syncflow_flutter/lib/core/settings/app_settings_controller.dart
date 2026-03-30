import 'package:flutter/material.dart';

import 'user_api_settings.dart';
import 'user_settings_storage_service.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._({
    required UserSettingsStorageService storageService,
    required UserApiSettings initialSettings,
  })  : _storageService = storageService,
        _settings = initialSettings;

  final UserSettingsStorageService _storageService;
  UserApiSettings _settings;
  bool _isSaving = false;

  UserApiSettings get settings => _settings;
  bool get isSaving => _isSaving;
  ThemeMode get themeMode => _settings.themeMode;

  static Future<AppSettingsController> bootstrap() async {
    final storageService = UserSettingsStorageService();
    final initialSettings = await storageService.load();
    return AppSettingsController._(
      storageService: storageService,
      initialSettings: initialSettings,
    );
  }

  Future<void> saveSettings(UserApiSettings settings) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _storageService.save(settings);
      _settings = settings;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
