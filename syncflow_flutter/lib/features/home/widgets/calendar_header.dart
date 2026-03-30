import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/pages/settings_page.dart';
import '../providers/home_dashboard_provider.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.provider,
  });

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.64);
    final selectedDate = provider.selectedDate;
    final titleText = DateFormat('M 月 d 日', 'zh_CN').format(selectedDate);
    final subtitleText = '${DateFormat('EEEE', 'zh_CN').format(selectedDate)} · ${DateFormat('yyyy 年', 'zh_CN').format(selectedDate)}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.20 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? const Color(0xFF192338) : const Color(0xFFF5F7FC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  provider.isMonthExpanded ? '月视图' : '日视图',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: provider.isMonthExpanded ? '收起月视图' : '展开月视图',
                onPressed: provider.toggleCalendarExpanded,
                icon: Icon(provider.isMonthExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ),
              PopupMenuButton<_HeaderMenuAction>(
                tooltip: '更多',
                onSelected: (action) {
                  if (action == _HeaderMenuAction.settings) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_HeaderMenuAction>(
                    value: _HeaderMenuAction.settings,
                    child: Text('设置'),
                  ),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: provider.isMonthExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _WeekStrip(provider: provider),
            secondChild: _MonthCalendar(provider: provider),
          ),
        ],
      ),
    );
  }
}

enum _HeaderMenuAction { settings }

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.64);
    final chipColor = theme.brightness == Brightness.dark ? const Color(0xFF192338) : AppTheme.surfaceGray;

    return Row(
      children: provider.weekDates.map((date) {
        final isSelected = DateUtils.isSameDay(date, provider.selectedDate);
        final hasEvent = provider.hasEventsOnDate(date);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => provider.selectDate(date),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentBlue : chipColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E', 'zh_CN').format(date),
                      style: TextStyle(
                        color: isSelected ? Colors.white70 : mutedColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasEvent ? (isSelected ? Colors.white : AppTheme.accentBlue) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.provider});

  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subdued = theme.colorScheme.onSurface.withValues(alpha: 0.64);
    final isDark = theme.brightness == Brightness.dark;

    return TableCalendar<void>(
      locale: 'zh_CN',
      headerVisible: false,
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: provider.focusedMonth,
      selectedDayPredicate: (day) => DateUtils.isSameDay(day, provider.selectedDate),
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures.horizontalSwipe,
      eventLoader: (day) => provider.hasEventsOnDate(day) ? [1] : [],
      onPageChanged: provider.onMonthChanged,
      onDaySelected: (selectedDay, focusedDay) {
        provider.selectDate(selectedDay);
      },
      calendarBuilders: CalendarBuilders(
        todayBuilder: (context, day, focusedDay) {
          final isSelected = DateUtils.isSameDay(day, provider.selectedDate);
          if (isSelected) {
            return _CalendarChip(
              label: '${day.day}',
              backgroundColor: AppTheme.accentBlue,
              textColor: Colors.white,
              borderColor: AppTheme.accentBlue,
            );
          }
          return _CalendarChip(
            label: '${day.day}',
            backgroundColor: isDark ? const Color(0xFF1A2A47) : const Color(0xFFEAF0FF),
            textColor: isDark ? const Color(0xFFBFD1FF) : AppTheme.accentBlue,
            borderColor: AppTheme.accentBlue.withValues(alpha: 0.35),
          );
        },
        selectedBuilder: (context, day, focusedDay) {
          return _CalendarChip(
            label: '${day.day}',
            backgroundColor: AppTheme.accentBlue,
            textColor: Colors.white,
            borderColor: AppTheme.accentBlue,
          );
        },
        defaultBuilder: (context, day, focusedDay) {
          return _CalendarChip(
            label: '${day.day}',
            backgroundColor: Colors.transparent,
            textColor: theme.colorScheme.onSurface,
            borderColor: Colors.transparent,
          );
        },
        outsideBuilder: (context, day, focusedDay) {
          return _CalendarChip(
            label: '${day.day}',
            backgroundColor: Colors.transparent,
            textColor: subdued,
            borderColor: Colors.transparent,
          );
        },
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: TextStyle(color: theme.colorScheme.onSurface),
        weekendTextStyle: TextStyle(color: theme.colorScheme.onSurface),
        todayTextStyle: TextStyle(color: isDark ? const Color(0xFFBFD1FF) : AppTheme.accentBlue, fontWeight: FontWeight.w700),
        selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        todayDecoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
        selectedDecoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
        markerDecoration: const BoxDecoration(color: AppTheme.accentBlue, shape: BoxShape.circle),
        markersMaxCount: 1,
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekendStyle: TextStyle(color: subdued),
        weekdayStyle: TextStyle(color: subdued),
      ),
    );
  }
}

class _CalendarChip extends StatelessWidget {
  const _CalendarChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
