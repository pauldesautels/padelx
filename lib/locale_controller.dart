import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';

const supportedPadelXLocales = <Locale>[Locale('en'), Locale('es', 'MX')];

enum PadelXLocalePreference {
  system('system'),
  english('en'),
  spanishMexico('es-MX');

  const PadelXLocalePreference(this.storageValue);
  final String storageValue;

  static PadelXLocalePreference? fromStorage(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) return preference;
    }
    return null;
  }
}

abstract interface class LocalePreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesLocalePreferenceStore implements LocalePreferenceStore {
  static const preferenceKey = 'padelx.locale.preference';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(preferenceKey);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, value);
  }
}

class PadelXLocaleController extends ChangeNotifier {
  PadelXLocaleController({
    required LocalePreferenceStore store,
    List<Locale> systemLocales = const <Locale>[],
  }) : _store = store,
       _systemLocales = List<Locale>.of(systemLocales);

  final LocalePreferenceStore _store;
  List<Locale> _systemLocales;
  PadelXLocalePreference _preference = PadelXLocalePreference.system;

  PadelXLocalePreference get preference => _preference;
  Locale get locale => switch (_preference) {
    PadelXLocalePreference.english => const Locale('en'),
    PadelXLocalePreference.spanishMexico => const Locale('es', 'MX'),
    PadelXLocalePreference.system => resolveSystemLocale(_systemLocales),
  };

  Future<void> load() async {
    try {
      _preference =
          PadelXLocalePreference.fromStorage(await _store.read()) ??
          PadelXLocalePreference.system;
    } catch (_) {
      _preference = PadelXLocalePreference.system;
    }
    notifyListeners();
  }

  Future<void> select(PadelXLocalePreference preference) async {
    if (_preference != preference) {
      _preference = preference;
      notifyListeners();
    }
    try {
      await _store.write(preference.storageValue);
    } catch (_) {
      // A local persistence failure must not block a runtime language change.
    }
  }

  void updateSystemLocales(List<Locale>? locales) {
    final next = List<Locale>.of(locales ?? const <Locale>[]);
    if (_systemLocales.length == next.length &&
        Iterable<int>.generate(
          next.length,
        ).every((index) => _systemLocales[index] == next[index])) {
      return;
    }
    _systemLocales = next;
    if (_preference == PadelXLocalePreference.system) notifyListeners();
  }

  static Locale resolveSystemLocale(List<Locale> locales) {
    for (final locale in locales) {
      if (locale.languageCode.toLowerCase() == 'es') {
        return const Locale('es', 'MX');
      }
      if (locale.languageCode.toLowerCase() == 'en') {
        return const Locale('en');
      }
    }
    return const Locale('en');
  }
}

class PadelXLocaleScope extends InheritedNotifier<PadelXLocaleController> {
  const PadelXLocaleScope({
    super.key,
    required PadelXLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static PadelXLocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PadelXLocaleScope>()?.notifier;

  static PadelXLocaleController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'PadelXLocaleScope is missing.');
    return controller!;
  }
}

String localePreferenceLabel(
  AppLocalizations strings,
  PadelXLocalePreference preference,
) => switch (preference) {
  PadelXLocalePreference.system => strings.useDeviceLanguage,
  PadelXLocalePreference.english => strings.english,
  PadelXLocalePreference.spanishMexico => strings.spanishMexico,
};

Future<void> showPadelXLanguageSelector(BuildContext context) async {
  final controller = PadelXLocaleScope.of(context);
  final strings = AppLocalizations.of(context);
  final selection = await showModalBottomSheet<PadelXLocalePreference>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                strings.chooseLanguage,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              trailing: IconButton(
                key: const Key('language-selector-cancel'),
                tooltip: strings.cancel,
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ),
            Flexible(
              child: RadioGroup<PadelXLocalePreference>(
                groupValue: controller.preference,
                onChanged: (value) => Navigator.pop(sheetContext, value),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final preference in PadelXLocalePreference.values)
                      RadioListTile<PadelXLocalePreference>(
                        key: ValueKey(
                          'language-option-${preference.storageValue}',
                        ),
                        value: preference,
                        title: Text(localePreferenceLabel(strings, preference)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (selection != null) await controller.select(selection);
}

class PadelXLanguageSettingsTile extends StatelessWidget {
  const PadelXLanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PadelXLocaleScope.of(context);
    final strings = AppLocalizations.of(context);
    return ListTile(
      key: const Key('settings-language'),
      leading: const Icon(Icons.language),
      title: Text(strings.language),
      subtitle: Text(localePreferenceLabel(strings, controller.preference)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showPadelXLanguageSelector(context),
    );
  }
}
