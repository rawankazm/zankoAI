import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUpdateInfo {
  final bool isUpdateAvailable;
  final bool isForced;
  final String localVersion;
  final String remoteVersion;
  final String updateUrl;
  final String title;
  final String notes;

  const AppUpdateInfo({
    required this.isUpdateAvailable,
    required this.isForced,
    required this.localVersion,
    required this.remoteVersion,
    required this.updateUrl,
    required this.title,
    required this.notes,
  });
}

class AppVersionService extends ChangeNotifier {
  static final AppVersionService _instance = AppVersionService._internal();
  factory AppVersionService() => _instance;
  AppVersionService._internal();

  /// The version of the current mobile app build.
  static const String currentAppVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  StreamSubscription? _configSub;
  AppUpdateInfo? _updateInfo;
  AppUpdateInfo? get updateInfo => _updateInfo;

  void startListening(Function(AppUpdateInfo info)? onUpdateRequired) {
    _configSub?.cancel();
    try {
      _configSub = FirebaseFirestore.instance
          .collection('config')
          .doc('version_config')
          .snapshots()
          .listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final info = _evaluateVersion(data);
          _updateInfo = info;
          notifyListeners();
          if (info.isUpdateAvailable && info.isForced && onUpdateRequired != null) {
            onUpdateRequired(info);
          }
        } else {
          FirebaseFirestore.instance.collection('config').doc('app_config').get().then((fallbackSnap) {
            if (fallbackSnap.exists && fallbackSnap.data() != null) {
              final info = _evaluateVersion(fallbackSnap.data()!);
              _updateInfo = info;
              notifyListeners();
              if (info.isUpdateAvailable && info.isForced && onUpdateRequired != null) {
                onUpdateRequired(info);
              }
            }
          }).catchError((_) {});
        }
      }, onError: (e) {
        FirebaseFirestore.instance.collection('config').doc('app_config').get().then((fallbackSnap) {
          if (fallbackSnap.exists && fallbackSnap.data() != null) {
            final info = _evaluateVersion(fallbackSnap.data()!);
            _updateInfo = info;
            notifyListeners();
            if (info.isUpdateAvailable && info.isForced && onUpdateRequired != null) {
              onUpdateRequired(info);
            }
          }
        }).catchError((_) {});
      });
    } catch (e) {
      debugPrint('AppVersionService startListening error: $e');
    }
  }

  Future<AppUpdateInfo> checkForUpdate() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('version_config')
          .get()
          .timeout(const Duration(seconds: 4));

      if (!doc.exists || doc.data() == null) {
        doc = await FirebaseFirestore.instance
            .collection('config')
            .doc('app_config')
            .get()
            .timeout(const Duration(seconds: 4));
      }

      if (doc.exists && doc.data() != null) {
        final info = _evaluateVersion(doc.data()!);
        _updateInfo = info;
        notifyListeners();
        return info;
      }
    } catch (e) {
      debugPrint('AppVersionService checkForUpdate error: ');
    }

    return const AppUpdateInfo(
      isUpdateAvailable: false,
      isForced: false,
      localVersion: currentAppVersion,
      remoteVersion: currentAppVersion,
      updateUrl: '',
      title: '',
      notes: '',
    );
  }

  AppUpdateInfo _evaluateVersion(Map<String, dynamic> data) {
    final remoteVersion = (data['app_version'] ?? data['latest_version'] ?? currentAppVersion).toString().trim();
    final minRequired = (data['min_required_version'] ?? '1.0.0').toString().trim();
    final forceUpdateFlag = data['force_update'] == true;
    final updateUrl = (data['update_url'] ?? 'https://play.google.com/store/apps/details?id=com.zanko.student').toString();
    final title = (data['update_title'] ?? '🚀 نوێکارییەکی نوێ بەردەستە!').toString();
    final notes = (data['update_notes'] ?? 'تایبەتمەندی نوێ زیادکراوە و خێرایی ئەپەکە بەرزکراوەتەوە.').toString();

    final isNewer = _isVersionGreater(remoteVersion, currentAppVersion);
    final isBelowMin = _isVersionGreater(minRequired, currentAppVersion);
    final isForced = forceUpdateFlag || isBelowMin;

    final isUpdateAvailable = isNewer || (remoteVersion != currentAppVersion);

    return AppUpdateInfo(
      isUpdateAvailable: isUpdateAvailable,
      isForced: isForced,
      localVersion: currentAppVersion,
      remoteVersion: remoteVersion,
      updateUrl: updateUrl,
      title: title,
      notes: notes,
    );
  }

  bool _isVersionGreater(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (parts1.length < 3) {
        parts1.add(0);
      }
      while (parts2.length < 3) {
        parts2.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (parts1[i] > parts2[i]) return true;
        if (parts1[i] < parts2[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }
}
