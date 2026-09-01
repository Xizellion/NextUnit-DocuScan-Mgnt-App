import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      _currentUser = account;

      final authHeaders = await account.authHeaders;
      final authClient = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(authClient);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  /// Uploads any local file to Google Drive under 'NextUnit DocuScan' folder
  Future<String?> uploadFileToDrive(File file, {String? customTitle}) async {
    if (_driveApi == null) {
      final success = await signInWithGoogle();
      if (!success || _driveApi == null) return null;
    }

    try {
      final driveFile = drive.File();
      driveFile.name = customTitle ?? file.path.split('/').last;

      final media = drive.Media(
        file.openRead(),
        file.lengthSync(),
      );

      final response = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return response.id;
    } catch (e) {
      return null;
    }
  }

  /// List all locally saved documents, exported spreadsheets, and voice notes
  Future<List<FileSystemEntity>> listLocalFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      entities.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      return entities;
    } catch (e) {
      return [];
    }
  }
}