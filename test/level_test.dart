import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/level.dart';

void main() {
  test('canonical scale contains every half-step from 1 through 7', () {
    expect(padelLevelValues, [
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
    ]);
  });

  test(
    'normalizes numeric and prefixed levels and rejects arbitrary values',
    () {
      expect(normalizePadelLevel('3.5'), '3.5');
      expect(normalizePadelLevel('Level 3.5'), '3.5');
      expect(normalizePadelLevel('  Level 3.5  '), '3.5');
      expect(normalizePadelLevel('3.7'), isNull);
      expect(normalizePadelLevel('Intermediate'), isNull);
      expect(matchLevelStorageValue('3.5'), 'Level 3.5');
      expect(profileLevelStorageValue('Level 3.5'), '3.5');
    },
  );

  test('detects named legacy levels without mapping them', () {
    expect(isLegacyPadelLevel('Beginner'), isTrue);
    expect(isLegacyPadelLevel('Intermediate'), isTrue);
    expect(isLegacyPadelLevel('Advanced'), isTrue);
    expect(isLegacyPadelLevel('Level 3'), isFalse);
  });

  testWidgets(
    'selector opens, scrolls, fires callback, and displays selection',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PadelLevelSelector(
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose a level'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('padel-level-options')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('padel-level-option-1')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const Key('padel-level-options')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('padel-level-option-6.5')));
      await tester.pumpAndSettle();
      expect(selected, '6.5');
      expect(find.text('Level 6.5'), findsOneWidget);
    },
  );

  testWidgets('legacy selector value is safe and requires a new selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PadelLevelSelector(
            value: null,
            legacyValue: 'Intermediate',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Current value "Intermediate" is legacy'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
