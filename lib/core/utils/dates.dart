import 'package:intl/intl.dart';

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
DateRange monthRange(DateTime ref, {int startDay = 1}) {
  final day = startDay.clamp(1, 28);
  var start = DateTime(ref.year, ref.month, day);
  if (ref.isBefore(start)) start = DateTime(ref.year, ref.month - 1, day);
  return DateRange(start, DateTime(start.year, start.month + 1, day));
}

/// [firstWeekday] mengikuti DateTime.monday (1) … DateTime.sunday (7).
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

String fmtDate(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);
String fmtDateShort(DateTime d) => DateFormat('d MMM', 'id_ID').format(d);
String fmtDateLong(DateTime d) => DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d);
String fmtTime(DateTime d) => DateFormat('HH:mm', 'id_ID').format(d);
String fmtMonthYear(DateTime d) => DateFormat('MMMM yyyy', 'id_ID').format(d);
String fmtMonthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

String fmtRange(DateRange r) {
  final last = r.end.subtract(const Duration(days: 1));
  if (r.start.day == 1 && r.end.day == 1 && r.days >= 28 && r.days <= 31) return fmtMonthYear(r.start);
  if (r.start.year == last.year) return '${fmtDateShort(r.start)} – ${fmtDate(last)}';
  return '${fmtDate(r.start)} – ${fmtDate(last)}';
}

/// "Hari ini", "Kemarin", atau tanggal lengkap.
String fmtRelativeDay(DateTime d) {
  final today = dateOnly(DateTime.now());
  final day = dateOnly(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  if (diff == -1) return 'Besok';
  return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(d);
}

/// Salam sesuai waktu, dengan sentuhan Jepang.
(String jp, String id) greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 4) return ('こんばんは', 'Selamat malam');
  if (h < 11) return ('おはよう', 'Selamat pagi');
  if (h < 15) return ('こんにちは', 'Selamat siang');
  if (h < 18) return ('こんにちは', 'Selamat sore');
  return ('こんばんは', 'Selamat malam');
}

/// Musim (季節) untuk motif dekoratif.
enum Season { spring, summer, autumn, winter }

Season seasonOf(DateTime d) => switch (d.month) {
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      9 || 10 || 11 => Season.autumn,
      _ => Season.winter,
    };

extension SeasonX on Season {
  String get kanji => switch (this) { Season.spring => '春', Season.summer => '夏', Season.autumn => '秋', Season.winter => '冬' };
  String get motif => switch (this) { Season.spring => '🌸', Season.summer => '🎐', Season.autumn => '🍁', Season.winter => '❄️' };
}
