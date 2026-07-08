import 'package:flutter_test/flutter_test.dart';
import 'package:babas_app/main.dart';
import 'package:babas_app/services/app_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows splash screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = AppSettingsService.instance;
    await settingsService.load();
    await tester.pumpWidget(MyApp(settingsService: settingsService));

    expect(find.text('Babas App'), findsWidgets);
  });
}
