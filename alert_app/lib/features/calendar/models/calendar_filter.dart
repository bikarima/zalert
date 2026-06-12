class CalendarFilter {
  final Set<String> impacts;
  final Set<String> currencies;

  const CalendarFilter({
    required this.impacts,
    required this.currencies,
  });

  static CalendarFilter get defaultFilter => CalendarFilter(
    impacts:    {'high', 'medium', 'low', 'holiday'},
    currencies: {'AUD','CAD','CHF','CNY','EUR','GBP','JPY','NZD','USD'},
  );

  bool get isDefault =>
      impacts.length == 4 && currencies.length == 9;

  CalendarFilter copyWith({Set<String>? impacts, Set<String>? currencies}) =>
      CalendarFilter(
        impacts:    impacts    ?? this.impacts,
        currencies: currencies ?? this.currencies,
      );

  // آیا این رویداد از فیلتر رد میشه
  bool matches(String impact, String currency) {
    final imp = impact.isEmpty ? 'low' : impact;
    final cur = currency.toUpperCase();
    return impacts.contains(imp) &&
        (currencies.isEmpty || currencies.contains(cur) || cur == 'ALL');
  }
}
