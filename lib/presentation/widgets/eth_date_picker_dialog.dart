import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ethiopian_calendar.dart';
import '../../core/utils/date_formatter.dart';

Future<DateTime?> showEthDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => EthDatePickerDialog(initialDate: initialDate, firstDate: firstDate, lastDate: lastDate),
  );
}

Future<DateTime?> showThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => GregorianDatePickerDialog(initialDate: initialDate, firstDate: firstDate, lastDate: lastDate),
  );
}

class GregorianDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  const GregorianDatePickerDialog({super.key, required this.initialDate, required this.firstDate, required this.lastDate});
  @override
  State<GregorianDatePickerDialog> createState() => _GregorianDatePickerDialogState();
}

class _GregorianDatePickerDialogState extends State<GregorianDatePickerDialog> {
  late DateTime _selected;
  late DateTime _display;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _display = DateTime(_selected.year, _selected.month, 1);
  }

  bool _isInRange(DateTime d) => !d.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) && !d.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

  void _changeMonth(int delta) {
    setState(() => _display = DateTime(_display.year, _display.month + delta, 1));
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    final daysInMonth = _daysInMonth(_display.year, _display.month);
    final weekday = _display.weekday % 7;
    final weekdayLetters = locale == 'am'
        ? const ['ሰ', 'ማ', 'ረ', 'ሐ', 'ዓ', 'ቅ', 'እ']
        : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final eth = EthiopianCalendar.gregorianToEthiopian(_selected);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMMd(locale).format(_selected),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.active == CalendarType.ethiopian
                        ? '${eth.day} ${EthiopianCalendar.monthNamesAmharic[eth.month - 1]} ${eth.year}'
                        : DateFormat.EEEE(locale).format(_selected),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                  Text(
                    DateFormat.yMMMM(locale).format(_display),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: weekdayLetters
                    .map((w) => Expanded(child: Center(child: Text(w, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight, fontWeight: FontWeight.w600)))))
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.1),
                itemCount: weekday + daysInMonth,
                itemBuilder: (_, idx) {
                  if (idx < weekday) return const SizedBox.shrink();
                  final day = idx - weekday + 1;
                  final d = DateTime(_display.year, _display.month, day);
                  final isSelected = _selected.year == d.year && _selected.month == d.month && _selected.day == d.day;
                  final inRange = _isInRange(d);
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: inRange
                            ? () {
                                setState(() => _selected = d);
                              }
                            : null,
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: !inRange
                                  ? theme.disabledColor
                                  : isSelected
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white
                                          : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text(MaterialLocalizations.of(context).okButtonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EthDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  const EthDatePickerDialog({super.key, required this.initialDate, required this.firstDate, required this.lastDate});
  @override
  State<EthDatePickerDialog> createState() => _EthDatePickerDialogState();
}

class _EthDatePickerDialogState extends State<EthDatePickerDialog> {
  late EthDate _selected;
  late EthDate _display;
  late DateTime _selectedGregorian;

  @override
  void initState() {
    super.initState();
    _selected = EthiopianCalendar.gregorianToEthiopian(widget.initialDate);
    _display = EthDate(_selected.year, _selected.month, 1);
    _selectedGregorian = widget.initialDate;
  }

  bool _isInRange(DateTime g) => !g.isBefore(widget.firstDate) && !g.isAfter(widget.lastDate);

  void _changeMonth(int delta) {
    var y = _display.year;
    var m = _display.month + delta;
    while (m < 1) {
      m += 13;
      y -= 1;
    }
    while (m > 13) {
      m -= 13;
      y += 1;
    }
    setState(() => _display = EthDate(y, m, 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final daysInMonth = EthiopianCalendar.daysInEthiopianMonth(_display.year, _display.month);
    final firstOfMonthGreg = EthiopianCalendar.ethiopianToGregorian(_display.year, _display.month, 1);
    final weekday = firstOfMonthGreg.weekday % 7;
    final selected = _selected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selected.day} ${EthiopianCalendar.monthNamesAmharic[selected.month - 1]} ${selected.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.active == CalendarType.ethiopian
                        ? DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(DateFormatter.toAddisTime(_selectedGregorian))
                        : DateFormatter.formatDate(_selectedGregorian, languageCode: Localizations.localeOf(context).languageCode),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                  Text(
                    '${EthiopianCalendar.monthNamesAmharic[_display.month - 1]} ${_display.year}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: ['ሰ', 'ማ', 'ረ', 'ሐ', 'ዓ', 'ቅ', 'እ']
                    .map((w) => Expanded(child: Center(child: Text(w, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight, fontWeight: FontWeight.w600)))))
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.1),
                itemCount: weekday + daysInMonth,
                itemBuilder: (_, idx) {
                  if (idx < weekday) return const SizedBox.shrink();
                  final day = idx - weekday + 1;
                  final g = EthiopianCalendar.ethiopianToGregorian(_display.year, _display.month, day);
                  final isSelected = _selected.year == _display.year && _selected.month == _display.month && _selected.day == day;
                  final inRange = _isInRange(g);
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: inRange
                            ? () {
                                setState(() {
                                  _selected = EthDate(_display.year, _display.month, day);
                                  _selectedGregorian = g;
                                });
                              }
                            : null,
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: !inRange
                                  ? theme.disabledColor
                                  : isSelected
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white
                                          : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context, _selectedGregorian),
                    child: Text(MaterialLocalizations.of(context).okButtonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
