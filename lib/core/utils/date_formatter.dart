import 'package:intl/intl.dart';
import 'ethiopian_calendar.dart';

enum CalendarType { gregorian, ethiopian }

class DateFormatter {
  static CalendarType _active = CalendarType.gregorian;
  static void setActive(CalendarType c) => _active = c;
  static CalendarType get active => _active;

  
  
  static const Duration addisOffset = Duration(hours: 3);

  
  
  
  static DateTime toAddisTime(DateTime d) {
    final a = d.toUtc().add(addisOffset);
    return DateTime(a.year, a.month, a.day, a.hour, a.minute, a.second,
        a.millisecond, a.microsecond);
  }

  
  
  
  static DateTime addisDayStart([DateTime? ref]) {
    final moment = ref ?? DateTime.now();
    final a = moment.toUtc().add(addisOffset);
    return DateTime.utc(a.year, a.month, a.day).subtract(addisOffset);
  }

  static DateTime addisMonthStart([DateTime? ref]) {
    final moment = ref ?? DateTime.now();
    final a = moment.toUtc().add(addisOffset);
    return DateTime.utc(a.year, a.month, 1).subtract(addisOffset);
  }

  static String formatDate(DateTime d, {String languageCode = 'en'}) {
    final local = toAddisTime(d);
    if (_active == CalendarType.ethiopian) {
      final e = EthiopianCalendar.gregorianToEthiopian(local);
      final monthName = EthiopianCalendar.monthNamesAmharic[e.month - 1];
      return '$monthName ${e.day}, ${e.year}';
    }
    return DateFormat.yMMMd(languageCode).format(local);
  }

  static String formatDateTime(DateTime d, {String languageCode = 'en'}) {
    final local = toAddisTime(d);
    if (_active == CalendarType.ethiopian) {
      final e = EthiopianCalendar.gregorianToEthiopian(local);
      final monthName = EthiopianCalendar.monthNamesAmharic[e.month - 1];
      final time = DateFormat.jm(languageCode).format(local);
      return '$monthName ${e.day}, ${e.year} $time';
    }
    return DateFormat.yMMMd(languageCode).add_jm().format(local);
  }

  static String formatDateTimeNoYear(DateTime d, {String languageCode = 'en'}) {
    final local = toAddisTime(d);
    if (_active == CalendarType.ethiopian) {
      final e = EthiopianCalendar.gregorianToEthiopian(local);
      final monthName = EthiopianCalendar.monthNamesAmharic[e.month - 1];
      final time = DateFormat.jm(languageCode).format(local);
      return '$monthName ${e.day} $time';
    }
    return DateFormat.MMMd(languageCode).add_jm().format(local);
  }

  static String formatMonthYear(DateTime d, {String languageCode = 'en'}) {
    final local = toAddisTime(d);
    if (_active == CalendarType.ethiopian) {
      final e = EthiopianCalendar.gregorianToEthiopian(local);
      return '${EthiopianCalendar.monthNamesAmharic[e.month - 1]} ${e.year}';
    }
    return DateFormat.yMMMM(languageCode).format(local);
  }

  static String formatFull(DateTime d, {String languageCode = 'en'}) {
    final local = toAddisTime(d);
    if (_active == CalendarType.ethiopian) {
      final e = EthiopianCalendar.gregorianToEthiopian(local);
      final monthName = EthiopianCalendar.monthNamesAmharic[e.month - 1];
      final weekday = EthiopianCalendar.weekdayNameAmharic(local);
      return '$weekday, $monthName ${e.day}, ${e.year}';
    }
    return DateFormat('EEEE, MMMM d, yyyy').format(local);
  }

  static String formatRelative(DateTime d, {String languageCode = 'en'}) {
    final now = toAddisTime(DateTime.now());
    final that = toAddisTime(d);
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(that.year, that.month, that.day);
    if (today == thatDay) return languageCode == 'am' ? 'ዛሬ' : 'Today';
    if (today.difference(thatDay).inDays == 1) return languageCode == 'am' ? 'ትናንት' : 'Yesterday';
    return formatDate(d, languageCode: languageCode);
  }

  static DateTime parseUserInput(int year, int month, int day, {required CalendarType calendar}) {
    if (calendar == CalendarType.ethiopian) {
      return EthiopianCalendar.ethiopianToGregorian(year, month, day);
    }
    return DateTime(year, month, day);
  }

  static EthDate toEthiopian(DateTime d) => EthiopianCalendar.gregorianToEthiopian(d);
}
