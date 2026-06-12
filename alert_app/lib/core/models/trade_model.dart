import 'dart:convert';

class TradeModel {
  final String   id;
  final String   symbol;
  final String   type;         // buy / sell
  final double   entry;
  final double?  exit;
  final double   lotSize;
  final double?  stopLoss;
  final double?  takeProfit;
  final String?  notes;
  final String?  imageUrl;     // Google Drive URL
  final DateTime openedAt;
  final DateTime? closedAt;

  const TradeModel({
    required this.id,
    required this.symbol,
    required this.type,
    required this.entry,
    this.exit,
    required this.lotSize,
    this.stopLoss,
    this.takeProfit,
    this.notes,
    this.imageUrl,
    required this.openedAt,
    this.closedAt,
  });

  bool get isOpen   => exit == null;
  bool get isBuy    => type == 'buy';
  bool get hasSL    => stopLoss != null;
  bool get hasTP    => takeProfit != null;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  double? get pnl {
    if (exit == null) return null;
    final diff = isBuy ? exit! - entry : entry - exit!;
    return diff * lotSize * 100; // simplified
  }

  double? get riskRewardRatio {
    if (stopLoss == null || takeProfit == null) return null;
    final risk   = (entry - stopLoss!).abs();
    final reward = (takeProfit! - entry).abs();
    return risk == 0 ? null : reward / risk;
  }

  Map<String, dynamic> toJson() => {
    'id':         id,
    'symbol':     symbol,
    'type':       type,
    'entry':      entry,
    'exit':       exit,
    'lotSize':    lotSize,
    'stopLoss':   stopLoss,
    'takeProfit': takeProfit,
    'notes':      notes,
    'imageUrl':   imageUrl,
    'openedAt':   openedAt.toIso8601String(),
    'closedAt':   closedAt?.toIso8601String(),
  };

  factory TradeModel.fromJson(Map<String, dynamic> j) => TradeModel(
    id:         j['id']     as String,
    symbol:     j['symbol'] as String,
    type:       j['type']   as String,
    entry:      (j['entry'] as num).toDouble(),
    exit:       j['exit']   != null ? (j['exit'] as num).toDouble() : null,
    lotSize:    (j['lotSize'] as num).toDouble(),
    stopLoss:   j['stopLoss']   != null ? (j['stopLoss'] as num).toDouble() : null,
    takeProfit: j['takeProfit'] != null ? (j['takeProfit'] as num).toDouble() : null,
    notes:      j['notes']    as String?,
    imageUrl:   j['imageUrl'] as String?,
    openedAt:   DateTime.parse(j['openedAt'] as String),
    closedAt:   j['closedAt'] != null ? DateTime.parse(j['closedAt'] as String) : null,
  );

  TradeModel copyWith({
    double? exit,
    String? notes,
    String? imageUrl,
    DateTime? closedAt,
    double? stopLoss,
    double? takeProfit,
  }) =>
    TradeModel(
      id: id, symbol: symbol, type: type,
      entry: entry, lotSize: lotSize,
      exit:       exit       ?? this.exit,
      stopLoss:   stopLoss   ?? this.stopLoss,
      takeProfit: takeProfit ?? this.takeProfit,
      notes:      notes      ?? this.notes,
      imageUrl:   imageUrl   ?? this.imageUrl,
      openedAt:   openedAt,
      closedAt:   closedAt   ?? this.closedAt,
    );
}
