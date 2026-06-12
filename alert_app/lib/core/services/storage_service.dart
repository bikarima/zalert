import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _keyUserId   = 'user_id';
  static const _keyUsername = 'username';
  static const _keyDeviceId = 'device_id';

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
    // فقط اطلاعات یوزر رو پاک کن، device_id رو نگه دار
    await p.remove(_keyUserId);
    await p.remove(_keyUsername);
  }

  Future<bool> isLoggedIn() async => (await getUserId()) != null;

  /// یه device_id یکتا می‌سازه یا از storage می‌خونه
  Future<String> getOrCreateDeviceId() async {
    final p = await _prefs;
    final existing = p.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    // ساخت یه UUID جدید و تبدیل به عدد بزرگ
    const uuid = Uuid();
    final newId = uuid.v4().replaceAll('-', '');
    await p.setString(_keyDeviceId, newId);
    return newId;
  }

  /// device_id رو به عنوان عدد برمی‌گردونه (از 16 کاراکتر اول hex)
  Future<int> getOrCreateDeviceIdAsInt() async {
    final id = await getOrCreateDeviceId();
    // برگرداندن 15 رقم اول hex به عنوان int
    final hexPart = id.substring(0, 15);
    return int.parse(hexPart, radix: 16);
  }

  // ── Trades (local storage) ────────────────────────────────────────

  static const _keyTrades = 'local_trades';

  Future<String?> getTradesJson() async {
    final p = await _prefs;
    return p.getString(_keyTrades);
  }

  Future<void> saveTradesJson(String json) async {
    final p = await _prefs;
    await p.setString(_keyTrades, json);
  }

  // ── Announcements (read status) ───────────────────────────────────

  static const _keyReadAnnouncements = 'read_announcements';

  Future<List<String>> getReadAnnouncementIds() async {
    final p = await _prefs;
    return p.getStringList(_keyReadAnnouncements) ?? [];
  }

  Future<void> markAnnouncementRead(String id) async {
    final p = await _prefs;
    final list = p.getStringList(_keyReadAnnouncements) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await p.setStringList(_keyReadAnnouncements, list);
    }
  }
}
