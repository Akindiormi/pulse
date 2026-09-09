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
  late DateTime _anchorDate;
  _CalendarView _view = _CalendarView.day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
  }

  DateTime get _dayStart => _anchorDate;
  DateTime get _weekStart => _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
  CalendarRange get _range {
    final start = _view == _CalendarView.day ? _dayStart : _weekStart;
    return CalendarRange(start: start, end: start.add(Duration(days: _view == _CalendarView.day ? 1 : 7)));
  }

  void _move(int amount) {
    setState(() {
      _anchorDate = _anchorDate.add(Duration(days: amount * (_view == _CalendarView.day ? 1 : 7)));
    });
  }

  void _today() {
    final now = DateTime.now();
    setState(() => _anchorDate = DateTime(now.year, now.month, now.day));
  }

  Future<String?> _uid() async {
    final state = await ref.read(authServiceProvider).authStateChanges.first;
    return state.status == AuthStatus.authenticated ? state.uid : null;
  }

  Future<void> _createOrEdit({CalendarEvent? event, DateTime? initialStart}) async {
    final tasks = await ref.read(calendarTasksProvider.future);
    if (!mounted) return;

    final draft = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventEditor(event: event, initialStart: initialStart, tasks: tasks),
    );
    if (draft == null || !mounted) return;

    try {
      final uid = await _uid();
      if (uid == null) throw StateError('Sign in to manage calendar events.');
      final repo = ref.read(calendarRepositoryProvider);
      if (event == null) {
        await repo.createEvent(
          uid: uid,
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
      ref.invalidate(calendarTasksProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save event: $error')));
    }
  }

  Future<void> _delete(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(event.isRecurring ? 'This removes the whole recurring series.' : 'The linked task will stay in Pulse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(calendarRepositoryProvider).deleteEvent(eventId: event.id);
      ref.invalidate(calendarEventsProvider(_range));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete event: $error')));
    }
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
              padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.lg, PulseSpace.lg, PulseSpace.xxl),
              sliver: SliverToBoxAdapter(child: _CalendarHeader(
                anchorDate: _anchorDate,
                view: _view,
                onViewChanged: (view) => setState(() => _view = view),
                onPrevious: () => _move(-1),
                onNext: () => _move(1),
                onToday: _today,
                onAdd: () => _createOrEdit(initialStart: _anchorDate.add(const Duration(hours: 9))),
              )),
            ),
            events.when(
              loading: () => const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
              error: (error, _) => SliverFillRemaining(hasScrollBody: false, child: Center(child: _ErrorState(message: '$error', onRetry: () => ref.invalidate(calendarEventsProvider(_range))))),
              data: (items) => _view == _CalendarView.day
                  ? _DaySliver(date: _dayStart, events: items, onEventTap: _createOrEdit, onEmptyTap: () => _createOrEdit(initialStart: _dayStart.add(const Duration(hours: 9))))
                  : _WeekSliver(start: _weekStart, events: items, onEventTap: _createOrEdit, onDayTap: (date) => _createOrEdit(initialStart: date.add(const Duration(hours: 9)))),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.anchorDate, required this.view, required this.onViewChanged, required this.onPrevious, required this.onNext, required this.onToday, required this.onAdd});
  final DateTime anchorDate;
  final _CalendarView view;
  final ValueChanged<_CalendarView> onViewChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final rangeStart = view == _CalendarView.day ? anchorDate : anchorDate.subtract(Duration(days: anchorDate.weekday - 1));
    final rangeEnd = rangeStart.add(Duration(days: view == _CalendarView.day ? 0 : 6));
    final title = view == _CalendarView.day
        ? _formatDate(anchorDate)
        : '${_month(rangeStart)} ${rangeStart.day} – ${_month(rangeEnd)} ${rangeEnd.day}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Calendar', style: AppTypography.headline),
          const SizedBox(height: PulseSpace.xs),
          Text(title, style: AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        IconButton(onPressed: onPrevious, tooltip: 'Previous', icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(onPressed: onNext, tooltip: 'Next', icon: const Icon(Icons.chevron_right_rounded)),
        IconButton.filled(onPressed: onAdd, tooltip: 'Add event', icon: const Icon(Icons.add_rounded)),
      ]),
      const SizedBox(height: PulseSpace.lg),
      Row(children: [
        Expanded(child: SegmentedButton<_CalendarView>(
          segments: const [
            ButtonSegment(value: _CalendarView.day, label: Text('Day'), icon: Icon(Icons.view_day_rounded)),
            ButtonSegment(value: _CalendarView.week, label: Text('Week'), icon: Icon(Icons.view_week_rounded)),
          ],
          selected: {view},
          onSelectionChanged: (selection) => onViewChanged(selection.first),
        )),
        const SizedBox(width: PulseSpace.sm),
        OutlinedButton(onPressed: onToday, child: const Text('Today')),
      ]),
    ]);
  }
}

class _DaySliver extends StatelessWidget {
  const _DaySliver({required this.date, required this.events, required this.onEventTap, required this.onEmptyTap});
  final DateTime date;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onEmptyTap;

  @override
  Widget build(BuildContext context) {
    final allDay = events.where((event) => event.allDay).toList(growable: false);
    final timed = events.where((event) => !event.allDay).toList(growable: false);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(PulseSpace.lg, 0, PulseSpace.lg, PulseSpace.giant),
      sliver: SliverList(delegate: SliverChildListDelegate([
        if (allDay.isNotEmpty) ...[
          const _SectionLabel(label: 'All day'),
          ...allDay.map((event) => Padding(padding: const EdgeInsets.only(bottom: PulseSpace.sm), child: _EventCard(event: event, onTap: () => onEventTap(event)))),
          const SizedBox(height: PulseSpace.lg),
        ],
        if (timed.isEmpty && allDay.isEmpty)
          _EmptyDay(date: date, onAdd: onEmptyTap)
        else ...[
          const _SectionLabel(label: 'Schedule'),
          ...timed.map((event) => Padding(padding: const EdgeInsets.only(bottom: PulseSpace.sm), child: _EventCard(event: event, onTap: () => onEventTap(event)))),
        ],
      ])),
    );
  }
}

class _WeekSliver extends StatelessWidget {
  const _WeekSliver({required this.start, required this.events, required this.onEventTap, required this.onDayTap});
  final DateTime start;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(PulseSpace.lg, 0, PulseSpace.lg, PulseSpace.giant),
      sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
        final date = start.add(Duration(days: index));
        final dayEvents = events.where((event) => _sameDay(event.startsAt, date)).toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: PulseSpace.md),
          child: PulseInteractiveCard(
            onTap: () => onDayTap(date),
            child: PulseCard(padding: const EdgeInsets.all(PulseSpace.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: _sameDay(date, DateTime.now()) ? PulseColors.accent : PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.medium)), child: Text('${date.day}', style: AppTypography.title.copyWith(color: _sameDay(date, DateTime.now()) ? Colors.white : PulseColors.accent))),
                const SizedBox(width: PulseSpace.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_weekday(date), style: AppTypography.label), Text('${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}', style: AppTypography.metadata.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))])),
                const Icon(Icons.add_rounded, size: 20),
              ]),
              if (dayEvents.isNotEmpty) ...[
                const SizedBox(height: PulseSpace.md),
                ...dayEvents.map((event) => Padding(padding: const EdgeInsets.only(bottom: PulseSpace.xs), child: _WeekEventRow(event: event, onTap: () => onEventTap(event)))),
              ],
            ])),
          ),
        );
      }, childCount: 7)),
    );
  }
}

class _WeekEventRow extends StatelessWidget {
  const _WeekEventRow({required this.event, required this.onTap});
  final CalendarEvent event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(PulseRadius.small), child: Padding(padding: const EdgeInsets.symmetric(vertical: PulseSpace.sm), child: Row(children: [Container(width: 3, height: 32, decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(3))), const SizedBox(width: PulseSpace.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event.title, style: AppTypography.label), Text(event.allDay ? 'All day' : '${_time(event.startsAt)} – ${_time(event.endsAt)}', style: AppTypography.metadata.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))])), if (event.taskIds.isNotEmpty) const Icon(Icons.check_circle_outline_rounded, size: 18)])));
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});
  final CalendarEvent event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PulseInteractiveCard(onTap: onTap, child: PulseCard(padding: const EdgeInsets.all(PulseSpace.lg), child: Row(children: [Container(width: 4, height: 52, decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(4))), const SizedBox(width: PulseSpace.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event.title, style: AppTypography.title.copyWith(fontSize: 17)), const SizedBox(height: PulseSpace.xs), Text(event.allDay ? 'All day' : '${_time(event.startsAt)} – ${_time(event.endsAt)}', style: AppTypography.metadata.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), if (event.description != null && event.description!.isNotEmpty) ...[const SizedBox(height: PulseSpace.xs), Text(event.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]],)), if (event.isRecurring) const Padding(padding: EdgeInsets.only(left: PulseSpace.sm), child: Icon(Icons.repeat_rounded, size: 20)), if (event.taskIds.isNotEmpty) const Padding(padding: EdgeInsets.only(left: PulseSpace.sm), child: Icon(Icons.task_alt_rounded, size: 20))])));
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
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _allDay;
  String? _taskId;
  String? _recurrence;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final start = event?.startsAt ?? widget.initialStart ?? DateTime.now().add(const Duration(hours: 1));
    _startsAt = start;
    _endsAt = event?.endsAt ?? start.add(const Duration(hours: 1));
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _allDay = event?.allDay ?? false;
    _taskId = event?.taskIds.isNotEmpty == true ? event!.taskIds.first : null;
    _recurrence = _ruleToChoice(event?.recurrenceRule);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _timezone => 'UTC';

  Future<void> _pickStart() async {
    final value = await _pickDateTime(_startsAt);
    if (value == null) return;
    setState(() {
      _startsAt = value;
      if (!_endsAt.isAfter(value)) _endsAt = value.add(const Duration(hours: 1));
    });
  }

  Future<void> _pickEnd() async {
    final value = await _pickDateTime(_endsAt);
    if (value == null) return;
    if (!value.isAfter(_startsAt)) return;
    setState(() => _endsAt = value);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: initial);
    if (date == null || !mounted) return null;
    if (_allDay) return date;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(child: Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(PulseRadius.hero))), padding: EdgeInsets.fromLTRB(PulseSpace.xxl, PulseSpace.xxl, PulseSpace.xxl, PulseSpace.xxl + bottom), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(widget.event == null ? 'New event' : 'Edit event', style: AppTypography.title)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
      const SizedBox(height: PulseSpace.lg),
      TextField(controller: _title, autofocus: widget.event == null, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Title', hintText: 'What is happening?')),
      const SizedBox(height: PulseSpace.md),
      TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', hintText: 'Add useful context')),
      const SizedBox(height: PulseSpace.lg),
      _EditorRow(icon: Icons.schedule_rounded, label: 'Starts', value: _allDay ? _date(_startsAt) : '${_date(_startsAt)} · ${_time(_startsAt)}', onTap: _pickStart),
      const SizedBox(height: PulseSpace.sm),
      _EditorRow(icon: Icons.flag_outlined, label: 'Ends', value: _allDay ? _date(_endsAt) : '${_date(_endsAt)} · ${_time(_endsAt)}', onTap: _pickEnd),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('All day'), value: _allDay, onChanged: (value) => setState(() => _allDay = value)),
      DropdownButtonFormField<String?>(value: _recurrence, decoration: const InputDecoration(labelText: 'Repeat'), items: const [DropdownMenuItem<String?>(value: null, child: Text('Does not repeat')), DropdownMenuItem<String?>(value: 'DAILY', child: Text('Every day')), DropdownMenuItem<String?>(value: 'WEEKLY', child: Text('Every week')), DropdownMenuItem<String?>(value: 'MONTHLY', child: Text('Every month')), DropdownMenuItem<String?>(value: 'YEARLY', child: Text('Every year'))], onChanged: (value) => setState(() => _recurrence = value)),
      if (widget.tasks.isNotEmpty) ...[
        const SizedBox(height: PulseSpace.md),
        DropdownButtonFormField<String?>(value: _taskId, decoration: const InputDecoration(labelText: 'Linked task', hintText: 'Optional'), items: [const DropdownMenuItem<String?>(value: null, child: Text('No linked task')), ...widget.tasks.map((task) => DropdownMenuItem<String?>(value: task.id, child: Text(task.title, overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() => _taskId = value)),
      ],
      const SizedBox(height: PulseSpace.xl),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { final title = _title.text.trim(); if (title.isEmpty || !_endsAt.isAfter(_startsAt)) return; Navigator.pop(context, _EventDraft(title: title, description: _description.text.trim().isEmpty ? null : _description.text.trim(), startsAt: _startsAt, endsAt: _endsAt, allDay: _allDay, timezone: _timezone, recurrenceRule: _choiceToRule(_recurrence, _startsAt), taskId: _taskId)); }, icon: const Icon(Icons.check_rounded), label: Text(widget.event == null ? 'Create event' : 'Save changes'))),
    ])));
  }

  String? _choiceToRule(String? choice, DateTime start) {
    switch (choice) {
      case 'DAILY': return 'FREQ=DAILY;INTERVAL=1';
      case 'WEEKLY': return 'FREQ=WEEKLY;INTERVAL=1;BYDAY=${_rruleDay(start.weekday)}';
      case 'MONTHLY': return 'FREQ=MONTHLY;INTERVAL=1';
      case 'YEARLY': return 'FREQ=YEARLY;INTERVAL=1';
      default: return null;
    }
  }
}

class _EventDraft {
  const _EventDraft({required this.title, required this.description, required this.startsAt, required this.endsAt, required this.allDay, required this.timezone, required this.recurrenceRule, required this.taskId});
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String timezone;
  final String? recurrenceRule;
  final String? taskId;
}

class _EditorRow extends StatelessWidget {
  const _EditorRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(PulseRadius.medium), child: Padding(padding: const EdgeInsets.symmetric(vertical: PulseSpace.sm), child: Row(children: [Icon(icon, size: 21), const SizedBox(width: PulseSpace.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTypography.metadata.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 2), Text(value, style: AppTypography.label)])), const Icon(Icons.chevron_right_rounded)]));
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.date, required this.onAdd});
  final DateTime date;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => PulseCard(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: PulseColors.accentTint, shape: BoxShape.circle), child: const Icon(Icons.event_available_rounded, color: PulseColors.accent)), const SizedBox(height: PulseSpace.lg), Text('Nothing scheduled', style: AppTypography.title), const SizedBox(height: PulseSpace.xs), Text('Keep the day open or add something you need to be there for.', textAlign: TextAlign.center, style: AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: PulseSpace.lg), OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add event'))]));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: PulseSpace.sm), child: Text(label, style: AppTypography.label.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 40), const SizedBox(height: PulseSpace.md), Text('Calendar could not load', style: AppTypography.title), const SizedBox(height: PulseSpace.xs), Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall), const SizedBox(height: PulseSpace.lg), OutlinedButton(onPressed: onRetry, child: const Text('Try again'))]));
}

String _formatDate(DateTime date) => '${_weekday(date)}, ${_month(date)} ${date.day}';
String _weekday(DateTime date) => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday - 1];
String _month(DateTime date) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1];
String _date(DateTime date) => '${_month(date)} ${date.day}, ${date.year}';
String _time(DateTime date) => TimeOfDay.fromDateTime(date).format(navigatorKey.currentContext ?? _fallbackContext());
String _rruleDay(int weekday) => const ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'][weekday - 1];
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

BuildContext _fallbackContext() => throw StateError('Time formatting context is unavailable.');
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
