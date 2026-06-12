import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;

  // ── Auth ──────────────────────────────────────────────────────────

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (e) {
      debugPrint('[Drive] Sign in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<bool> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
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
      final client  = _AuthenticatedClient(headers);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('[Drive] Auth error: $e');
      return null;
    }
  }

  /// آپلود عکس به Google Drive و برگرداندن link قابل share
  Future<String?> uploadImage(File imageFile, {String? tradeId}) async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      // اول پوشه ZAlert رو پیدا یا بساز
      final folderId = await _getOrCreateFolder(api, 'ZAlert Trades');
      if (folderId == null) return null;

      final fileName = 'trade_${tradeId ?? DateTime.now().millisecondsSinceEpoch}'
          '${path.extension(imageFile.path)}';

      final fileContent = await imageFile.readAsBytes();
      final media       = drive.Media(
        Stream.value(fileContent),
        fileContent.length,
        contentType: _mimeType(imageFile.path),
      );

      final driveFile = drive.File()
        ..name    = fileName
        ..parents = [folderId];

      final uploaded = await api.files.create(
        driveFile,
        uploadMedia: media,
      );

      if (uploaded.id == null) return null;

      // عمومی قابل مشاهده کن
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        uploaded.id!,
      );

      return 'https://drive.google.com/uc?id=${uploaded.id}';
    } catch (e) {
      debugPrint('[Drive] Upload error: $e');
      return null;
    }
  }

  Future<String?> _getOrCreateFolder(drive.DriveApi api, String name) async {
    try {
      final result = await api.files.list(
        q: "name='$name' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }

      // بساز
      final folder = drive.File()
        ..name     = name
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      return created.id;
    } catch (e) {
      debugPrint('[Drive] Folder error: $e');
      return null;
    }
  }

  String _mimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      case '.webp': return 'image/webp';
      default:      return 'image/jpeg';
    }
  }
}

// ── HTTP Client با Bearer Token ───────────────────────────────────────────────

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
