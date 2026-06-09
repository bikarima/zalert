import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _keyUserId   = 'user_id';
  static const _keyUsername = 'username';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveUser(int userId, String username) async {
    final p = await _prefs;
    await p.setInt(_keyUserId, userId);
    await p.setString(_keyUsername, username);
  }

  Future<int?> getUserId() async {
    final p = await _prefs;
    return p.getInt(_keyUserId);
  }

  Future<String?> getUsername() async {
    final p = await _prefs;
    return p.getString(_keyUsername);
  }

  Future<void> clear() async {
    final p = await _prefs;
    await p.clear();
  }

  Future<bool> isLoggedIn() async => (await getUserId()) != null;
}
