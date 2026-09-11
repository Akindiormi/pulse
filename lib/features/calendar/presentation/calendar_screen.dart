import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../models/calendar_event_model.dart';
import '../../../models/task_model.dart';
import '../application/calendar_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

enum _CalendarView { day, week }

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _anchor;
  _CalendarView _view = _CalendarView.day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart => _anchor.subtract(Duration(days: _anchor.weekday - 1));

  CalendarRange get _range {
    final start = _view == _CalendarView.day ? _anchor : _weekStart;
    final days = _view == _CalendarView.day ? 1 : 7;
    return CalendarRange(start: start, end: start.add(Duration(days: days)));
  }

  Future<void> _openEditor({CalendarEvent? event, DateTime? start}) async {
    final tasks = await ref.read(calendarTasksProvider.future);
    if (!mounted) return;

    final draft = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventEditor(
        event: event,
        initialStart: start,
        tasks: tasks,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final auth = await ref.read(authServiceProvider).authStateChanges.first;
      if (auth.status != AuthStatus.authenticated || auth.uid == null) {
        throw StateError('Sign in to manage Calendar.');
      }
      final repo = ref.read(calendarRepositoryProvider);

      if (event == null) {
        await repo.createEvent(
          uid: auth.uid!,
          title: draft.title,
          description: draft.description,
          startsAt: draft.startsAt,
          endsAt: draft.endsAt,
          allDay: draft.allDay,
          timezone: draft.timezone,
          recurrenceRule: draft.recurrenceRule,
          taskId: draft.taskId,
        );
      } else {
        await repo.updateEvent(
          eventId: event.id,
          title: draft.title,
          description: draft.description,
          startsAt: draft.startsAt,
          endsAt: draft.endsAt,
          allDay: draft.allDay,
          timezone: draft.timezone,
          recurrenceRule: draft.recurrenceRule,
        );
        for (final taskId in event.taskIds) {
          await repo.unlinkTask(taskId: taskId, eventId: event.id);
        }
        if (draft.taskId != null) {
          await repo.linkTask(taskId: draft.taskId!, eventId: event.id);
        }
      }
      ref.invalidate(calendarEventsProvider(_range));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save event: $error')),
        );
      }
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          event.isRecurring
              ? 'This removes the whole recurring series. Linked tasks stay in Pulse.'
              : 'The linked task will stay in Pulse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(calendarRepositoryProvider).deleteEvent(eventId: event.id);
      ref.invalidate(calendarEventsProvider(_range));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete event: $error')),
        );
      }
    }
  }

  void _shift(int direction) {
    final days = _view == _CalendarView.day ? 1 : 7;
    setState(() => _anchor = _anchor.add(Duration(days: direction * days)));
  }

  void _today() {
    final now = DateTime.now();
    setState(() => _anchor = DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarEventsProvider(_range));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(calendarEventsProvider(_range)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PulseSpace.lg,
                PulseSpace.lg,
                PulseSpace.lg,
                PulseSpace.xxl,
              ),
              sliver: SliverToBoxAdapter(
                child: _CalendarHeader(
                  anchor: _anchor,
                  view: _view,
                  onViewChanged: (value) => setState(() => _view = value),
                  onPrevious: () => _shift(-1),
                  onNext: () => _shift(1),
                  onToday: _today,
                  onAdd: () => _openEditor(
                    start: _anchor.add(const Duration(hours: 9)),
                  ),
                ),
              ),
            ),
            events.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: '$error',
                  onRetry: () => ref.invalidate(calendarEventsProvider(_range)),
                ),
              ),
              data: (items) => _view == _CalendarView.day
                  ? _DayView(
                      date: _anchor,
                      events: items,
                      onEdit: (event) => _openEditor(event: event),
                      onDelete: _deleteEvent,
                      onAdd: () => _openEditor(
                        start: _anchor.add(const Duration(hours: 9)),
                      ),
                    )
                  : _WeekView(
                      start: _weekStart,
                      events: items,
                      onEdit: (event) => _openEditor(event: event),
                      onDelete: _deleteEvent,
                      onAdd: (date) => _openEditor(
                        start: date.add(const Duration(hours: 9)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.anchor,
    required this.view,
    required this.onViewChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onAdd,
  });

  final DateTime anchor;
  final _CalendarView view;
  final ValueChanged<_CalendarView> onViewChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final start = view == _CalendarView.day
        ? anchor
        : anchor.subtract(Duration(days: anchor.weekday - 1));
    final end = start.add(Duration(days: view == _CalendarView.day ? 0 : 6));
    final title = view == _CalendarView.day
        ? '${_weekday(anchor)}, ${_month(anchor)} ${anchor.day}'
        : '${_month(start)} ${start.day} – ${_month(end)} ${end.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendar', style: AppTypography.headline),
                  const SizedBox(height: PulseSpace.xs),
                  Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPrevious,
              tooltip: 'Previous',
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              onPressed: onNext,
              tooltip: 'Next',
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton.filled(
              onPressed: onAdd,
              tooltip: 'Add event',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: PulseSpace.lg),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_CalendarView>(
                segments: const [
                  ButtonSegment(
                    value: _CalendarView.day,
                    label: Text('Day'),
                    icon: Icon(Icons.view_day_rounded),
                  ),
                  ButtonSegment(
                    value: _CalendarView.week,
                    label: Text('Week'),
                    icon: Icon(Icons.view_week_rounded),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (selection) =>
                    onViewChanged(selection.first),
              ),
            ),
            const SizedBox(width: PulseSpace.sm),
            OutlinedButton(onPressed: onToday, child: const Text('Today')),
          ],
        ),
      ],
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.date,
    required this.events,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEdit;
  final ValueChanged<CalendarEvent> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final allDay = events.where((event) => event.allDay).toList();
    final timed = events.where((event) => !event.allDay).toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        PulseSpace.lg,
        0,
        PulseSpace.lg,
        PulseSpace.giant,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (allDay.isNotEmpty) const _SectionLabel('All day'),
          ...allDay.map(
            (event) => _EventCard(
              event: event,
              onEdit: () => onEdit(event),
              onDelete: () => onDelete(event),
            ),
          ),
          if (timed.isNotEmpty) const _SectionLabel('Schedule'),
          ...timed.map(
            (event) => _EventCard(
              event: event,
              onEdit: () => onEdit(event),
              onDelete: () => onDelete(event),
            ),
          ),
          if (events.isEmpty) _EmptyDay(onAdd: onAdd),
        ]),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.start,
    required this.events,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final DateTime start;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEdit;
  final ValueChanged<CalendarEvent> onDelete;
  final ValueChanged<DateTime> onAdd;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        PulseSpace.lg,
        0,
        PulseSpace.lg,
        PulseSpace.giant,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final date = start.add(Duration(days: index));
            final dayEvents = events
                .where((event) => _sameDay(event.startsAt, date))
                .toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: PulseSpace.md),
              child: PulseCard(
                padding: const EdgeInsets.all(PulseSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _sameDay(date, DateTime.now())
                                ? PulseColors.accent
                                : PulseColors.accentTint,
                            borderRadius:
                                BorderRadius.circular(PulseRadius.medium),
                          ),
                          child: Text(
                            '${date.day}',
                            style: AppTypography.title.copyWith(
                              color: _sameDay(date, DateTime.now())
                                  ? Colors.white
                                  : PulseColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: PulseSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_weekday(date), style: AppTypography.label),
                              Text(
                                '${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}',
                                style: AppTypography.metadata.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onAdd(date),
                          tooltip: 'Add event',
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    if (dayEvents.isNotEmpty) ...[
                      const SizedBox(height: PulseSpace.sm),
                      ...dayEvents.map(
                        (event) => _WeekEvent(
                          event: event,
                          onEdit: () => onEdit(event),
                          onDelete: () => onDelete(event),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          childCount: 7,
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpace.sm),
      child: PulseInteractiveCard(
        onTap: onEdit,
        child: PulseCard(
          padding: const EdgeInsets.all(PulseSpace.lg),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: PulseColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: PulseSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: AppTypography.title.copyWith(fontSize: 17)),
                    const SizedBox(height: PulseSpace.xs),
                    Text(
                      event.allDay
                          ? 'All day'
                          : '${_time(event.startsAt)} – ${_time(event.endsAt)}',
                      style: AppTypography.metadata.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (event.isRecurring)
                      const Padding(
                        padding: EdgeInsets.only(top: PulseSpace.xs),
                        child: Text('Repeats', style: AppTypography.metadata),
                      ),
                    if (event.taskIds.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: PulseSpace.xs),
                        child: Text('Linked task', style: AppTypography.metadata),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  } else {
                    onEdit();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekEvent extends StatelessWidget {
  const _WeekEvent({required this.event, required this.onEdit, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PulseSpace.xs),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(PulseRadius.small),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: PulseColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: PulseSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: AppTypography.label),
                  Text(
                    event.allDay
                        ? 'All day'
                        : '${_time(event.startsAt)} – ${_time(event.endsAt)}',
                    style: AppTypography.metadata.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                } else {
                  onEdit();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventEditor extends StatefulWidget {
  const _EventEditor({this.event, this.initialStart, required this.tasks});

  final CalendarEvent? event;
  final DateTime? initialStart;
  final List<Task> tasks;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  String? _taskId;
  String? _repeat;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final start = event?.startsAt ??
        widget.initialStart ??
        DateTime.now().add(const Duration(hours: 1));
    _start = start;
    _end = event?.endsAt ?? start.add(const Duration(hours: 1));
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _allDay = event?.allDay ?? false;
    _taskId = event?.taskIds.isNotEmpty == true ? event!.taskIds.first : null;
    _repeat = _ruleToChoice(event?.recurrenceRule);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current,
    );
    if (date == null || !mounted) return;

    if (_allDay) {
      final value = DateTime(date.year, date.month, date.day);
      setState(() {
        if (start) {
          _start = value;
        } else {
          _end = value.add(const Duration(days: 1));
        }
      });
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!start && !value.isAfter(_start)) return;

    setState(() {
      if (start) {
        _start = value;
        if (!_end.isAfter(value)) {
          _end = value.add(const Duration(hours: 1));
        }
      } else {
        _end = value;
      }
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty || !_end.isAfter(_start)) return;
    Navigator.pop(
      context,
      _EventDraft(
        title: title,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        startsAt: _start,
        endsAt: _end,
        allDay: _allDay,
        timezone: 'UTC',
        recurrenceRule: _choiceToRule(_repeat, _start),
        taskId: _taskId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          PulseSpace.xxl,
          PulseSpace.xxl,
          PulseSpace.xxl,
          PulseSpace.xxl + bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PulseRadius.hero),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.event == null ? 'New event' : 'Edit event',
                      style: AppTypography.title,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: PulseSpace.lg),
              TextField(
                controller: _title,
                autofocus: widget.event == null,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What is happening?',
                ),
              ),
              const SizedBox(height: PulseSpace.md),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: PulseSpace.lg),
              _DateRow(
                label: 'Starts',
                value: _allDay
                    ? _date(_start)
                    : '${_date(_start)} · ${_time(_start)}',
                onTap: () => _pick(true),
              ),
              _DateRow(
                label: 'Ends',
                value: _allDay
                    ? _date(_end.subtract(const Duration(days: 1)))
                    : '${_date(_end)} · ${_time(_end)}',
                onTap: () => _pick(false),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: _allDay,
                onChanged: (value) => setState(() => _allDay = value),
              ),
              DropdownButtonFormField<String?>(
                value: _repeat,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Does not repeat')),
                  DropdownMenuItem<String?>(value: 'DAILY', child: Text('Every day')),
                  DropdownMenuItem<String?>(value: 'WEEKLY', child: Text('Every week')),
                  DropdownMenuItem<String?>(value: 'MONTHLY', child: Text('Every month')),
                  DropdownMenuItem<String?>(value: 'YEARLY', child: Text('Every year')),
                ],
                onChanged: (value) => setState(() => _repeat = value),
              ),
              if (widget.tasks.isNotEmpty) ...[
                const SizedBox(height: PulseSpace.md),
                DropdownButtonFormField<String?>(
                  value: _taskId,
                  decoration: const InputDecoration(labelText: 'Linked task'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No linked task'),
                    ),
                    ...widget.tasks.map(
                      (task) => DropdownMenuItem<String?>(
                        value: task.id,
                        child: Text(task.title, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _taskId = value),
                ),
              ],
              const SizedBox(height: PulseSpace.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(widget.event == null ? 'Create event' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.timezone,
    required this.recurrenceRule,
    required this.taskId,
  });

  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String timezone;
  final String? recurrenceRule;
  final String? taskId;
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PulseRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PulseSpace.md),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 20),
              const SizedBox(width: PulseSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.metadata.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(value, style: AppTypography.label),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      );
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => PulseCard(
        padding: const EdgeInsets.all(PulseSpace.xxxl),
        child: Column(
          children: [
            const Icon(Icons.event_available_rounded, size: 42, color: PulseColors.accent),
            const SizedBox(height: PulseSpace.md),
            Text('Nothing scheduled', style: AppTypography.title),
            const SizedBox(height: PulseSpace.xs),
            Text(
              'Add an event or leave the time open.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PulseSpace.lg),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add event'),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: PulseSpace.sm, top: PulseSpace.md),
        child: Text(
          text,
          style: AppTypography.label.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(PulseSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: PulseSpace.md),
            Text('Calendar could not load', style: AppTypography.title),
            const SizedBox(height: PulseSpace.xs),
            Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: PulseSpace.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}

String _weekday(DateTime date) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];

String _month(DateTime date) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][date.month - 1];

String _date(DateTime date) => '${_month(date)} ${date.day}, ${date.year}';

String _time(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String? _ruleToChoice(String? rule) {
  if (rule == null) return null;
  final value = rule.toUpperCase();
  if (value.contains('FREQ=DAILY')) return 'DAILY';
  if (value.contains('FREQ=WEEKLY')) return 'WEEKLY';
  if (value.contains('FREQ=MONTHLY')) return 'MONTHLY';
  if (value.contains('FREQ=YEARLY')) return 'YEARLY';
  return null;
}

String? _choiceToRule(String? choice, DateTime start) {
  switch (choice) {
    case 'DAILY':
      return 'FREQ=DAILY;INTERVAL=1';
    case 'WEEKLY':
      const days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
      return 'FREQ=WEEKLY;INTERVAL=1;BYDAY=${days[start.weekday - 1]}';
    case 'MONTHLY':
      return 'FREQ=MONTHLY;INTERVAL=1';
    case 'YEARLY':
      return 'FREQ=YEARLY;INTERVAL=1';
    default:
      return null;
  }
}
