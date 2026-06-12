import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/trade_model.dart';
import '../../../core/services/drive/google_drive_service.dart';

class TradeProvider extends ChangeNotifier {
  List<TradeModel> _trades = [];
  bool _loading = false;
  bool _uploadingImage = false;

  List<TradeModel> get trades        => _trades;
  List<TradeModel> get openTrades    => _trades.where((t) => t.isOpen).toList();
  List<TradeModel> get closedTrades  => _trades.where((t) => !t.isOpen).toList();
  bool             get loading       => _loading;
  bool             get uploadingImage => _uploadingImage;

  double get totalPnl => closedTrades
      .where((t) => t.pnl != null)
      .fold(0.0, (sum, t) => sum + t.pnl!);

  double get winRate {
    final closed = closedTrades.where((t) => t.pnl != null).toList();
    if (closed.isEmpty) return 0;
    final wins = closed.where((t) => t.pnl! > 0).length;
    return (wins / closed.length) * 100;
  }

  TradeProvider() {
    _load();
  }

  Future<void> _load() async {
    final p    = await SharedPreferences.getInstance();
    final json = p.getStringList('trades') ?? [];
    _trades    = json
        .map((s) => TradeModel.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    notifyListeners();
  }

  Future<void> _save() async {
    final p    = await SharedPreferences.getInstance();
    final json = _trades.map((t) => jsonEncode(t.toJson())).toList();
    await p.setStringList('trades', json);
  }

  Future<TradeModel> addTrade({
    required String symbol,
    required String type,
    required double entry,
    required double lotSize,
    double? stopLoss,
    double? takeProfit,
    String? notes,
    File?   imageFile,
  }) async {
    _loading = true;
    notifyListeners();

    String? imageUrl;
    if (imageFile != null) {
      _uploadingImage = true;
      notifyListeners();
      imageUrl = await GoogleDriveService.instance.uploadImage(
        imageFile,
        tradeId: const Uuid().v4(),
      );
      _uploadingImage = false;
    }

    final trade = TradeModel(
      id:         const Uuid().v4(),
      symbol:     symbol.toUpperCase(),
      type:       type,
      entry:      entry,
      lotSize:    lotSize,
      stopLoss:   stopLoss,
      takeProfit: takeProfit,
      notes:      notes,
      imageUrl:   imageUrl,
      openedAt:   DateTime.now(),
    );

    _trades.insert(0, trade);
    await _save();
    _loading = false;
    notifyListeners();
    return trade;
  }

  Future<void> closeTrade(String id, double exitPrice) async {
    final idx = _trades.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _trades[idx] = _trades[idx].copyWith(
      exit:     exitPrice,
      closedAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  Future<void> updateNotes(String id, String notes) async {
    final idx = _trades.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _trades[idx] = _trades[idx].copyWith(notes: notes);
    await _save();
    notifyListeners();
  }

  Future<void> addImageToTrade(String id, File imageFile) async {
    _uploadingImage = true;
    notifyListeners();

    final url = await GoogleDriveService.instance.uploadImage(
      imageFile, tradeId: id);

    _uploadingImage = false;
    if (url == null) {
      notifyListeners();
      return;
    }

    final idx = _trades.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _trades[idx] = _trades[idx].copyWith(imageUrl: url);
      await _save();
    }
    notifyListeners();
  }

  Future<void> deleteTrade(String id) async {
    _trades.removeWhere((t) => t.id == id);
    await _save();
    notifyListeners();
  }
}
