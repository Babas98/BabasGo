import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:babas_app/services/app_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('settings can be updated and persisted', () async {
    final service = AppSettingsService();
    await service.load();

    await service.updateThemeMode(ThemeMode.dark);
    expect(service.currentSettings.themeMode, ThemeMode.dark);

    await service.updateFontSizeArabic(28);
    expect(service.currentSettings.fontSizeArabic, 28);
  });
}
