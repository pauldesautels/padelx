import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'l10n/l10n.dart';

typedef MatchDateTimePicker =
    Future<DateTime?> Function(
      BuildContext context, {
      required DateTime now,
      DateTime? initialValue,
    });

Future<DateTime?> showAdaptiveMatchDateTimePicker(
  BuildContext context, {
  required DateTime now,
  DateTime? initialValue,
  TargetPlatform? platform,
}) async {
  final minimum = now.add(const Duration(minutes: 1));
  final maximum = DateTime(now.year + 5);
  var initial = initialValue?.isAfter(minimum) == true
      ? initialValue!
      : minimum;
  if (initial.isAfter(maximum)) initial = maximum;

  if (!kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.iOS) {
    var selected = initial;
    return showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(sheetContext.l10n.cancel),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      sheetContext.l10n.chooseDateTime,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: Text(sheetContext.l10n.done),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 250,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: initial,
                minimumDate: minimum,
                maximumDate: maximum,
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: maximum,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    initialEntryMode: TimePickerEntryMode.input,
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
