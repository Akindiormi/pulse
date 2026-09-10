import 'package:flutter/material.dart';

import '../../../core/design/pulse_tokens.dart';
import '../../../models/milestone_model.dart';
import '../../../models/task_model.dart';

class TaskEditorResult {
  const TaskEditorResult({
    required this.title,
    required this.dueDate,
    required this.dueTime,
    required this.milestoneId,
    required this.recurrenceType,
    required this.recurrenceInterval,
    required this.startsAt,
    required this.untilAt,
    required this.occurrenceCount,
  });

  final String title;
  final DateTime dueDate;
  final String? dueTime;
  final String? milestoneId;
  final TaskRecurrenceType? recurrenceType;
  final int recurrenceInterval;
  final DateTime startsAt;
  final DateTime? untilAt;
  final int? occurrenceCount;

  bool get isRecurring => recurrenceType != null;
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    this.task,
    required this.milestones,
    this.defaultMilestoneId,
    this.defaultDate,
    this.timezone = 'UTC',
  });

  final Task? task;
  final List<Milestone> milestones;
  final String? defaultMilestoneId;
  final DateTime? defaultDate;
  final String timezone;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _time;
  late final TextEditingController _interval;
  late final TextEditingController _count;
  DateTime _date = DateTime.now();
  DateTime? _until;
  String? _milestoneId;
  TaskRecurrenceType? _recurrence;
  bool _hasEndDate = false;
  bool _hasCount = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _time = TextEditingController(text: task?.dueTime ?? '');
    _interval = TextEditingController(text: '1');
    _count = TextEditingController();
    final initial = task?.dueDate ?? widget.defaultDate ?? DateTime.now();
    _date = DateTime(initial.year, initial.month, initial.day);
    _milestoneId = task?.milestoneId ?? widget.defaultMilestoneId;
  }

  @override
  void dispose() {
    _title.dispose();
    _time.dispose();
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickUntil() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _date,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _until ?? _date.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _until = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    final title = _title.text.trim();
    final interval = int.tryParse(_interval.text.trim());
    final count = int.tryParse(_count.text.trim());
    if (title.isEmpty) {
      _error('Give the task a name.');
      return;
    }
    if (_recurrence != null && (interval == null || interval < 1)) {
      _error('The repeat interval must be at least 1.');
      return;
    }
    if (_hasCount && (count == null || count < 1)) {
      _error('Enter a valid occurrence count.');
      return;
    }
    if (_hasEndDate && _until == null) {
      _error('Choose an end date.');
      return;
    }

    final startsAt = _combineDateAndTime(_date, _time.text.trim());
    Navigator.of(context).pop(
      TaskEditorResult(
        title: title,
        dueDate: _date,
        dueTime: _time.text.trim().isEmpty ? null : _time.text.trim(),
        milestoneId: _milestoneId,
        recurrenceType: _recurrence,
        recurrenceInterval: interval ?? 1,
        startsAt: startsAt,
        untilAt: _hasEndDate ? _until : null,
        occurrenceCount: _hasCount ? count : null,
      ),
    );
  }

  DateTime _combineDateAndTime(DateTime date, String time) {
    if (time.isEmpty) return DateTime(date.year, date.month, date.day, 9);
    final match = RegExp(r'^(\d{1,2}):(\d{2})\$').firstMatch(time);
    if (match == null) return DateTime(date.year, date.month, date.day, 9);
    final hour = int.tryParse(match.group(1)!) ?? 9;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour.clamp(0, 23).toInt(),
      minute.clamp(0, 59).toInt(),
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(DateTime value) => '${value.day}/${value.month}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final recurringEnabled = !_editing || widget.task?.taskSeriesId != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: PulseSpace.lg,
          right: PulseSpace.lg,
          top: PulseSpace.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + PulseSpace.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit task' : 'New task',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: PulseSpace.md),
              TextField(
                controller: _title,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task',
                  hintText: 'What needs to get done?',
                ),
              ),
              const SizedBox(height: PulseSpace.md),
              DropdownButtonFormField<String?>(
                value: _milestoneId,
                decoration: const InputDecoration(labelText: 'Milestone'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No milestone'),
                  ),
                  ...widget.milestones.map(
                    (milestone) => DropdownMenuItem<String?>(
                      value: milestone.id,
                      child: Text(milestone.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _milestoneId = value),
              ),
              const SizedBox(height: PulseSpace.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(_dateLabel(_date)),
                    ),
                  ),
                  const SizedBox(width: PulseSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: _time,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        hintText: '09:00',
                      ),
                    ),
                  ),
                ],
              ),
              if (recurringEnabled) ...[
                const SizedBox(height: PulseSpace.xl),
                Text(
                  'Repeat',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: PulseSpace.sm),
                SegmentedButton<TaskRecurrenceType?>(
                  segments: const [
                    ButtonSegment<TaskRecurrenceType?>(
                      value: null,
                      label: Text('Never'),
                    ),
                    ButtonSegment<TaskRecurrenceType?>(
                      value: TaskRecurrenceType.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment<TaskRecurrenceType?>(
                      value: TaskRecurrenceType.weekly,
                      label: Text('Weekly'),
                    ),
                    ButtonSegment<TaskRecurrenceType?>(
                      value: TaskRecurrenceType.interval,
                      label: Text('Interval'),
                    ),
                  ],
                  selected: {_recurrence},
                  onSelectionChanged: (selection) =>
                      setState(() => _recurrence = selection.first),
                  multiSelectionEnabled: false,
                ),
                if (_recurrence != null) ...[
                  const SizedBox(height: PulseSpace.md),
                  TextField(
                    controller: _interval,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _recurrence == TaskRecurrenceType.weekly
                          ? 'Every how many weeks?'
                          : 'Every how many days?',
                    ),
                  ),
                  const SizedBox(height: PulseSpace.md),
                  Text(
                    'Starts ${_dateLabel(_date)} · ${widget.timezone}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: PulseSpace.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _hasEndDate,
                    title: const Text('End on a date'),
                    onChanged: (value) =>
                        setState(() => _hasEndDate = value ?? false),
                  ),
                  if (_hasEndDate)
                    OutlinedButton.icon(
                      onPressed: _pickUntil,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        _until == null
                            ? 'Choose end date'
                            : 'Ends ${_dateLabel(_until!)}',
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _hasCount,
                    title: const Text('End after a number of occurrences'),
                    onChanged: (value) =>
                        setState(() => _hasCount = value ?? false),
                  ),
                  if (_hasCount)
                    TextField(
                      controller: _count,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of occurrences',
                      ),
                    ),
                  if (_recurrence == TaskRecurrenceType.weekly) ...[
                    const SizedBox(height: PulseSpace.xs),
                    Text(
                      'Weekly repeats on ${_weekday(_date)}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ],
              const SizedBox(height: PulseSpace.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_editing ? 'Save changes' : 'Create task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekday(DateTime value) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][value.weekday - 1];
}
