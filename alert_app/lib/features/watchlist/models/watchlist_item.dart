/// A single symbol the user is watching.
class WatchlistItem {
  const WatchlistItem({
    required this.symbol,
    required this.emoji,
    required this.label,
    this.price,
    this.prevPrice,
    this.lastUpdated,
  });

  final String   symbol;
  final String   emoji;
  final String   label;
  final double?  price;
  final double?  prevPrice;
  final DateTime? lastUpdated;

  WatchlistItem copyWith({double? price, double? prevPrice, DateTime? lastUpdated}) =>
      WatchlistItem(
        symbol:      symbol,
        emoji:       emoji,
        label:       label,
        price:       price      ?? this.price,
        prevPrice:   prevPrice  ?? this.prevPrice,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  bool get isUp =>
      price == null || prevPrice == null || price! >= prevPrice!;

  // Default symbols the watchlist starts with
  static const List<WatchlistItem> defaults = [
    WatchlistItem(symbol: 'XAUUSD', emoji: '🥇', label: 'طلا / Gold'),
    WatchlistItem(symbol: 'XAGUSD', emoji: '🥈', label: 'نقره / Silver'),
    WatchlistItem(symbol: 'EURUSD', emoji: '💶', label: 'EUR/USD'),
    WatchlistItem(symbol: 'GBPUSD', emoji: '💵', label: 'GBP/USD'),
    WatchlistItem(symbol: 'USOIL',  emoji: '🫙', label: 'نفت / Oil'),
    WatchlistItem(symbol: 'US500',  emoji: '📈', label: 'S&P 500'),
    WatchlistItem(symbol: 'NAS100', emoji: '📊', label: 'NASDAQ'),
    WatchlistItem(symbol: 'BTCUSD', emoji: '🔷', label: 'Bitcoin'),
  ];
}
