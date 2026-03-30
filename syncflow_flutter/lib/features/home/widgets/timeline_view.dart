import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/reminders/event_reminder_store.dart';
import '../../../core/reminders/system_alarm_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/event_model.dart';
import '../providers/home_dashboard_provider.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({
    super.key,
    required this.provider,
  });

  final HomeDashboardProvider provider;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  static const int _centerPage = 10000;
  late final PageController _pageController;
  late DateTime _anchorDate;
  bool _jumpingToCenter = false;

  @override
  void initState() {
    super.initState();
    _anchorDate = widget.provider.selectedDate;
    _pageController = PageController(initialPage: _centerPage);
  }

  @override
  void didUpdateWidget(covariant TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(widget.provider.selectedDate, _anchorDate)) {
      _anchorDate = widget.provider.selectedDate;
      if (_pageController.hasClients) {
        _jumpingToCenter = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(_centerPage);
          _jumpingToCenter = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.provider.loadEventsForFocusedRange,
      child: PageView.builder(
        controller: _pageController,
        physics: widget.provider.isMonthExpanded
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: (page) async {
          if (_jumpingToCenter || page == _centerPage) {
            return;
          }

          final delta = page - _centerPage;
          final nextDate =
              _normalizeDate(_anchorDate.add(Duration(days: delta)));
          await widget.provider.selectDate(nextDate);

          if (!mounted || !_pageController.hasClients) return;
          _anchorDate = widget.provider.selectedDate;
          _jumpingToCenter = true;
          _pageController.jumpToPage(_centerPage);
          _jumpingToCenter = false;
        },
        itemBuilder: (context, index) {
          final delta = index - _centerPage;
          final pageDate =
              _normalizeDate(_anchorDate.add(Duration(days: delta)));
          final events = widget.provider.eventsForDate(pageDate);

          return _TimelineDayPage(
            key: ValueKey(pageDate.toIso8601String()),
            date: pageDate,
            events: events,
            provider: widget.provider,
          );
        },
      ),
    );
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _TimelineDayPage extends StatelessWidget {
  const _TimelineDayPage({
    super.key,
    required this.date,
    required this.events,
    required this.provider,
  });

  final DateTime date;
  final List<EventModel> events;
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: events.isEmpty
              ? _EmptyDayHint(date: date)
              : Column(
                  key: ValueKey('list-${date.toIso8601String()}'),
                  children: events
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TimelineEventRow(
                            event: event,
                            provider: provider,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _EmptyDayHint extends StatelessWidget {
  const _EmptyDayHint({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('empty-${date.toIso8601String()}'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 84),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            DateFormat('M月d日').format(date),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '这一天还没有日程。左右滑动继续切天，或长按底部语音按钮，让 SyncFlow AI 直接在本机帮你生成安排。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({
    required this.event,
    required this.provider,
  });

  final EventModel event;
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminderConfig = provider.reminderConfigFor(event.id);
    final hasReminder = reminderConfig?.enabled == true;
    final conflicts = provider.conflictingEventsFor(event);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onLongPress: () async {
        if (!provider.startEventAction()) {
          return;
        }
        await _showEventActions(context);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.startLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.durationLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
                if (hasReminder) ...[
                  const SizedBox(height: 10),
                  _MiniTag(
                    label: '默认提醒',
                    background: AppTheme.accentBlue.withValues(alpha: 0.12),
                    foreground: AppTheme.accentBlue,
                  ),
                ],
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _MiniTag(
                    label: '冲突 ${conflicts.length}',
                    background: Colors.redAccent.withValues(alpha: 0.12),
                    foreground: Colors.redAccent,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _EventCard(
              event: event,
              conflicts: conflicts,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEventActions(BuildContext context) async {
    final theme = Theme.of(context);
    final reminderConfig = provider.reminderConfigFor(event.id);
    final hasReminder = reminderConfig?.enabled == true;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(hasReminder ? '调整默认提醒' : '恢复默认提醒'),
                  subtitle: const Text('通知中心和横幅提醒默认开启，也可以在这里单独调节。'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showReminderSheet(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alarm_add_outlined),
                  title: const Text('添加系统闹钟'),
                  subtitle: const Text('跳转到系统闹钟界面，用事件时间预填并让用户自行确认。'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final opened =
                        await SystemAlarmBridge.openAlarmComposer(event);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            opened ? '已打开系统闹钟界面。' : '当前设备暂时无法直接打开闹钟界面。',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('检查通知权限'),
                  subtitle: const Text('如果通知中心没有提醒，可直接打开系统通知设置和精确提醒授权。'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showPermissionActions(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('修改事件'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showEditSheet(context);
                  },
                ),
                if (hasReminder)
                  ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: const Text('关闭此事件提醒'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await provider.disableReminder(event.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已关闭该事件的默认提醒。')),
                        );
                      }
                    },
                  ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('删除事件'),
                  textColor: Colors.redAccent,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('删除这条事件？'),
                          content: Text('“${event.displayTitle}”将从本地日程中移除。'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('删除'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed == true && context.mounted) {
                      await provider.deleteEvent(context, event.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    provider.finishEventAction();
  }

  Future<void> _showPermissionActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系统提醒排查',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('如果通知中心没有收到提醒，先确认应用通知已开启，再确认系统允许精确提醒。'),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('打开系统通知设置'),
                  onTap: () async {
                    final opened =
                        await SystemAlarmBridge.openNotificationSettings();
                    if (context.mounted) {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            opened ? '已打开系统通知设置。' : '当前设备暂时无法直接打开通知设置。',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm_on_outlined),
                  title: const Text('打开精确提醒授权'),
                  onTap: () async {
                    final opened =
                        await SystemAlarmBridge.openExactAlarmSettings();
                    if (context.mounted) {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            opened ? '已尝试打开精确提醒授权页。' : '当前设备暂时无法直接打开授权页。',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReminderSheet(BuildContext context) async {
    final existing =
        provider.reminderConfigFor(event.id) ?? provider.buildDefaultReminderConfig();
    bool enabled = existing.enabled;
    int centerLead = existing.notificationCenterLeadMinutes;
    int bannerLead = existing.bannerLeadMinutes;
    int bannerInterval = existing.bannerRepeatIntervalMinutes;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '设置提醒',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.displayTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.68),
                        ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('为这个事件保留默认提醒'),
                    subtitle: const Text('关闭后将取消通知中心与横幅提醒。'),
                    value: enabled,
                    onChanged: (value) {
                      setModalState(() {
                        enabled = value;
                      });
                    },
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 12),
                    _ReminderDropdownField(
                      label: '提前多久进入通知中心',
                      value: centerLead,
                      options: const [0, 5, 10, 15, 30, 60, 120, 180],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            centerLead = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _ReminderDropdownField(
                      label: '提前多久开始横幅提醒',
                      value: bannerLead,
                      options: const [0, 5, 10, 15, 30, 60],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            bannerLead = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _ReminderDropdownField(
                      label: '横幅提醒间隔',
                      value: bannerInterval,
                      options: const [5, 10, 15, 30],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            bannerInterval = value;
                          });
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!enabled) {
                          await provider.disableReminder(event.id);
                        } else {
                          await provider.saveReminderConfig(
                            event.id,
                            EventReminderConfig(
                              enabled: true,
                              notificationCenterLeadMinutes: centerLead,
                              bannerLeadMinutes: bannerLead,
                              bannerRepeatIntervalMinutes: bannerInterval,
                            ),
                          );
                        }
                        if (context.mounted) {
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(enabled ? '提醒设置已保存。' : '已关闭该事件提醒。'),
                            ),
                          );
                        }
                      },
                      child: const Text('保存提醒设置'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSheet(BuildContext context) async {
    final titleController = TextEditingController(text: event.displayTitle);
    final durationController =
        TextEditingController(text: event.durationMinutes.toString());
    final keywordController =
        TextEditingController(text: event.targetKeyword ?? '');
    DateTime draftTime = event.startTime;
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '修改事件',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: draftTime,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2035),
                      );
                      if (pickedDate == null || !context.mounted) return;

                      final pickedClock = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(draftTime),
                      );
                      if (pickedClock == null) return;

                      setModalState(() {
                        draftTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedClock.hour,
                          pickedClock.minute,
                        );
                      });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '开始时间'),
                      child:
                          Text(DateFormat('yyyy-MM-dd HH:mm').format(draftTime)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '时长（分钟）'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keywordController,
                    decoration: const InputDecoration(labelText: '关键词（可选）'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: provider.isSubmittingIntent
                          ? null
                          : () async {
                              final duration =
                                  int.tryParse(durationController.text.trim());
                              if (titleController.text.trim().isEmpty ||
                                  duration == null ||
                                  duration <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请填写有效的标题和时长。')),
                                );
                                return;
                              }
                              await provider.updateEvent(
                                context,
                                eventId: event.id,
                                title: titleController.text.trim(),
                                startTime: draftTime,
                                durationMinutes: duration,
                                targetKeyword: keywordController.text.trim(),
                              );
                              if (context.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      child: provider.isSubmittingIntent
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存修改'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReminderDropdownField extends StatelessWidget {
  const _ReminderDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (minutes) => DropdownMenuItem<int>(
              value: minutes,
              child: Text(minutes == 0 ? '事件开始时' : '$minutes 分钟前'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.conflicts,
  });

  final EventModel event;
  final List<EventModel> conflicts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasLocation = event.location?.trim().isNotEmpty == true;
    final hasKeyword = event.targetKeyword?.trim().isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: conflicts.isNotEmpty ? Colors.redAccent : theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 112,
            decoration: BoxDecoration(
              color: conflicts.isNotEmpty ? Colors.redAccent : AppTheme.accentBlue,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(22)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.displayTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '专注时长 ${event.durationMinutes} 分钟',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.64),
                    ),
                  ),
                  if (conflicts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '与 ${conflicts.map((item) => item.displayTitle).join('、')} 存在时间冲突',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (hasLocation) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.52),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.58),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasKeyword) ...[
                    const SizedBox(height: 8),
                    Text(
                      '关键词：${event.targetKeyword}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
