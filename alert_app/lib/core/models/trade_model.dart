import 'dart:convert';

class TradeModel {
  final String id;
  final String symbol;
  final String type; // buy / sell
  final double entry;
  final double? exit;
  final double lotSize;
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;

  const TradeModel({
    required this.id,
    required this.symbol,
    required this.type,
    required this.entry,
    this.exit,
    required this.lotSize,
    this.notes,
    required this.openedAt,
    this.closedAt,
  });

  bool get isClosed => exit != null && closedAt != null;

  /// محاسبه سود/ضرر (ساده — فرض pip value = 10 برای جفت‌ارزهای معمولی)
  double? get pnl {
    if (exit == null) return null;
    final diff = type == 'buy' ? exit! - entry : entry - exit!;
    // هر pip ≈ 0.0001 برای جفت‌های معمولی / 0.01 برای JPY pairs
    final pipSize = symbol.toUpperCase().contains('JPY') ? 0.01 : 0.0001;
    final pips = diff / pipSize;
    return pips * 10.0 * lotSize;
  }

  bool get isWin => (pnl ?? 0) > 0;

  factory TradeModel.fromJson(Map<String, dynamic> json) {
    return TradeModel(
      id:        json['id']?.toString() ?? '',
      symbol:    json['symbol']?.toString() ?? '',
      type:      json['type']?.toString() ?? 'buy',
      entry:     (json['entry'] as num?)?.toDouble() ?? 0.0,
      exit:      (json['exit'] as num?)?.toDouble(),
      lotSize:   (json['lot_size'] as num?)?.toDouble() ?? 0.01,
      notes:     json['notes']?.toString(),
      openedAt:  DateTime.tryParse(json['opened_at']?.toString() ?? '') ??
                 DateTime.now(),
      closedAt:  json['closed_at'] != null
                 ? DateTime.tryParse(json['closed_at'].toString())
                 : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'type': type,
    'entry': entry,
    if (exit != null) 'exit': exit,
    'lot_size': lotSize,
    if (notes != null) 'notes': notes,
    'opened_at': openedAt.toIso8601String(),
    if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
  };

  TradeModel copyWith({
    String? id, String? symbol, String? type, double? entry,
    double? exit, double? lotSize, String? notes,
    DateTime? openedAt, DateTime? closedAt,
  }) {
    return TradeModel(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      type: type ?? this.type,
      entry: entry ?? this.entry,
      exit: exit ?? this.exit,
      lotSize: lotSize ?? this.lotSize,
      notes: notes ?? this.notes,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  static List<TradeModel> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => TradeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<TradeModel> trades) {
    return jsonEncode(trades.map((t) => t.toJson()).toList());
  }
}
