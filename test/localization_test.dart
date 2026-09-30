import 'package:esma_game/localization/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Turkish and English catalogs load and language preference persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await AppLocalizations.instance.loadInitial(prefs);
    expect(tr('home.startAdventure'), 'Maceraya başla');

    await AppLocalizations.instance.setLanguage('en', prefs: prefs);
    expect(tr('home.startAdventure'), 'Start the adventure');
    expect(prefs.getString('languageCode'), 'en');

    await AppLocalizations.instance.setLanguage('tr', prefs: prefs);
    expect(tr('home.startAdventure'), 'Maceraya başla');
  });
}
