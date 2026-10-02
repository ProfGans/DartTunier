/// Local calendar-day boundaries; the end day is inclusive, even across DST.
class StatisticsPeriod {
  StatisticsPeriod(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      endExclusive = DateTime(end.year, end.month, end.day + 1);

  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime? value) =>
      value != null && !value.isBefore(start) && value.isBefore(endExclusive);
}
