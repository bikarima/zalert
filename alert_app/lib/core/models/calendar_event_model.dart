class CalendarEventModel {
  final String id;
  final String title;
  final String currency;
  final String date;
  final String time;
  final String timeUtc;   // برای scheduled notification
  final String impact;
  final String forecast;
  final String previous;
  final String actual;
  final String url;

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.currency,
    required this.date,
    required this.time,
    required this.timeUtc,
    required this.impact,
    required this.forecast,
    required this.previous,
    required this.actual,
    required this.url,
  });

  factory CalendarEventModel.fromJson(Map<String, dynamic> j) =>
      CalendarEventModel(
        id:       j['id']       as String? ?? '',
        title:    j['title']    as String? ?? '',
        currency: j['currency'] as String? ?? '',
        date:     j['date']     as String? ?? '',
        time:     j['time']     as String? ?? '',
        timeUtc:  j['time_utc'] as String? ?? '',
        impact:   j['impact']   as String? ?? 'low',
        forecast: j['forecast'] as String? ?? '',
        previous: j['previous'] as String? ?? '',
        actual:   j['actual']   as String? ?? '',
        url:      j['url']      as String? ?? '',
      );

  bool get hasActual    => actual.isNotEmpty;
  bool get isHighImpact => impact == 'high';
  bool get isMedImpact  => impact == 'medium';
  bool get isHoliday    => impact == 'holiday';

  /// زمان UTC برای scheduled notification
  DateTime? get eventTimeUtc {
    if (timeUtc.isEmpty) return null;
    try {
      return DateTime.parse(timeUtc).toUtc();
    } catch (_) {
      return null;
    }
  }

  /// چقدر مونده تا این رویداد (null اگه گذشته یا نامعلوم)
  Duration? get timeUntil {
    final t = eventTimeUtc;
    if (t == null) return null;
    final diff = t.difference(DateTime.now().toUtc());
    return diff.isNegative ? null : diff;
  }
}
