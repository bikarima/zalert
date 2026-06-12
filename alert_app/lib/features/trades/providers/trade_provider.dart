import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/trade_model.dart';
import '../../../core/services/drive/google_drive_service.dart';

class TradeProvider extends ChangeNotifier {
  List<TradeModel> _trades    = [];
  bool _loading               = false;
  bool _uploadingImage        = false;
  bool _syncing               = false;
  String? _error;

  List<TradeModel> get trades         => _trades;
  List<TradeModel> get openTrades     => _trades.where((t) => t.isOpen).toList();
  List<TradeModel> get closedTrades   => _trades.where((t) => !t.isOpen).toList();
  bool             get loading        => _loading;
  bool             get uploadingImage => _uploadingImage;
  bool             get syncing        => _syncing;
  String?          get error          => _error;

  double get totalPnl => closedTrades
      .where((t) => t.pnl != null)
      .fold(0.0, (sum, t) => sum + t.pnl!);

  double get winRate {
    final closed = closedTrades.where((t) => t.pnl != null).toList();
    if (closed.isEmpty) return 0;
    return (closed.where((t) => t.pnl! > 0).length / closed.length) * 100;
  }

  // ── Load از Drive ─────────────────────────────────────────────────

  Future<bool> loadFromDrive() async {
    if (!GoogleDriveService.instance.isSignedIn) return false;

    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final data = await GoogleDriveService.instance.restoreTrades();
      if (data == null) {
        _error   = 'خطا در اتصال به Google Drive';
        _loading = false;
        notifyListeners();
        return false;
      }

      _trades = data
          .map((j) => TradeModel.fromJson(j))
          .toList()
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error   = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Backup به Drive ───────────────────────────────────────────────

  Future<void> _backup() async {
    if (!GoogleDriveService.instance.isSignedIn) return;
    _syncing = true;
    notifyListeners();
    final json = _trades.map((t) => t.toJson()).toList();
    await GoogleDriveService.instance.backupTrades(json);
    _syncing = false;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────

  Future<TradeModel?> addTrade({
    required String symbol,
    required String type,
    required double entry,
    required double lotSize,
    double? stopLoss,
    double? takeProfit,
    String? notes,
    File?   imageFile,
  }) async {
    if (!GoogleDriveService.instance.isSignedIn) return null;

    _loading = true;
    notifyListeners();

    String? imageUrl;
    if (imageFile != null) {
      _uploadingImage = true;
      notifyListeners();
      final id = const Uuid().v4();
      imageUrl = await GoogleDriveService.instance.uploadImage(
          imageFile, tradeId: id);
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
    _loading = false;
    notifyListeners();

    await _backup();
    return trade;
  }

  Future<void> closeTrade(String id, double exitPrice) async {
    final idx = _trades.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _trades[idx] = _trades[idx].copyWith(
      exit:     exitPrice,
      closedAt: DateTime.now(),
    );
    notifyListeners();
    await _backup();
  }

  Future<void> updateNotes(String id, String notes) async {
    final idx = _trades.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _trades[idx] = _trades[idx].copyWith(notes: notes);
    notifyListeners();
    await _backup();
  }

  Future<void> addImageToTrade(String id, File imageFile) async {
    if (!GoogleDriveService.instance.isSignedIn) return;
    _uploadingImage = true;
    notifyListeners();

    final url = await GoogleDriveService.instance.uploadImage(
        imageFile, tradeId: id);
    _uploadingImage = false;

    if (url != null) {
      final idx = _trades.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _trades[idx] = _trades[idx].copyWith(imageUrl: url);
        notifyListeners();
        await _backup();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> deleteTrade(String id) async {
    _trades.removeWhere((t) => t.id == id);
    notifyListeners();
    await _backup();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
