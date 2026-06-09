class AlertModel {
  final int id;
  final String symbol;
  final double targetPrice;
  final String alertType;   // above / below
  final String direction;   // ⬆️ / ⬇️
  final String createdAt;
  final bool triggered;
  final String? triggeredAt;

  const AlertModel({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.alertType,
    required this.direction,
    required this.createdAt,
    required this.triggered,
    this.triggeredAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
        id: json['id'] as int,
        symbol: json['symbol'] as String,
        targetPrice: (json['target_price'] as num).toDouble(),
        alertType: json['alert_type'] as String,
        direction: json['direction'] as String,
        createdAt: json['created_at'] as String,
        triggered: json['triggered'] as bool,
        triggeredAt: json['triggered_at'] as String?,
      );

  bool get isAbove => alertType == 'above';
}
