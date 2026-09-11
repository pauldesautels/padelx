import 'package:flutter/material.dart';

const List<String> padelLevelValues = [
  '1',
  '1.5',
  '2',
  '2.5',
  '3',
  '3.5',
  '4',
  '4.5',
  '5',
  '5.5',
  '6',
  '6.5',
  '7',
];

const Set<String> legacyPadelLevels = {'Beginner', 'Intermediate', 'Advanced'};

String? normalizePadelLevel(String? value) {
  final trimmed = value?.trim() ?? '';
  final numeric = trimmed.toLowerCase().startsWith('level ')
      ? trimmed.substring(6).trim()
      : trimmed;
  return padelLevelValues.contains(numeric) ? numeric : null;
}

bool isValidPadelLevel(String? value) => normalizePadelLevel(value) != null;

bool isLegacyPadelLevel(String? value) =>
    legacyPadelLevels.contains(value?.trim());

String matchLevelStorageValue(String value) {
  final normalized = normalizePadelLevel(value);
  if (normalized == null) {
    throw ArgumentError.value(value, 'value', 'Invalid PadelX level');
  }
  return 'Level $normalized';
}

String profileLevelStorageValue(String value) {
  final normalized = normalizePadelLevel(value);
  if (normalized == null) {
    throw ArgumentError.value(value, 'value', 'Invalid PadelX level');
  }
  return normalized;
}

String padelLevelLabel(String? value, {String emptyLabel = 'Level not set'}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return emptyLabel;
  final normalized = normalizePadelLevel(trimmed);
  return normalized == null ? trimmed : 'Level $normalized';
}

class PadelLevelSelector extends StatelessWidget {
  final Key? fieldKey;
  final String? value;
  final String? legacyValue;
  final ValueChanged<String?>? onChanged;
  final String labelText;
  final String? errorText;
  final Key? errorKey;
  final IconData icon;

  const PadelLevelSelector({
    super.key,
    this.fieldKey,
    required this.value,
    required this.onChanged,
    this.legacyValue,
    this.labelText = 'Player level',
    this.errorText,
    this.errorKey,
    this.icon = Icons.leaderboard,
  });

  Future<void> _openSelector(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labelText,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close level selector',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  key: const Key('padel-level-options'),
                  shrinkWrap: true,
                  children: padelLevelValues
                      .map(
                        (level) => ListTile(
                          key: ValueKey('padel-level-option-$level'),
                          title: Text('Level $level'),
                          selected: level == value,
                          trailing: level == value
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, level),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final legacy = legacyValue?.trim() ?? '';
    final enabled = onChanged != null;
    return Semantics(
      label: labelText,
      value: value == null
          ? (legacy.isEmpty ? 'Not selected' : legacy)
          : 'Level $value',
      button: true,
      enabled: enabled,
      onTap: enabled ? () => _openSelector(context) : null,
      child: InkWell(
        key: fieldKey,
        onTap: enabled ? () => _openSelector(context) : null,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          // The child always renders either a selected value or a prompt, so the
          // label must float in both states instead of overlapping that text.
          isEmpty: false,
          isFocused: false,
          decoration: InputDecoration(
            labelText: labelText,
            helperText: legacy.isEmpty
                ? null
                : 'Current value "$legacy" is legacy. Choose a numeric level.',
            error: errorText == null ? null : Text(errorText!, key: errorKey),
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            enabled: enabled,
            border: const OutlineInputBorder(),
          ),
          child: Text(value == null ? 'Choose a level' : 'Level $value'),
        ),
      ),
    );
  }
}
