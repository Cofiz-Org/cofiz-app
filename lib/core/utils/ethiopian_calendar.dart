import 'package:ethio_calendar/ethio_calendar.dart' as ec;

class EthDate {
  final int year;
  final int month;
  final int day;
  const EthDate(this.year, this.month, this.day);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

class EthiopianCalendar {
  static const monthNamesAmharic = <String>[
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ',
  ];

  static const weekdayNamesAmharic = <String>[
    'ሰኞ',
    'ማክሰኞ',
    'ረቡዕ',
    'ሐሙስ',
    'ዓርብ',
    'ቅዳሜ',
    'እሁድ',
  ];

  static String weekdayNameAmharic(DateTime d) =>
      weekdayNamesAmharic[d.weekday - 1];

  static bool isEthiopianLeapYear(int year) => ec.isEthiopianLeapYear(year);

  static int daysInEthiopianMonth(int year, int month) => ec.ethiopianDaysInMonth(year, month);

  static EthDate gregorianToEthiopian(DateTime g) {
    final e = ec.EthiopianDate.fromGregorian(g);
    return EthDate(e.year, e.month, e.day);
  }

  static DateTime ethiopianToGregorian(int year, int month, int day) {
    return ec.EthiopianDate(year, month, day).toGregorian();
  }
}
