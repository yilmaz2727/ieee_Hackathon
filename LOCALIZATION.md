# Localization

The game uses a single bilingual translation catalog:

- `assets/i18n/translations.json`
  - `tr`: Turkish interface text
  - `en`: English interface text

Runtime localization is handled by `lib/localization/app_localizations.dart`.
Use `tr('key')` for plain text and `tr('key', {'name': value})` for placeholders.

The home screen language menu switches between Turkish and English and saves the selected language with `SharedPreferences` under `languageCode`.
