import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String padelXLocaleName(Locale locale) => locale.countryCode == null
    ? locale.languageCode
    : '${locale.languageCode}_${locale.countryCode}';

String formatPadelXDecimal(num value, Locale locale) =>
    NumberFormat.decimalPattern(padelXLocaleName(locale)).format(value);

String formatPadelXFoundationDate(DateTime value, Locale locale) =>
    DateFormat.yMMMd(padelXLocaleName(locale)).format(value);
