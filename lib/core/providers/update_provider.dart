import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_service.dart';

enum UpdateStatus {
  unknown,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  error,
}

/// Owns update state for the Settings card. Network + cache live in
/// [UpdateService]; the platform installer handoff lives here so widgets and
/// tests can inject fakes through [openInstaller] and [currentVersionOverride].
class UpdateProvider with ChangeNotifier {
  UpdateService? _service;
  final Future<String> Function()? _versionLoader;
  final Future<OpenResult> Function(String path)? _openInstaller;

  UpdateStatus _status = UpdateStatus.unknown;
  ReleaseInfo? _release;
  String _currentVersion = '';
  double _progress = 0;
  String? _errorMessage;
  String? _downloadedApkPath;
  bool _cancelRequested = false;
  bool _checkInFlight = false;

  UpdateProvider({
    UpdateService? service,
    Future<String> Function()? versionLoader,
    Future<OpenResult> Function(String path)? openInstaller,
  })  : _service = service,
        _versionLoader = versionLoader,
        _openInstaller = openInstaller;

  UpdateStatus get status => _status;
  ReleaseInfo? get release => _release;
  String get currentVersion => _currentVersion;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;

  bool get hasUpdate =>
      _status == UpdateStatus.available ||
      _status == UpdateStatus.downloading ||
      _status == UpdateStatus.ready;

  bool get isForceBlocked {
    final r = _release;
    if (r == null || r.minVersion.isEmpty || _currentVersion.isEmpty) {
      return false;
    }
    return compareVersions(_currentVersion, r.minVersion) < 0;
  }

  Future<UpdateService> _readyService() async {
    final existing = _service;
    if (existing != null) return existing;
    final prefs = await SharedPreferences.getInstance();
    final created = UpdateService(prefs: prefs);
    _service = created;
    return created;
  }

  Future<String> _currentAppVersion() async {
    final loader = _versionLoader;
    if (loader != null) return loader();
    return (await PackageInfo.fromPlatform()).version;
  }

  /// Cold-start entry point: loads the installed version, then checks.
  /// Never throws; background failures keep last-known state silently.
  Future<void> initialize() async {
    if (_status == UpdateStatus.checking) return;
    _status = UpdateStatus.checking;
    notifyListeners();
    try {
      _currentVersion = await _currentAppVersion();
      await checkForUpdates();
    } catch (_) {
      _status = UpdateStatus.unknown;
      notifyListeners();
    }
  }

  /// [force] bypasses the 24h cache. [userInitiated] surfaces failures as
  /// [UpdateStatus.error]; background polls stay silent per spec.
  Future<void> checkForUpdates(
      {bool force = false, bool userInitiated = false}) async {
    if (_checkInFlight) return;
    _checkInFlight = true;
    final service = await _readyService();
    if (_currentVersion.isEmpty) {
      try {
        _currentVersion = await _currentAppVersion();
      } catch (_) {}
    }
    if (_status != UpdateStatus.downloading &&
        _status != UpdateStatus.ready) {
      _status = UpdateStatus.checking;
      notifyListeners();
    }
    try {
      final release = await service.checkForUpdates(
        currentVersion: _currentVersion,
        force: force,
      );
      if (release != null) {
        _release = release;
        if (_status != UpdateStatus.downloading &&
            _status != UpdateStatus.ready) {
          _status = UpdateStatus.available;
        }
      } else if (_status != UpdateStatus.downloading &&
          _status != UpdateStatus.ready) {
        _release = null;
        if (userInitiated && service.lastError != null) {
          _status = UpdateStatus.error;
          _errorMessage =
              UpdateService.friendlyError(service.lastError!);
        } else {
          _status =
              _currentVersion.isEmpty ? UpdateStatus.unknown : UpdateStatus.upToDate;
        }
      }
    } catch (e) {
      if (userInitiated &&
          _status != UpdateStatus.downloading &&
          _status != UpdateStatus.ready) {
        _status = UpdateStatus.error;
        _errorMessage = UpdateService.friendlyError(e);
      }
    } finally {
      _checkInFlight = false;
      notifyListeners();
    }
  }

  Future<void> dismiss() async {
    if (isForceBlocked) return;
    final release = _release;
    if (release == null) return;
    final service = await _readyService();
    await service.dismissVersion(release.version);
    _release = null;
    _status = _currentVersion.isEmpty ? UpdateStatus.unknown : UpdateStatus.upToDate;
    notifyListeners();
  }

  void cancelDownload() {
    _cancelRequested = true;
  }

  /// Downloads the APK with progress, then hands it to the Android installer.
  /// Throws nothing; failures land in [UpdateStatus.error] with [errorMessage].
  Future<void> downloadAndInstall() async {
    final release = _release;
    final service = await _readyService();
    if (release == null) return;
    if (_status == UpdateStatus.downloading) return;
    _cancelRequested = false;
    _progress = 0;
    _errorMessage = null;
    _status = UpdateStatus.downloading;
    notifyListeners();
    try {
      final dir = await getTemporaryDirectory();
      final safeTag = release.tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '${dir.path}/cofiz-update-$safeTag.apk';
      await service.downloadApk(
        url: release.apkUrl,
        destPath: path,
        onProgress: (p) {
          _progress = p.clamp(0.0, 1.0);
          notifyListeners();
        },
        isCancelled: () async => _cancelRequested,
      );
      _downloadedApkPath = path;
      _progress = 1;
      _status = UpdateStatus.ready;
      notifyListeners();
      await openInstaller(path);
    } catch (e) {
      if (isDownloadCancelled(e)) {
        _status = UpdateStatus.available;
        _progress = 0;
        notifyListeners();
        return;
      }
      _status = UpdateStatus.error;
      _errorMessage = UpdateService.friendlyError(e);
      notifyListeners();
    }
  }

  /// Re-fires the installer for an already-downloaded APK.
  Future<void> openInstaller(String path) async {
    try {
      final opener = _openInstaller ?? OpenFilex.open;
      final result = await opener(path);
      if (result.type != ResultType.done) {
        _status = UpdateStatus.ready;
        final detail = result.message.isNotEmpty
            ? result.message
            : 'Could not open installer';
        _errorMessage = UpdateService.friendlyError(detail);
        notifyListeners();
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = UpdateService.friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> retryReadyInstall() async {
    final path = _downloadedApkPath;
    if (path == null) return;
    await openInstaller(path);
  }
}
