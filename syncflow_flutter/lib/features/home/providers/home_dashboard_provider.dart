import 'package:flutter/material.dart';

import '../../../core/reminders/event_reminder_store.dart';
import '../../../core/reminders/reminder_coordinator.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/intent_parse_models.dart';
import '../../../data/repositories/schedule_repository.dart';

class HomeDashboardProvider extends ChangeNotifier {
  HomeDashboardProvider({
    required ScheduleRepository repository,
    required AppSettingsController settingsController,
    required EventReminderStore reminderStore,
    required ReminderCoordinator reminderCoordinator,
  })  : _repository = repository,
        _settingsController = settingsController,
        _reminderStore = reminderStore,
        _reminderCoordinator = reminderCoordinator;

  final ScheduleRepository _repository;
  final AppSettingsController _settingsController;
  final EventReminderStore _reminderStore;
  final ReminderCoordinator _reminderCoordinator;

  GlobalKey<AnimatedListState> _timelineListKey =
      GlobalKey<AnimatedListState>();
  final TextEditingController textController = TextEditingController();

  DateTime _selectedDate = _normalizeDate(DateTime.now());
  DateTime _focusedMonth = _normalizeDate(DateTime.now());
  bool _isMonthExpanded = false;
  bool _isLoadingEvents = false;
  bool _isSubmittingIntent = false;
  bool _isEventActionOpen = false;
  int _dayTransitionDirection = 1;
  DateTime? _lastIntentSubmittedAt;
  String? _lastIntentPayload;
  List<EventModel> _allEvents = <EventModel>[];
  List<EventModel> _visibleEvents = <EventModel>[];

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedMonth => _focusedMonth;
  bool get isMonthExpanded => _isMonthExpanded;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isSubmittingIntent => _isSubmittingIntent;
  bool get isEventActionOpen => _isEventActionOpen;
  int get dayTransitionDirection => _dayTransitionDirection;
  GlobalKey<AnimatedListState> get timelineListKey => _timelineListKey;
  List<EventModel> get visibleEvents => List.unmodifiable(_visibleEvents);

  Future<void> initialize() async {
    await loadEventsForFocusedRange();
  }

  List<DateTime> get weekDates {
    final weekStart =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    return List<DateTime>.generate(
      7,
      (index) => _normalizeDate(weekStart.add(Duration(days: index))),
    );
  }

  EventReminderConfig buildDefaultReminderConfig({bool enabled = true}) {
    final settings = _settingsController.settings;
    return EventReminderConfig(
      enabled: enabled,
      notificationCenterLeadMinutes: settings.notificationCenterLeadMinutes,
      bannerLeadMinutes: settings.bannerLeadMinutes,
      bannerRepeatIntervalMinutes: settings.bannerRepeatIntervalMinutes,
    );
  }

  EventReminderConfig? reminderConfigFor(int eventId) =>
      _reminderStore.configFor(eventId);

  Future<void> saveReminderConfig(
    int eventId,
    EventReminderConfig config,
  ) async {
    await _reminderStore.saveFor(eventId, config);
    EventModel? event;
    for (final item in _allEvents) {
      if (item.id == eventId) {
        event = item;
        break;
      }
    }
    if (event != null) {
      await _reminderCoordinator.syncForEvent(event);
    }
    notifyListeners();
  }

  Future<void> disableReminder(int eventId) async {
    await _reminderStore.removeFor(eventId);
    await _reminderCoordinator.cancelForEvent(eventId);
    notifyListeners();
  }

  Future<void> loadEventsForFocusedRange() async {
    _isLoadingEvents = true;
    notifyListeners();

    try {
      final range = _buildQueryRange(_focusedMonth);
      _allEvents = await _repository.fetchEvents(
        startDate: range.$1,
        endDate: range.$2,
      );
      _syncVisibleEvents(animated: false);
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }

  void toggleCalendarExpanded() {
    _isMonthExpanded = !_isMonthExpanded;
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    if (!DateUtils.isSameDay(date, _selectedDate)) {
      _dayTransitionDirection = date.isAfter(_selectedDate) ? 1 : -1;
    }

    final monthChanged =
        _selectedDate.month != date.month || _selectedDate.year != date.year;

    _selectedDate = _normalizeDate(date);
    _focusedMonth = _normalizeDate(DateTime(date.year, date.month, 1));
    _syncVisibleEvents(animated: false);
    notifyListeners();

    if (monthChanged) {
      await loadEventsForFocusedRange();
    }
  }

  Future<void> onMonthChanged(DateTime month) async {
    _focusedMonth = _normalizeDate(DateTime(month.year, month.month, 1));
    notifyListeners();
    await loadEventsForFocusedRange();
  }

  Future<void> goToNextDay() async {
    _dayTransitionDirection = 1;
    await selectDate(_selectedDate.add(const Duration(days: 1)));
  }

  Future<void> goToPreviousDay() async {
    _dayTransitionDirection = -1;
    await selectDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  bool startEventAction() {
    if (_isEventActionOpen || _isSubmittingIntent) {
      return false;
    }
    _isEventActionOpen = true;
    notifyListeners();
    return true;
  }

  void finishEventAction() {
    if (!_isEventActionOpen) {
      return;
    }
    _isEventActionOpen = false;
    notifyListeners();
  }

  bool hasEventsOnDate(DateTime date) {
    return _allEvents.any((event) => event.occursOn(date));
  }

  List<EventModel> eventsForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    final items = _allEvents.where((event) => event.occursOn(normalized)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return List.unmodifiable(items);
  }

  Future<bool> submitTextIntent(BuildContext context) async {
    final text = textController.text.trim();
    if (text.isEmpty) {
      _showMessage(context, '请输入你想让 SyncFlow 安排的内容。');
      return false;
    }

    final submitted = await _submitIntent(context, text);
    if (submitted) {
      textController.clear();
    }
    return submitted;
  }

  Future<bool> _submitIntent(BuildContext context, String text) async {
    if (_isSubmittingIntent) {
      return false;
    }
    if (_isDuplicateIntent(text)) {
      if (context.mounted) {
        _showMessage(context, '这条输入刚刚已经在本机解析过了。');
      }
      return false;
    }

    _isSubmittingIntent = true;
    _lastIntentPayload = text;
    _lastIntentSubmittedAt = DateTime.now();
    notifyListeners();

    try {
      final response = await _repository.parseIntent(text);
      if (!context.mounted) {
        return false;
      }

      final messenger = ScaffoldMessenger.of(context);
      await _syncAffectedEvents(response);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(response.message),
            behavior: SnackBarBehavior.floating,
          ),
        );

      await loadEventsForFocusedRange();
      if (!context.mounted) {
        return false;
      }
      _syncVisibleEvents(animated: true);
      return true;
    } catch (error) {
      if (!context.mounted) {
        return false;
      }
      _showMessage(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isSubmittingIntent = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> updateEvent(
    BuildContext context, {
    required int eventId,
    required String title,
    required DateTime startTime,
    required int durationMinutes,
    String? targetKeyword,
  }) async {
    _isSubmittingIntent = true;
    notifyListeners();

    try {
      final updated = await _repository.updateEvent(
        eventId: eventId,
        title: title,
        startTime: startTime,
        durationMinutes: durationMinutes,
        targetKeyword: targetKeyword,
      );
      _upsertEvent(updated, animated: true);
      await _reminderCoordinator.syncForEvent(updated);
      if (!context.mounted) {
        return;
      }
      _showMessage(context, '本地日程已更新。');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isSubmittingIntent = false;
      notifyListeners();
    }
  }

  Future<void> deleteEvent(BuildContext context, int eventId) async {
    _isSubmittingIntent = true;
    notifyListeners();

    try {
      final deleted = await _repository.deleteEvent(eventId);
      _allEvents = _allEvents.where((event) => event.id != deleted.id).toList();
      _syncVisibleEvents(animated: true);
      await disableReminder(eventId);
      if (!context.mounted) {
        return;
      }
      _showMessage(context, '本地日程已删除。');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isSubmittingIntent = false;
      notifyListeners();
    }
  }

  Future<void> _syncAffectedEvents(IntentParseResponse response) async {
    for (final event in response.affectedEvents) {
      if (event.status == 1) {
        await _reminderCoordinator.syncForEvent(event);
      } else {
        await disableReminder(event.id);
      }
    }
  }

  void _upsertEvent(EventModel updated, {required bool animated}) {
    final index = _allEvents.indexWhere((event) => event.id == updated.id);
    if (index == -1) {
      _allEvents = <EventModel>[..._allEvents, updated];
    } else {
      _allEvents[index] = updated;
    }
    _allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    _syncVisibleEvents(animated: animated);
  }

  void _syncVisibleEvents({required bool animated}) {
    final next = _allEvents.where((event) => event.occursOn(_selectedDate)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (!animated || timelineListKey.currentState == null) {
      _timelineListKey = GlobalKey<AnimatedListState>();
      _visibleEvents = next;
      return;
    }

    final listState = timelineListKey.currentState!;
    final previous = List<EventModel>.from(_visibleEvents);

    for (int index = previous.length - 1; index >= 0; index--) {
      final oldItem = previous[index];
      if (!next.any((item) => item.id == oldItem.id)) {
        final removed = _visibleEvents.removeAt(index);
        listState.removeItem(
          index,
          (context, animation) =>
              _RemovedTimelineCard(event: removed, animation: animation),
          duration: const Duration(milliseconds: 260),
        );
      }
    }

    for (int index = 0; index < next.length; index++) {
      final newItem = next[index];
      final existingIndex =
          _visibleEvents.indexWhere((item) => item.id == newItem.id);
      if (existingIndex == -1) {
        _visibleEvents.insert(index, newItem);
        listState.insertItem(
          index,
          duration: const Duration(milliseconds: 320),
        );
      } else {
        _visibleEvents[existingIndex] = newItem;
      }
    }
  }

  (DateTime, DateTime) _buildQueryRange(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return (firstDay, lastDay);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isDuplicateIntent(String text) {
    final submittedAt = _lastIntentSubmittedAt;
    final lastPayload = _lastIntentPayload;
    if (submittedAt == null || lastPayload == null) {
      return false;
    }

    final isSamePayload = lastPayload == text;
    final isTooSoon =
        DateTime.now().difference(submittedAt) < const Duration(seconds: 2);
    return isSamePayload && isTooSoon;
  }

  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }
}

class _RemovedTimelineCard extends StatelessWidget {
  const _RemovedTimelineCard({
    required this.event,
    required this.animation,
  });

  final EventModel event;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final subtitle = event.location?.trim().isNotEmpty == true
        ? '${event.startLabel} · ${event.durationLabel} · ${event.location!.trim()}'
        : '${event.startLabel} · ${event.durationLabel}';

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            child: ListTile(
              title: Text(event.displayTitle),
              subtitle: Text(subtitle),
            ),
          ),
        ),
      ),
    );
  }
}
