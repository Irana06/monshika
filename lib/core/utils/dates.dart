import 'package:intl/intl.dart';

import '../../l10n/strings.dart';

class DateRange {
  const DateRange(this.start, this.end);

  /// Inklusif.
  final DateTime start;

  /// Eksklusif.
  final DateTime end;

  int get days => end.difference(start).inDays;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  DateRange shift(int periods, String period) => switch (period) {
        'weekly' => DateRange(start.add(Duration(days: 7 * periods)), end.add(Duration(days: 7 * periods))),
        'yearly' => DateRange(DateTime(start.year + periods, start.month, start.day),
            DateTime(end.year + periods, end.month, end.day)),
        _ => DateRange(addMonths(start, periods), addMonths(end, periods)),
      };

  @override
  bool operator ==(Object other) => other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addMonths(DateTime d, int months) {
  final y = d.year + ((d.month - 1 + months) ~/ 12);
  final m = (d.month - 1 + months) % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
}

/// Periode bulanan yang dimulai pada [startDay] (mis. tanggal gajian 25).
/// Tanggal 29 sampai 31 dipotong ke hari terakhir pada bulan yang lebih pendek.
DateRange monthRange(DateTime ref, {int startDay = 1}) {
  final day = startDay.clamp(1, 31);
  DateTime startOf(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  var start = startOf(ref.year, ref.month);
  if (ref.isBefore(start)) start = startOf(ref.year, ref.month - 1);
  return DateRange(start, startOf(start.year, start.month + 1));
}

/// [firstWeekday] mengikuti DateTime.monday (1) sampai DateTime.sunday (7).
DateRange weekRange(DateTime ref, {int firstWeekday = DateTime.monday}) {
  final d = dateOnly(ref);
  final diff = (d.weekday - firstWeekday) % 7;
  final start = d.subtract(Duration(days: diff));
  return DateRange(start, start.add(const Duration(days: 7)));
}

DateRange yearRange(DateTime ref) => DateRange(DateTime(ref.year), DateTime(ref.year + 1));

DateRange dayRange(DateTime ref) {
  final d = dateOnly(ref);
  return DateRange(d, d.add(const Duration(days: 1)));
}

DateRange periodRange(String period, DateTime ref, {int monthStartDay = 1, int firstWeekday = DateTime.monday}) =>
    switch (period) {
      'weekly' => weekRange(ref, firstWeekday: firstWeekday),
      'yearly' => yearRange(ref),
      _ => monthRange(ref, startDay: monthStartDay),
    };

const kJpWeekdays = ['月', '火', '水', '木', '金', '土', '日'];
const kJpMonths = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];

String get _locale => S.current.dateLocale;

/// Nama hari singkat. Kanji bila gaya Jepang aktif.
String weekdayShort(int weekday) {
  if (S.current.jp) return kJpWeekdays[weekday - 1];
  // 2024-01-01 adalah hari Senin.
  return DateFormat('E', _locale).format(DateTime(2024, 1, weekday));
}

/// Nama bulan singkat. Kanji bila gaya Jepang aktif.
String monthShort(DateTime d) => S.current.jp ? kJpMonths[d.month - 1] : DateFormat('MMM', _locale).format(d);

String fmtDate(DateTime d) => DateFormat('d MMM yyyy', _locale).format(d);
String fmtDateShort(DateTime d) => DateFormat('d MMM', _locale).format(d);
String fmtDateLong(DateTime d) => DateFormat('EEEE, d MMMM yyyy', _locale).format(d);
String fmtTime(DateTime d) => DateFormat('HH:mm', _locale).format(d);
String fmtMonthYear(DateTime d) => DateFormat('MMMM yyyy', _locale).format(d);
String fmtMonthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

String fmtRange(DateRange r) {
  final last = r.end.subtract(const Duration(days: 1));
  if (r.start.day == 1 && r.end.day == 1 && r.days >= 28 && r.days <= 31) return fmtMonthYear(r.start);
  if (r.start.year == last.year) return '${fmtDateShort(r.start)} - ${fmtDate(last)}';
  return '${fmtDate(r.start)} - ${fmtDate(last)}';
}

/// "Hari ini", "Kemarin", atau tanggal lengkap.
String fmtRelativeDay(DateTime d) {
  final s = S.current;
  final today = dateOnly(DateTime.now());
  final diff = today.difference(dateOnly(d)).inDays;
  if (diff == 0) return s.today;
  if (diff == 1) return s.yesterday;
  if (diff == -1) return s.tomorrow;
  return DateFormat('EEEE, d MMM yyyy', _locale).format(d);
}

/// Salam sesuai waktu: (label Jepang, salam biasa).
(String jp, String text) greeting([DateTime? now]) {
  final s = S.current;
  final h = (now ?? DateTime.now()).hour;
  if (h < 4) return ('こんばんは', s.t('Selamat malam', 'Good evening'));
  if (h < 11) return ('おはよう', s.t('Selamat pagi', 'Good morning'));
  if (h < 15) return ('こんにちは', s.t('Selamat siang', 'Good afternoon'));
  if (h < 18) return ('こんにちは', s.t('Selamat sore', 'Good afternoon'));
  return ('こんばんは', s.t('Selamat malam', 'Good evening'));
}

/// Musim untuk motif dekoratif.
enum Season { spring, summer, autumn, winter }

Season seasonOf(DateTime d) => switch (d.month) {
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      9 || 10 || 11 => Season.autumn,
      _ => Season.winter,
    };

extension SeasonX on Season {
  String get motif => switch (this) { Season.spring => '🌸', Season.summer => '🎐', Season.autumn => '🍁', Season.winter => '❄️' };
}
