// lib/data/repositories/settings_repository_impl.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  final SharedPreferences _prefs;
  final _streamController = StreamController<AppSettingsEntity>.broadcast();

  SharedPrefsSettingsRepository(this._prefs);

  @override
  Future<AppSettingsEntity> getSettings() async {
    return _readFromPrefs();
  }

  @override
  Future<void> saveSettings(AppSettingsEntity settings) async {
    await Future.wait([
      _prefs.setBool(AppConstants.keyMusicEnabled, settings.musicEnabled),
      _prefs.setDouble(AppConstants.keyMusicVolume, settings.musicVolume),
      _prefs.setBool(
        AppConstants.keyNotificationsEnabled,
        settings.notificationsEnabled,
      ),
      _prefs.setBool(
        AppConstants.keyAnimationsEnabled,
        settings.animationsEnabled,
      ),
      _prefs.setString(AppConstants.keyThemeMode, settings.themeMode.name),
      _prefs.setBool(AppConstants.keyPinEnabled, settings.pinEnabled),
      if (settings.pinHash != null)
        _prefs.setString(AppConstants.keyPinHash, settings.pinHash!),
      _prefs.setBool(
        AppConstants.keyBiometricEnabled,
        settings.biometricEnabled,
      ),
      _prefs.setString(AppConstants.keyLanguage, settings.language),
      _prefs.setBool(AppConstants.keyEnableDemoData, settings.enableDemoData),
    ]);
    _streamController.add(settings);
  }

  @override
  Future<void> resetSettings() async {
    await _prefs.clear();
    _streamController.add(AppSettingsEntity.defaults);
  }

  @override
  Stream<AppSettingsEntity> watchSettings() => _streamController.stream;

  AppSettingsEntity _readFromPrefs() {
    final themeString = _prefs.getString(AppConstants.keyThemeMode);
    final themeMode = themeString != null
        ? AppThemeMode.values.firstWhere(
            (e) => e.name == themeString,
            orElse: () => AppThemeMode.light,
          )
        : AppThemeMode.light;

    return AppSettingsEntity(
      musicEnabled: _prefs.getBool(AppConstants.keyMusicEnabled) ?? true,
      musicVolume: _prefs.getDouble(AppConstants.keyMusicVolume) ?? 0.7,
      notificationsEnabled:
          _prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true,
      animationsEnabled:
          _prefs.getBool(AppConstants.keyAnimationsEnabled) ?? true,
      themeMode: themeMode,
      pinEnabled: _prefs.getBool(AppConstants.keyPinEnabled) ?? false,
      pinHash: _prefs.getString(AppConstants.keyPinHash),
      biometricEnabled:
          _prefs.getBool(AppConstants.keyBiometricEnabled) ?? false,
      language: _prefs.getString(AppConstants.keyLanguage) ?? 'ar',
      enableDemoData: _prefs.getBool(AppConstants.keyEnableDemoData) ?? true,
    );
  }

  void dispose() => _streamController.close();
}
