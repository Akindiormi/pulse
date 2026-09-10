import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/features/tasks/presentation/task_editor_sheet.dart';
import 'package:pulse/models/milestone_model.dart';
import 'package:pulse/models/task_model.dart';

void main() {
  testWidgets('creates a normal task draft with milestone and date', (tester) async {
    TaskEditorResult? result;
    final date = DateTime(2026, 9, 10);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<TaskEditorResult>(
                  context: context,
                  builder: (_) => TaskEditorSheet(
                    milestones: const <Milestone>[],
                    defaultDate: date,
                    timezone: 'Africa/Lagos',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Gym');
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Gym');
    expect(result!.isRecurring, isFalse);
    expect(result!.dueDate, DateTime(2026, 9, 10));
  });

  testWidgets('exposes daily recurrence interval and occurrence limit', (tester) async {
    TaskEditorResult? result;
    final date = DateTime(2026, 9, 10);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<TaskEditorResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TaskEditorSheet(
                    milestones: const <Milestone>[],
                    defaultDate: date,
                    timezone: 'Africa/Lagos',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Gym');
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();

    final numberFields = find.byType(TextField);
    expect(numberFields, findsNWidgets(3));
    await tester.enterText(numberFields.at(1), '2');
    await tester.tap(find.text('End after a number of occurrences'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10');
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Gym');
    expect(result!.recurrenceType, TaskRecurrenceType.daily);
    expect(result!.recurrenceInterval, 2);
    expect(result!.occurrenceCount, 10);
    expect(result!.startsAt, DateTime(2026, 9, 10, 9));
  });
}
