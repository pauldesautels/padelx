import 'package:flutter/material.dart';
import 'l10n/l10n.dart';

class AttendanceParticipant {
  final String uid;
  final String name;
  const AttendanceParticipant(this.uid, this.name);
}

class AttendanceSelection {
  final bool matchHappened;
  final List<String> attendedUids;
  const AttendanceSelection({required this.matchHappened, required this.attendedUids});
}

class AttendanceConfirmationDialog extends StatefulWidget {
  final List<AttendanceParticipant> participants;
  const AttendanceConfirmationDialog({super.key, required this.participants});

  @override
  State<AttendanceConfirmationDialog> createState() => _AttendanceConfirmationDialogState();
}

class _AttendanceConfirmationDialogState extends State<AttendanceConfirmationDialog> {
  bool happened = true;
  late final Set<String> selected = widget.participants.map((item) => item.uid).toSet();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.confirmAttendance),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.didMatchHappen),
      RadioGroup<bool>(groupValue: happened,
        onChanged: (value) => setState(() => happened = value ?? happened),
        child: Column(children: [
          RadioListTile<bool>(key: const Key('attendance-happened'), value: true,
            title: Text(context.l10n.yesMatchHappened)),
          RadioListTile<bool>(key: const Key('attendance-not-played'), value: false,
            title: Text(context.l10n.matchDidNotHappen)),
        ])),
      if (happened) ...[
        const SizedBox(height: 8),
        Text(context.l10n.whoPlayed, style: Theme.of(context).textTheme.titleMedium),
        ...widget.participants.map((entry) => CheckboxListTile(
          key: Key('attendance-player-${entry.uid}'), value: selected.contains(entry.uid),
          title: Text(entry.name), onChanged: (value) => setState(() => value == true
            ? selected.add(entry.uid) : selected.remove(entry.uid)))),
      ],
      Text(context.l10n.attendanceSubmissionFinal,
        style: Theme.of(context).textTheme.bodySmall),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
      FilledButton(key: const Key('attendance-submit'), onPressed: () => Navigator.pop(context,
        AttendanceSelection(matchHappened: happened,
          attendedUids: happened ? selected.toList() : const [])), child: Text(context.l10n.submit)),
    ],
  );
}

class AttendanceAction extends StatelessWidget {
  final bool submitted;
  final bool busy;
  final VoidCallback onPressed;
  const AttendanceAction({super.key, required this.submitted, required this.busy,
    required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true, enabled: !submitted && !busy,
    label: submitted ? context.l10n.attendanceSubmitted : context.l10n.confirmAttendance,
    child: OutlinedButton.icon(key: const Key('confirm-attendance-action'),
      onPressed: busy || submitted ? null : onPressed,
      icon: Icon(submitted ? Icons.check_circle_outline : Icons.how_to_reg_outlined),
      label: Text(submitted ? context.l10n.attendanceSubmitted : context.l10n.confirmAttendance)),
  );
}
