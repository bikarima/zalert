import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../models/watchlist_item.dart';

/// Manages the watchlist: symbol list, live prices, persistence.
/// Auto-refreshes every 15 seconds (matches server CHECK_INTERVAL).
class WatchlistProvider extends ChangeNotifier {
  static const _key = 'watchlist_symbols';
  static const _refreshInterval = Duration(seconds: 15);

  List<WatchlistItem> _items = [];
  bool  _loading  = true;
  Timer? _timer;

  List<WatchlistItem> get items   => List.unmodifiable(_items);
  bool                get loading => _loading;

  WatchlistProvider() {
    _init();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      await _loadFromPrefs();
    } catch (_) {
      _items = List.of(WatchlistItem.defaults);
    }
    try {
      await refreshPrices();
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
    _timer = Timer.periodic(_refreshInterval, (_) => refreshPrices());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_key);

    if (raw == null || raw.isEmpty) {
      _items = List.of(WatchlistItem.defaults);
    } else {
      final defaults = {for (final d in WatchlistItem.defaults) d.symbol: d};
      _items = raw.map((s) {
        final d = defaults[s];
        return d ?? WatchlistItem(symbol: s, emoji: '📊', label: s);
      }).toList();
    }
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _items.map((i) => i.symbol).toList());
  }

  // ── Price refresh ─────────────────────────────────────────────────────────

  Future<void> refreshPrices() async {
    _loading = _items.every((i) => i.price == null);
    if (_loading) notifyListeners();

    await Future.wait(_items.map(_fetchOne));
    _loading = false;
    notifyListeners();
  }

  Future<void> _fetchOne(WatchlistItem item) async {
    try {
      final data  = await ApiService.instance.getPrice(item.symbol);
      final price = (data['price'] as num?)?.toDouble();
      if (price == null) return;
      final idx = _items.indexWhere((i) => i.symbol == item.symbol);
      if (idx == -1) return;
      _items[idx] = _items[idx].copyWith(
        prevPrice:   _items[idx].price ?? price,
        price:       price,
        lastUpdated: DateTime.now(),
      );
    } catch (_) {}
  }

  // ── Symbol management ─────────────────────────────────────────────────────

  bool contains(String symbol) =>
      _items.any((i) => i.symbol.toUpperCase() == symbol.toUpperCase());

  Future<void> addSymbol(String symbol, {String emoji = '📊', String label = ''}) async {
    final sym = symbol.toUpperCase();
    if (contains(sym)) return;
    final newItem = WatchlistItem(
      symbol: sym, emoji: emoji, label: label.isEmpty ? sym : label,
    );
    _items.add(newItem);
    notifyListeners();
    await _saveToPrefs();
    await _fetchOne(newItem);
    notifyListeners();
  }

  Future<void> removeSymbol(String symbol) async {
    _items.removeWhere((i) => i.symbol == symbol.toUpperCase());
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> resetToDefaults() async {
    _items = List.of(WatchlistItem.defaults);
    notifyListeners();
    await _saveToPrefs();
    await refreshPrices();
  }
}
