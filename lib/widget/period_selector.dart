import 'package:flutter/material.dart';

enum ExpensePeriod {
  today,
  week,
  month,
}

class PeriodSelector extends StatefulWidget {
  final ExpensePeriod initialPeriod;
  final ValueChanged<ExpensePeriod> onChanged;

  const PeriodSelector({
    super.key,
    this.initialPeriod = ExpensePeriod.today,
    required this.onChanged,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late ExpensePeriod selectedPeriod = widget.initialPeriod;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // color: Colors.white,
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.grey,
        //     spreadRadius: 0.05,
        //     blurRadius: 0.1,
        //   )
        // ],
        // Track color follows the theme: white in light mode, navy in dark.
        // A thin border replaces the old shadow so it also shows in dark mode.
        color: scheme.surfaceContainer,
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          _periodItem(
            title: 'Today',
            period: ExpensePeriod.today,
          ),
          _periodItem(
            title: 'Week',
            period: ExpensePeriod.week,
          ),
          _periodItem(
            title: 'Month',
            period: ExpensePeriod.month,
          ),
        ],
      ),
    );
  }

  Widget _periodItem({
    required String title,
    required ExpensePeriod period,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bool isSelected = selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Avoid redundant reloads if the user taps the already-active pill.
          if (selectedPeriod == period) return;

          setState(() {
            selectedPeriod = period;
          });

          // This is the one line that was missing — notifies the
          // parent (TransactionListScreen) which period was picked,
          // so it can call _loadToday() / _loadThisWeek() / _loadThisMonth().
          widget.onChanged(period);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // color: isSelected
            //     ? AppColors.mint
            //     : Colors.transparent,
            // primary is mint in dark mode and a deeper green in light mode
            color: isSelected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              // color: isSelected
              //     ? Colors.white
              //     : const Color(0xFF768088),
              // onPrimary stays readable on the selected pill in both modes
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}