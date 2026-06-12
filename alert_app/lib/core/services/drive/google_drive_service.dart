import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

const _backupFileName = 'zalert_trades_backup.json';
const _folderName     = 'ZAlert Trades';

class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;
  bool   get isSignedIn => _currentUser != null;
  String? get userEmail  => _currentUser?.email;

  // cache folder ID
  String? _folderId;

  // ── Auth ──────────────────────────────────────────────────────────

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) _folderId = null; // reset cache
      return _currentUser != null;
    } catch (e) {
      debugPrint('[Drive] Sign in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _folderId    = null;
  }

  Future<bool> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) _folderId = null;
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  // ── Drive API ─────────────────────────────────────────────────────

  Future<drive.DriveApi?> _getDriveApi() async {
    if (_currentUser == null) {
      final ok = await signInSilently();
      if (!ok) return null;
    }
    try {
      final auth    = await _currentUser!.authentication;
      final headers = {'Authorization': 'Bearer ${auth.accessToken}'};
      return drive.DriveApi(_AuthenticatedClient(headers));
    } catch (e) {
      debugPrint('[Drive] Auth error: $e');
      return null;
    }
  }

  // ── Folder ────────────────────────────────────────────────────────

  Future<String?> _getOrCreateFolder(drive.DriveApi api) async {
    if (_folderId != null) return _folderId;
    try {
      final result = await api.files.list(
        q: "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (result.files != null && result.files!.isNotEmpty) {
        _folderId = result.files!.first.id;
        return _folderId;
      }
      final folder = drive.File()
        ..name     = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      _folderId = created.id;
      return _folderId;
    } catch (e) {
      debugPrint('[Drive] Folder error: $e');
      return null;
    }
  }

  // ── Backup / Restore ──────────────────────────────────────────────

  /// ذخیره لیست trades به عنوان JSON در Drive
  Future<bool> backupTrades(List<Map<String, dynamic>> trades) async {
    final api = await _getDriveApi();
    if (api == null) return false;

    final folderId = await _getOrCreateFolder(api);
    if (folderId == null) return false;

    try {
      final jsonStr  = jsonEncode({'trades': trades, 'backup_at': DateTime.now().toIso8601String()});
      final bytes    = utf8.encode(jsonStr);
      final media    = drive.Media(Stream.value(bytes), bytes.length,
          contentType: 'application/json');

      // چک کن فایل backup قبلاً هست یا نه
      final existing = await _findBackupFile(api, folderId);

      if (existing != null) {
        // آپدیت فایل موجود
        await api.files.update(
          drive.File()..name = _backupFileName,
          existing,
          uploadMedia: media,
        );
      } else {
        // ساخت فایل جدید
        await api.files.create(
          drive.File()
            ..name    = _backupFileName
            ..parents = [folderId],
          uploadMedia: media,
        );
      }
      debugPrint('[Drive] Backup saved: ${trades.length} trades');
      return true;
    } catch (e) {
      debugPrint('[Drive] Backup error: $e');
      return false;
    }
  }

  /// بازیابی trades از Drive
  Future<List<Map<String, dynamic>>?> restoreTrades() async {
    final api = await _getDriveApi();
    if (api == null) return null;

    final folderId = await _getOrCreateFolder(api);
    if (folderId == null) return null;

    try {
      final fileId = await _findBackupFile(api, folderId);
      if (fileId == null) {
        debugPrint('[Drive] No backup file found');
        return [];
      }

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = <int>[];
      await for (final chunk in media.stream) {
        chunks.addAll(chunk);
      }

      final jsonStr = utf8.decode(chunks);
      final data    = jsonDecode(jsonStr) as Map<String, dynamic>;
      final trades  = (data['trades'] as List)
          .cast<Map<String, dynamic>>();

      debugPrint('[Drive] Restored: ${trades.length} trades');
      return trades;
    } catch (e) {
      debugPrint('[Drive] Restore error: $e');
      return null;
    }
  }

  Future<String?> _findBackupFile(drive.DriveApi api, String folderId) async {
    try {
      final result = await api.files.list(
        q: "name='$_backupFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      return result.files?.isNotEmpty == true ? result.files!.first.id : null;
    } catch (_) {
      return null;
    }
  }

  // ── Upload Image ──────────────────────────────────────────────────

  Future<String?> uploadImage(File imageFile, {String? tradeId}) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    final folderId = await _getOrCreateFolder(api);
    if (folderId == null) return null;

    try {
      final fileName    = 'chart_${tradeId ?? DateTime.now().millisecondsSinceEpoch}'
          '${path.extension(imageFile.path)}';
      final fileContent = await imageFile.readAsBytes();
      final media       = drive.Media(
        Stream.value(fileContent), fileContent.length,
        contentType: _mimeType(imageFile.path),
      );

      final driveFile = drive.File()
        ..name    = fileName
        ..parents = [folderId];

      final uploaded = await api.files.create(driveFile, uploadMedia: media);
      if (uploaded.id == null) return null;

      // عمومی قابل مشاهده
      await api.permissions.create(
        drive.Permission()..type = 'anyone'..role = 'reader',
        uploaded.id!,
      );

      return 'https://drive.google.com/uc?id=${uploaded.id}';
    } catch (e) {
      debugPrint('[Drive] Upload image error: $e');
      return null;
    }
  }

  String _mimeType(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.jpg': case '.jpeg': return 'image/jpeg';
      case '.png':               return 'image/png';
      case '.webp':              return 'image/webp';
      default:                   return 'image/jpeg';
    }
  }
}

// ── HTTP Client ───────────────────────────────────────────────────────────────

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
