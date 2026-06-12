class CalendarEventModel {
  final String id;
  final String title;
  final String currency;
  final String date;
  final String time;
  final String impact;   // high / medium / low / holiday
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
        impact:   j['impact']   as String? ?? 'low',
        forecast: j['forecast'] as String? ?? '',
        previous: j['previous'] as String? ?? '',
        actual:   j['actual']   as String? ?? '',
        url:      j['url']      as String? ?? '',
      );

  bool get hasActual  => actual.isNotEmpty;
  bool get isHighImpact => impact == 'high';
  bool get isMedImpact  => impact == 'medium';
  bool get isHoliday    => impact == 'holiday';
}
