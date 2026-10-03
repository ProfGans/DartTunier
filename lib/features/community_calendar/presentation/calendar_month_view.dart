import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/community_calendar.dart';

/// Monday-first month grid. Event details remain in the agenda below it.
class CalendarMonthView extends StatefulWidget {
  const CalendarMonthView({
    super.key,
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onDaySelected,
    this.today,
  });

  final DateTime month;
  final List<CommunityCalendarEvent> events;
  final DateTime? selectedDay, today;
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(widget.month.year, widget.month.month);
    final offset = first.weekday - DateTime.monday;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final weeks = ((offset + days) / 7).ceil();
    final byDay = <int, List<CommunityCalendarEvent>>{};
    for (final event in widget.events) {
      final date = event.startsAt.toLocal();
      if (date.year == first.year && date.month == first.month) {
        byDay.putIfAbsent(date.day, () => []).add(event);
      }
    }
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(336.0, constraints.maxWidth);
        final detailed =
            width >= 700 * MediaQuery.textScalerOf(context).scale(1);
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: width > constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final name in const [
                        'Mo',
                        'Di',
                        'Mi',
                        'Do',
                        'Fr',
                        'Sa',
                        'So',
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(name, textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  ),
                  for (var week = 0; week < weeks; week++)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final day = week * 7 + weekday - offset + 1;
                                  if (day < 1 || day > days) {
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        border: Border.all(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                    );
                                  }
                                  final date = DateTime(
                                    first.year,
                                    first.month,
                                    day,
                                  );
                                  final events = byDay[day] ?? [];
                                  final selected = DateUtils.isSameDay(
                                    date,
                                    widget.selectedDay,
                                  );
                                  final today = DateUtils.isSameDay(
                                    date,
                                    widget.today ?? DateTime.now(),
                                  );
                                  final label =
                                      '$day.${first.month}.${first.year}, ${events.length} Termine${today ? ', heute' : ''}';
                                  return Semantics(
                                    selected: selected,
                                    label: label,
                                    child: Tooltip(
                                      message: [
                                        label,
                                        ...events.map((e) => e.title),
                                      ].join('\n'),
                                      child: Material(
                                        color: selected
                                            ? colors.primaryContainer
                                            : colors.surface,
                                        child: InkWell(
                                          key: ValueKey('calendar-day-$day'),
                                          onTap: () =>
                                              widget.onDaySelected(date),
                                          child: Container(
                                            constraints: BoxConstraints(
                                              minHeight: detailed ? 112 : 64,
                                            ),
                                            padding: EdgeInsets.all(
                                              detailed ? 8 : 2,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: today
                                                    ? colors.primary
                                                    : colors.outlineVariant,
                                                width: today ? 2 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: detailed
                                                  ? CrossAxisAlignment.start
                                                  : CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '$day',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        today || selected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                if (events.isNotEmpty &&
                                                    !detailed)
                                                  Text(
                                                    '•${events.length}',
                                                    style: TextStyle(
                                                      color: colors.primary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (detailed) ...[
                                                  for (final event
                                                      in events.take(2))
                                                    Text(
                                                      event.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: colors.primary,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  if (events.length > 2)
                                                    Text(
                                                      '+${events.length - 2} weitere',
                                                    ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
