import 'package:flutter/material.dart';

enum DateSelectionType {
  single,
  range,
}

class DateSelectionBottomSheet extends StatefulWidget {
  const DateSelectionBottomSheet({
    super.key,
    this.initialDate,
    this.initialStartDate,
    this.initialEndDate,
  });

  final DateTime? initialDate;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  @override
  State<DateSelectionBottomSheet> createState() =>
      _DateSelectionBottomSheetState();
}

class _DateSelectionBottomSheetState
    extends State<DateSelectionBottomSheet> {

  DateSelectionType selectionType = DateSelectionType.range;

  late DateTime focusedMonth;

  DateTime? selectedDate;
  DateTime? rangeStart;
  DateTime? rangeEnd;

  @override
  void initState() {
    super.initState();

    selectedDate = widget.initialDate ?? DateTime.now();

    rangeStart = widget.initialStartDate;
    rangeEnd = widget.initialEndDate;

    focusedMonth = DateTime(
      selectedDate!.year,
      selectedDate!.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          // color: Colors.white,
          // Background and rounded corners now come from bottomSheetTheme
          // in AppTheme, so the sheet follows light / dark mode.
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  // No color set: text uses the theme's text color
                  const Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // SINGLE / RANGE
              _buildSelectionType(),

              const SizedBox(height: 15),

              // MONTH HEADER
              _buildMonthHeader(),

              const SizedBox(height: 10),

              // WEEK DAYS
              _buildWeekDays(),

              const SizedBox(height: 5),

              // CALENDAR
              _buildCalendar(),

              const SizedBox(height: 12),

              // SELECTED RANGE
              _buildSelectedDate(),

              const SizedBox(height: 12),

              // APPLY
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: Colors.blue,
                    // foregroundColor: Colors.white,
                    // Colors come from elevatedButtonTheme in AppTheme
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // CLEAR
              TextButton(
                onPressed: _clear,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    // color: Colors.blue,
                    // Color comes from textButtonTheme in AppTheme
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SINGLE DATE / DATE RANGE
  // ============================================================

  Widget _buildSelectionType() {
    final scheme = Theme.of(context).colorScheme;

    final bool isSingle =
        selectionType == DateSelectionType.single;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        // color: Colors.grey.shade100,
        color: scheme.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [

          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectionType =
                      DateSelectionType.single;
                  rangeStart = null;
                  rangeEnd = null;
                });
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSingle
                      ? scheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Single Date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSingle
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectionType =
                      DateSelectionType.range;
                  selectedDate = null;
                });
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isSingle
                      ? scheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: !isSingle
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTH HEADER
  // ============================================================

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        IconButton(
          onPressed: _previousMonth,
          icon: const Icon(
            Icons.chevron_left,
            size: 22,
          ),
        ),

        Text(
          '${_monthName(focusedMonth.month)} ${focusedMonth.year}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),

        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(
            Icons.chevron_right,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WEEK DAYS
  // ============================================================

  Widget _buildWeekDays() {
    final scheme = Theme.of(context).colorScheme;

    const days = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ];

    return Row(
      children: days.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 10,
                // color: Colors.grey,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // CALENDAR
  // ============================================================

  Widget _buildCalendar() {
    final firstDay = DateTime(
      focusedMonth.year,
      focusedMonth.month,
      1,
    );

    final lastDay = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    );

    // Sunday = 0
    final firstWeekday = firstDay.weekday % 7;

    final totalDays = lastDay.day;

    final totalCells =
        ((firstWeekday + totalDays) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 2,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {

        final dayNumber =
            index - firstWeekday + 1;

        if (dayNumber < 1 ||
            dayNumber > totalDays) {
          return const SizedBox();
        }

        final date = DateTime(
          focusedMonth.year,
          focusedMonth.month,
          dayNumber,
        );

        return _buildDay(date);
      },
    );
  }

  // ============================================================
  // DAY CELL
  // ============================================================

  Widget _buildDay(DateTime date) {
    final scheme = Theme.of(context).colorScheme;

    final bool isStart =
        rangeStart != null &&
            _isSameDay(date, rangeStart!);

    final bool isEnd =
        rangeEnd != null &&
            _isSameDay(date, rangeEnd!);

    // Only used in single-date mode. In range mode selectedDate holds a
    // default value (today) from initState, so it must not be painted as
    // selected, otherwise today looks like a chosen date when the sheet opens.
    final bool isSelected =
        selectionType == DateSelectionType.single &&
            selectedDate != null &&
            _isSameDay(date, selectedDate!);

    final bool isBetween =
        rangeStart != null &&
            rangeEnd != null &&
            date.isAfter(rangeStart!) &&
            date.isBefore(rangeEnd!);

    final bool isToday =
    _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: () {
        _selectDate(date);
      },
      child: Container(
        decoration: BoxDecoration(
          // Soft tint of the primary color for dates
          // between start and end.
          color: isBetween
              ? scheme.primary.withValues(alpha: 0.16)
              : Colors.transparent,

          borderRadius: BorderRadius.horizontal(
            left: isStart
                ? const Radius.circular(20)
                : Radius.zero,
            right: isEnd
                ? const Radius.circular(20)
                : Radius.zero,
          ),
        ),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isStart || isEnd || isSelected)
                  ? scheme.primary
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday &&
                  !isStart &&
                  !isEnd &&
                  !isSelected
                  ? Border.all(
                color: scheme.primary,
              )
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                // Selected days sit on the primary color,
                // everything else on the sheet background.
                color: (isStart ||
                    isEnd ||
                    isSelected)
                    ? scheme.onPrimary
                    : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SELECT DATE
  // ============================================================

  void _selectDate(DateTime date) {

    setState(() {

      if (selectionType ==
          DateSelectionType.single) {

        selectedDate = date;

        rangeStart = null;
        rangeEnd = null;

        return;
      }

      // DATE RANGE

      // First selection
      if (rangeStart == null ||
          rangeEnd != null) {

        rangeStart = date;
        rangeEnd = null;

        return;
      }

      // Second selection
      if (date.isBefore(rangeStart!)) {

        rangeEnd = rangeStart;
        rangeStart = date;

      } else {

        rangeEnd = date;
      }
    });
  }

  // ============================================================
  // PREVIOUS MONTH
  // ============================================================

  void _previousMonth() {
    setState(() {
      focusedMonth = DateTime(
        focusedMonth.year,
        focusedMonth.month - 1,
      );
    });
  }

  // ============================================================
  // NEXT MONTH
  // ============================================================

  void _nextMonth() {
    setState(() {
      focusedMonth = DateTime(
        focusedMonth.year,
        focusedMonth.month + 1,
      );
    });
  }

  // ============================================================
  // SELECTED DATE CONTAINER
  // ============================================================

  Widget _buildSelectedDate() {
    final scheme = Theme.of(context).colorScheme;

    String text;

    if (selectionType ==
        DateSelectionType.single) {

      text = selectedDate == null
          ? 'Select date'
          : _formatDate(selectedDate!);

    } else {

      if (rangeStart != null &&
          rangeEnd != null) {

        text =
        '${_formatDate(rangeStart!)} - '
            '${_formatDate(rangeEnd!)}';

      } else if (rangeStart != null) {

        text =
        '${_formatDate(rangeStart!)} - Select end date';

      } else {

        text = 'Select date range';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        // color: const Color(0xffEFF8FF),
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [

          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              // color: Colors.white,
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.calendar_month,
              color: scheme.primary,
              size: 18,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLY
  // ============================================================

  void _apply() {

    Navigator.pop(
      context,
      {
        'type': selectionType,
        'selectedDate': selectedDate,
        'startDate': rangeStart,
        'endDate': rangeEnd,
      },
    );
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void _clear() {

    setState(() {

      selectedDate = null;
      rangeStart = null;
      rangeEnd = null;
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isSameDay(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} '
        '${_monthName(date.month)} '
        '${date.year}';
  }

  String _monthName(int month) {

    const months = [
      '',
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
    ];

    return months[month];
  }
}