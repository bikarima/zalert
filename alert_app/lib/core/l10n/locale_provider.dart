import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  String _lang = 'fa';
  String get lang => _lang;
  bool get isRtl => _lang == 'fa';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _lang = p.getString('lang') ?? 'fa';
    notifyListeners();
  }

  Future<void> setLang(String lang) async {
    _lang = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', lang);
    notifyListeners();
  }
}
