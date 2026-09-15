// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get language => 'Idioma';

  @override
  String get useDeviceLanguage => 'Usar idioma del dispositivo';

  @override
  String get english => 'English';

  @override
  String get spanishMexico => 'Español (México)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get done => 'Listo';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get settings => 'Configuración';

  @override
  String get authHeadline => 'Encuentra tu próximo partido.';

  @override
  String get authSubtitle => 'Juega más pádel con jugadores cerca de ti.';

  @override
  String get continueWithEmail => 'Continuar con correo';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get privacyPolicy => 'Aviso de privacidad';

  @override
  String get chooseLanguage => 'Elegir idioma';

  @override
  String get languageSelectorTooltip => 'Cambiar idioma';

  @override
  String get languageSelectorSemantics => 'Cambiar el idioma de la aplicación';

  @override
  String welcomePlayer(String name) {
    return 'Te damos la bienvenida, $name';
  }

  @override
  String matchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidos',
      one: '1 partido',
      zero: 'No hay partidos',
    );
    return '$_temp0';
  }
}

/// The translations for Spanish Castilian, as used in Mexico (`es_MX`).
class AppLocalizationsEsMx extends AppLocalizationsEs {
  AppLocalizationsEsMx() : super('es_MX');

  @override
  String get language => 'Idioma';

  @override
  String get useDeviceLanguage => 'Usar idioma del dispositivo';

  @override
  String get english => 'English';

  @override
  String get spanishMexico => 'Español (México)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get done => 'Listo';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get settings => 'Configuración';

  @override
  String get authHeadline => 'Encuentra tu próximo partido.';

  @override
  String get authSubtitle => 'Juega más pádel con jugadores cerca de ti.';

  @override
  String get continueWithEmail => 'Continuar con correo';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get privacyPolicy => 'Aviso de privacidad';

  @override
  String get chooseLanguage => 'Elegir idioma';

  @override
  String get languageSelectorTooltip => 'Cambiar idioma';

  @override
  String get languageSelectorSemantics => 'Cambiar el idioma de la aplicación';

  @override
  String welcomePlayer(String name) {
    return 'Te damos la bienvenida, $name';
  }

  @override
  String matchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidos',
      one: '1 partido',
      zero: 'No hay partidos',
    );
    return '$_temp0';
  }
}
