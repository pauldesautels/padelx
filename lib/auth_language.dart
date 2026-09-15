import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

String firebaseAuthLanguageCode(Locale locale) =>
    locale.languageCode.toLowerCase() == 'es' ? 'es' : 'en';

Future<void> configureFirebaseAuthLanguage(FirebaseAuth auth, Locale locale) =>
    auth.setLanguageCode(firebaseAuthLanguageCode(locale));
