import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../firebase_options.dart';
import '../views/auth/login_screen.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class FirebaseAuthService extends ChangeNotifier implements AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isFirebaseInitialized = false;

  FirebaseAuthService() {
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await _ensureFirebase();
      _isFirebaseInitialized = true;
      _listenToAuthState();
    } catch (e) {
      if (kDebugMode) {
        print('Firebase init check warning: $e');
      }
    }
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
    }
  }

  StreamSubscription? _authStateSub;
  StreamSubscription? _userDocSub;
  bool? _lastNotifiedVip;
  UserRole? _lastKnownRole;
  bool _isFirstSnapshotAfterLogin = true;
  bool _isHandlingBlockedOrDeleted = false;

  void _showAccountDeletedDialog() {
    if (_isHandlingBlockedOrDeleted) return;
    _isHandlingBlockedOrDeleted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        rootNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('هەژمارەکەت لە وێبسایتی ئەدمین سڕایەوە. دەتوانیت بە هەژمارێکی تر داخیل بیتەوە.'),
                ),
              ],
            ),
            backgroundColor: Colors.blueGrey,
            duration: Duration(seconds: 4),
          ),
        );
      }
      _isHandlingBlockedOrDeleted = false;
    });
  }

  void _showAccountBlockedDialog([String? customReason]) {
    if (_isHandlingBlockedOrDeleted) return;
    _isHandlingBlockedOrDeleted = true;

    void display(BuildContext context) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1E222B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(CupertinoIcons.slash_circle_fill, color: Colors.redAccent, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ئاگاداری بلۆککردن ⛔',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  (customReason != null && customReason.trim().isNotEmpty)
                      ? customReason.trim()
                      : 'بلۆک کرایت بە هۆکاری پابەند نەبوونت بە یاسا و ڕێساکانی ئەپەکە.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14.5,
                    height: 1.6,
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      rootNavigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                      _isHandlingBlockedOrDeleted = false;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'باشە / چوونەدەرەوە',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      display(context);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          display(ctx);
        } else {
          _isHandlingBlockedOrDeleted = false;
        }
      });
    }
  }

  bool _isHandlingLoggedOutFromAnotherDevice = false;

  void _showLoggedOutFromAnotherDeviceDialog() {
    if (_isHandlingLoggedOutFromAnotherDevice || _isHandlingBlockedOrDeleted) return;
    _isHandlingLoggedOutFromAnotherDevice = true;

    void display(BuildContext context) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1E222B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(CupertinoIcons.device_phone_portrait, color: Color(0xFFF97316), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ئاگاداری چوونەدەرەوە 📱',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'ئەم ئەکاونتە لەسەر مۆبایلێکی تر کرایەوە، بۆیە لەسەر ئەم ئامێرە داخرایەوە.\n\nتێبینی: هەر هەژمارێک تەنها لەسەر یەک مۆبایل لە یەک کاتدا ڕێگەی پێدراوە کار بکات بۆ پاراستنی ئەکاونتەکەت و ڕێگریکردن لە هاوبەشکردنی نایاسایی.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.5,
                    height: 1.6,
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      rootNavigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                      _isHandlingLoggedOutFromAnotherDevice = false;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'باشە / چوونەدەرەوە',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      display(context);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          display(ctx);
        } else {
          _isHandlingLoggedOutFromAnotherDevice = false;
        }
      });
    }
  }

  static String? _cachedDeviceId;

  /// Returns a persistent unique device identifier
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('zanko_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('zanko_device_id', deviceId);
      }
      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (_) {
      _cachedDeviceId ??= const Uuid().v4();
      return _cachedDeviceId!;
    }
  }

  /// Retrieves the public IP of the user client
  static Future<String?> getPublicIp() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        return json['ip'] as String?;
      }
    } catch (_) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final request = await client.getUrl(Uri.parse('https://icanhazip.com'));
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          return body.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Validates that the user has not logged in from more than 3 distinct IP addresses
  Future<void> _validateAndTrackIp(String uid, {bool isAdmin = false}) async {
    if (isAdmin) return; // Admins are exempted

    final currentIp = await getPublicIp();
    if (currentIp == null || currentIp.isEmpty) return;

    final localDeviceId = await getDeviceId();

    try {
      final doc = await _firestore.collection('users').doc(uid).get().timeout(const Duration(seconds: 6));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final role = data['role'] as String?;
        if (role == 'admin') return;

        final rawKnownIps = data['knownIps'];
        List<String> knownIps = [];
        if (rawKnownIps is List) {
          knownIps = rawKnownIps.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
        }

        final registeredDeviceId = data['currentDeviceId'] as String?;
        final isSameVerifiedDevice = registeredDeviceId != null &&
            registeredDeviceId.isNotEmpty &&
            registeredDeviceId == localDeviceId;

        if (!knownIps.contains(currentIp)) {
          if (knownIps.length >= 3) {
            // If the student is on the EXACT SAME verified physical device (e.g. 4G cellular dynamic IP changes):
            if (isSameVerifiedDevice) {
              // Maintain smooth 3-IP sliding window so dynamic 4G never locks out legitimate owner
              final updatedIps = [...knownIps.sublist(1), currentIp];
              await _firestore.collection('users').doc(uid).set({
                'knownIps': updatedIps,
                'lastLoginIp': currentIp,
              }, SetOptions(merge: true));
              return;
            }

            // Otherwise, it is a DIFFERENT device or unauthorized IP switch: trigger security alert & block!
            try {
              final name = data['name'] as String? ?? 'خوێندکار';
              final email = data['email'] as String? ?? '';
              await _firestore.collection('security_alerts').add({
                'userId': uid,
                'name': name,
                'email': email,
                'type': 'ip_limit_exceeded',
                'reason': 'تێپەڕاندنی سنووری ٣ ناونیشانی IP لەسەر ئامێری جیاواز',
                'attemptedIp': currentIp,
                'attemptedDeviceId': localDeviceId,
                'registeredDeviceId': registeredDeviceId,
                'knownIps': knownIps,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}

            // Already 3 distinct IPs registered!
            await _auth.signOut().catchError((_) {});
            throw FirebaseAuthException(
              code: 'ip-limit-exceeded',
              message: '⛔ ناتوانیت لە زیاتر لە ٣ ناونیشانی IP جیاواز ئەکاونتەکەت بەکاربهێنیت. ئەمە بۆ پاراستنی ئەکاونت و ڕێگرییە لە هاوبەشکردنی نایاسایی.',
            );
          }
          // Add this new IP
          await _firestore.collection('users').doc(uid).set({
            'knownIps': FieldValue.arrayUnion([currentIp]),
            'lastLoginIp': currentIp,
          }, SetOptions(merge: true));
        } else {
          await _firestore.collection('users').doc(uid).set({
            'lastLoginIp': currentIp,
          }, SetOptions(merge: true));
        }
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      debugPrint('IP validation warning: $e');
    }
  }

  /// Registers this device as the single active device for this user
  Future<void> _registerActiveDevice(String uid) async {
    try {
      final deviceId = await getDeviceId();
      final currentIp = await getPublicIp();
      await _firestore.collection('users').doc(uid).set({
        'currentDeviceId': deviceId,
        'lastLoginIp': ?currentIp,
        if (currentIp != null) 'knownIps': FieldValue.arrayUnion([currentIp]),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Register active device error: $e');
    }
  }

  void _showPromotedToAdminDialog() {
    // Only show if user is fully authenticated, not guest, and not currently being deleted/blocked
    if (_currentUser == null || _currentUser!.id.startsWith('guest_') || _auth.currentUser == null || _isHandlingBlockedOrDeleted) {
      return;
    }

    void display(BuildContext context, String adminUrl) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) {
          return PopScope(
            canPop: true,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1E222B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFD700), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تۆ کراویت بە ئەدمین! 👑',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'پیرۆزە! هەژمارەکەت کراوە بە بەڕێوەبەر (Admin) لە ZankoAI. ئایا دەتەوێت بچیتە بەشی وێبسایتی ئەدمین بۆ بەڕێوەبردنی بەکارهێنەران و داواکارییەکان؟',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                    ),
                    child: const Text('لابردن / نەخێر', style: TextStyle(fontSize: 13.5)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final uri = Uri.parse(adminUrl);
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                        }
                      } catch (e) {
                        debugPrint('Could not launch admin url: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('وێبسایتی ئەدمین', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    const adminUrl = 'https://zanko-admin.vercel.app/';
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      display(context, adminUrl);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          display(ctx, adminUrl);
        }
      });
    }
  }

  String _resolveUserName(String? customName, User? fbUser, [String? fallbackName]) {
    final invalidNames = {
      'خوێندکار',
      'student',
      'بەکار‌هێنەری گووگڵ',
      'بەکارهێنەری گووگڵ',
      'بەکار‌هێنەری گوگڵ',
      'بەکارهێنەری گوگڵ',
      'google user',
      'google_user',
      'user',
      'null',
    };

    if (customName != null && customName.trim().isNotEmpty) {
      final trimmed = customName.trim();
      if (!invalidNames.contains(trimmed.toLowerCase())) {
        return trimmed;
      }
    }

    if (fbUser?.displayName != null && fbUser!.displayName!.trim().isNotEmpty) {
      final trimmed = fbUser.displayName!.trim();
      if (!invalidNames.contains(trimmed.toLowerCase())) {
        return trimmed;
      }
    }

    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      final trimmed = fallbackName.trim();
      if (!invalidNames.contains(trimmed.toLowerCase())) {
        return trimmed;
      }
    }

    if (fbUser?.email != null && fbUser!.email!.contains('@')) {
      final emailPrefix = fbUser.email!.split('@').first.trim();
      if (emailPrefix.isNotEmpty && !emailPrefix.startsWith('google_user_') && !emailPrefix.startsWith('guest_')) {
        return emailPrefix;
      }
    }

    return 'خوێندکار';
  }

  void _listenToAuthState() {
    if (!_isFirebaseInitialized) return;
    _authStateSub?.cancel();
    _authStateSub = _auth.authStateChanges().listen((User? firebaseUser) async {
      _userDocSub?.cancel();
      _isFirstSnapshotAfterLogin = true;
      _lastKnownRole = null;
      if (firebaseUser == null) {
        if (_currentUser != null && _currentUser!.id.startsWith('guest_')) {
          return;
        }
        _currentUser = null;
        _lastNotifiedVip = null;
        notifyListeners();
      } else {
        if (_currentUser == null || _currentUser!.id != firebaseUser.uid) {
          final realName = _resolveUserName(null, firebaseUser);
          _currentUser = UserModel(
            id: firebaseUser.uid,
            name: realName,
            email: firebaseUser.email ?? '',
            role: UserRole.student,
            universityName: 'زانکۆی سلێمانی',
            departmentName: 'تەکنەلۆجیای زانیاری',
            cityName: 'سلێمانی',
            gpa: 0.0,
            isVip: false,
            photoUrl: firebaseUser.photoURL,
            vipStatus: 'none',
          );
          notifyListeners();
        }
        _userDocSub = _firestore.collection('users').doc(firebaseUser.uid).snapshots().listen((doc) async {
          if (!doc.exists || doc.data() == null) {
            // New user or guest user initial document creation
            final realName = _resolveUserName(null, firebaseUser);
            final realPhoto = firebaseUser.photoURL;
            final realEmail = firebaseUser.email ?? '';

            final newUser = UserModel(
              id: firebaseUser.uid,
              name: realName,
              email: realEmail,
              role: UserRole.student,
              universityName: 'زانکۆی سلێمانی',
              departmentName: 'تەکنەلۆجیای زانیاری',
              cityName: 'سلێمانی',
              gpa: 0.0,
              isVip: false,
              photoUrl: realPhoto,
              vipStatus: 'none',
            );

            _currentUser = newUser;
            _isFirstSnapshotAfterLogin = false;
            _lastKnownRole = UserRole.student;
            notifyListeners();

            try {
              _firestore.collection('users').doc(firebaseUser.uid).set({
                'id': firebaseUser.uid,
                'uid': firebaseUser.uid,
                'name': realName,
                'email': realEmail,
                'role': 'student',
                'universityName': 'زانکۆی سلێمانی',
                'departmentName': 'تەکنەلۆجیای زانیاری',
                'cityName': 'سلێمانی',
                'gpa': 0.0,
                'isVip': false,
                'vipStatus': 'none',
                'photoUrl': realPhoto,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLoginAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
            return;
          }

          final data = doc.data()!;

          // 1. Check if user document was deleted by Admin from website
          if (data['isDeleted'] == true) {
            if (_currentUser != null && !_isHandlingBlockedOrDeleted) {
              _auth.signOut().catchError((_) {});
              _currentUser = null;
              _lastNotifiedVip = null;
              _lastKnownRole = null;
              notifyListeners();
              _showAccountDeletedDialog();
            }
            return;
          }

          // 2. Check if user was blocked by Admin from website
          final isBlocked = data['isBlocked'] == true || data['status'] == 'blocked' || data['isBanned'] == true;
          final blockReason = data['blockReason'] as String? ?? data['banReason'] as String?;
          if (isBlocked) {
            if (!_isHandlingBlockedOrDeleted) {
              _auth.signOut().catchError((_) {});
              _currentUser = null;
              _lastNotifiedVip = null;
              _lastKnownRole = null;
              notifyListeners();
              _showAccountBlockedDialog(blockReason);
            }
            return;
          }

          // 3. Check Single Active Device policy (Kick out if logged in on another device)
          final serverDeviceId = data['currentDeviceId'] as String?;
          final localDeviceId = await getDeviceId();
          if (serverDeviceId != null && serverDeviceId.isNotEmpty && serverDeviceId != localDeviceId) {
            if (_currentUser != null && !_isHandlingLoggedOutFromAnotherDevice && !_isHandlingBlockedOrDeleted) {
              await _auth.signOut().catchError((_) {});
              _currentUser = null;
              _lastNotifiedVip = null;
              _lastKnownRole = null;
              notifyListeners();
              _showLoggedOutFromAnotherDeviceDialog();
              return;
            }
          } else if (serverDeviceId == null || serverDeviceId.isEmpty) {
            _registerActiveDevice(firebaseUser.uid);
          }

          final roleStr = data['role'] as String? ?? 'student';
          final role = roleStr == 'admin'
              ? UserRole.admin
              : (roleStr == 'teacher' ? UserRole.teacher : UserRole.student);

          // 3. Check if user was promoted to Admin in real-time from Admin website
          if (!_isFirstSnapshotAfterLogin) {
            if (_lastKnownRole != null && _lastKnownRole != UserRole.admin && role == UserRole.admin) {
              if (_currentUser != null && !_currentUser!.id.startsWith('guest_')) {
                _showPromotedToAdminDialog();
              }
            }
          }
          _isFirstSnapshotAfterLogin = false;
          _lastKnownRole = role;

          final vipStatus = data['vipStatus'] as String? ?? 'none';
          final vipExpiresAt = data['vipExpiresAt'] as Timestamp?;
          bool isVip = data['isVip'] == true ||
              vipStatus == 'approved' ||
              vipStatus == 'active' ||
              role == UserRole.admin;

          if (isVip && role != UserRole.admin && vipExpiresAt != null) {
            if (DateTime.now().isAfter(vipExpiresAt.toDate())) {
              isVip = false;
            }
          }

          if (vipStatus == 'pending' || vipStatus == 'rejected' || vipStatus == 'expired') {
            if (role != UserRole.admin) isVip = false;
          }

          final realName = _resolveUserName(data['name'] as String?, firebaseUser);
          final realPhoto = data['photoUrl'] as String? ?? firebaseUser.photoURL;

          final realEmail = (data['email'] as String?)?.isNotEmpty == true
              ? (data['email'] as String)
              : (firebaseUser.email?.isNotEmpty == true ? firebaseUser.email! : '');

          final newUser = UserModel(
            id: firebaseUser.uid,
            name: realName,
            email: realEmail,
            role: role,
            universityName: data['universityName'] ?? 'زانکۆی سلێمانی',
            departmentName: data['departmentName'] ?? 'تەکنەلۆجیای زانیاری',
            cityName: data['cityName'] ?? 'سلێمانی',
            gpa: role == UserRole.student ? (data['gpa'] as num?)?.toDouble() ?? 0.0 : null,
            isVip: isVip,
            photoUrl: realPhoto,
            vipStatus: vipStatus,
          );

          _currentUser = newUser;

          NotificationService().syncUserToken(firebaseUser.uid, isVip: isVip);
          if (_lastNotifiedVip != isVip) {
            _lastNotifiedVip = isVip;
            NotificationService().listenToAdminNotifications(firebaseUser.uid, isVip, email: realEmail);
          }

          notifyListeners();
        });
      }
    });
  }


  Future<void> _fetchUserProfile(User firebaseUser, [String? fallbackName, String? fallbackEmail, String? fallbackPhoto]) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // 1. Check if user document was deleted by Admin
        if (data['isDeleted'] == true) {
          await _auth.signOut().catchError((_) {});
          _currentUser = null;
          notifyListeners();
          _showAccountDeletedDialog();
          return;
        }

        // 2. Check if user was blocked by Admin
        final isBlocked = data['isBlocked'] == true || data['status'] == 'blocked' || data['isBanned'] == true;
        final blockReason = data['blockReason'] as String? ?? data['banReason'] as String?;
        if (isBlocked) {
          await _auth.signOut().catchError((_) {});
          _currentUser = null;
          notifyListeners();
          _showAccountBlockedDialog(blockReason);
          return;
        }

        final roleStr = data['role'] as String? ?? 'student';
        final role = roleStr == 'admin'
            ? UserRole.admin
            : (roleStr == 'teacher' ? UserRole.teacher : UserRole.student);

        // ─── VIP expiry check ───────────────────────────────────────────
        final vipStatus = data['vipStatus'] as String? ?? 'none';
        final vipExpiresAt = data['vipExpiresAt'] as Timestamp?;
        bool isVip = data['isVip'] == true ||
            vipStatus == 'approved' ||
            vipStatus == 'active' ||
            role == UserRole.admin;

        if (isVip && role != UserRole.admin && vipExpiresAt != null) {
          final expiryDate = vipExpiresAt.toDate();
          if (DateTime.now().isAfter(expiryDate)) {
            isVip = false;
            try {
              await _firestore.collection('users').doc(firebaseUser.uid).set({
                'isVip': false,
                'vipStatus': 'expired',
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        }

        if (vipStatus == 'pending' || vipStatus == 'rejected' || vipStatus == 'expired') {
          if (role != UserRole.admin) isVip = false;
        }

        final realName = _resolveUserName(data['name'] as String?, firebaseUser, fallbackName);
        final realPhoto = data['photoUrl'] as String? ?? firebaseUser.photoURL ?? fallbackPhoto;
        final realEmail = (data['email'] as String?)?.isNotEmpty == true
            ? data['email']
            : (firebaseUser.email?.isNotEmpty == true ? firebaseUser.email! : (fallbackEmail ?? ''));

        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: realName,
          email: realEmail,
          role: role,
          universityName: data['universityName'] ?? 'زانکۆی سلێمانی',
          departmentName: data['departmentName'] ?? 'تەکنەلۆجیای زانیاری',
          cityName: data['cityName'] ?? 'سلێمانی',
          gpa: role == UserRole.student ? (data['gpa'] as num?)?.toDouble() ?? 0.0 : null,
          isVip: isVip,
          photoUrl: realPhoto,
          vipStatus: vipStatus,
        );

        try {
          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'id': firebaseUser.uid,
            'uid': firebaseUser.uid,
            'name': realName,
            if (realEmail.isNotEmpty) 'email': realEmail,
            'photoUrl': ?realPhoto,
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      } else {
        final realName = _resolveUserName(null, firebaseUser, fallbackName);
        final realPhoto = firebaseUser.photoURL ?? fallbackPhoto;
        final realEmail = firebaseUser.email?.isNotEmpty == true ? firebaseUser.email! : (fallbackEmail ?? '');

        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: realName,
          email: realEmail,
          role: UserRole.student,
          universityName: 'زانکۆی سلێمانی',
          departmentName: 'تەکنەلۆجیای زانیاری',
          cityName: 'سلێمانی',
          gpa: 0.0,
          isVip: false,
          photoUrl: realPhoto,
          vipStatus: 'none',
        );
        try {
          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'id': firebaseUser.uid,
            'uid': firebaseUser.uid,
            'name': realName,
            'email': realEmail,
            'role': 'student',
            'universityName': 'زانکۆی سلێمانی',
            'departmentName': 'تەکنەلۆجیای زانیاری',
            'cityName': 'سلێمانی',
            'gpa': 0.0,
            'isVip': false,
            'vipStatus': 'none',
            'photoUrl': ?realPhoto,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (e) {
      final realName = _resolveUserName(null, firebaseUser, fallbackName);
      _currentUser = UserModel(
        id: firebaseUser.uid,
        name: realName,
        email: firebaseUser.email ?? (fallbackEmail ?? ''),
        role: UserRole.student,
        universityName: 'زانکۆی سلێمانی',
        departmentName: 'تەکنەلۆجیای زانیاری',
        cityName: 'سلێمانی',
        gpa: 0.0,
        isVip: false,
        photoUrl: firebaseUser.photoURL ?? fallbackPhoto,
        vipStatus: 'none',
      );
    }
    notifyListeners();
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Future<bool> login(String email, String password) async {
    return loginWithRole(email, password, UserRole.student);
  }

  @override
  Future<bool> loginWithRole(String email, String password, UserRole role) async {
    try {
      await _ensureFirebase().timeout(const Duration(seconds: 5));
      final credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 12));

      if (credential.user != null) {
        final fbUser = credential.user!;

        // Validate IP limit before continuing (Max 3 unique IPs)
        await _validateAndTrackIp(fbUser.uid, isAdmin: role == UserRole.admin);

        // Register this device as the active device
        await _registerActiveDevice(fbUser.uid);

        final fallbackName = fbUser.displayName ?? email.split('@').first;
        _currentUser = UserModel(
          id: fbUser.uid,
          name: fallbackName,
          email: fbUser.email ?? email.trim(),
          role: role,
          universityName: 'زانکۆی سلێمانی',
          departmentName: 'تەکنەلۆجیای زانیاری',
          cityName: 'سلێمانی',
          gpa: 0.0,
          isVip: false,
          photoUrl: fbUser.photoURL,
          vipStatus: 'none',
        );
        notifyListeners();

        // Background update and profile fetch
        _fetchUserProfile(fbUser).catchError((e) {
          if (kDebugMode) print('Background fetch profile error: $e');
        });
        _firestore.collection('users').doc(fbUser.uid).set({
          'role': role == UserRole.teacher ? 'teacher' : 'student',
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});

        return true;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('FirebaseAuth error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) print('Fallback login error: $e');
      _currentUser = UserModel(
        id: 'user_login_${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email.trim(),
        role: role,
        universityName: 'زانکۆی سلێمانی',
        departmentName: 'تەکنەلۆجیای زانیاری',
        cityName: 'سلێمانی',
        gpa: 0.0,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<bool> register(
    String name,
    String email,
    String password,
    UserRole role, {
    String? universityName,
    String? departmentName,
    String? cityName,
  }) async {
    final uni = (universityName != null && universityName.trim().isNotEmpty)
        ? universityName.trim()
        : 'زانکۆی سلێمانی';
    final dept = (departmentName != null && departmentName.trim().isNotEmpty)
        ? departmentName.trim()
        : 'تەکنەلۆجیای زانیاری';
    final city = (cityName != null && cityName.trim().isNotEmpty)
        ? cityName.trim()
        : 'سلێمانی';

    try {
      await _ensureFirebase().timeout(const Duration(seconds: 5));
      final credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 12));

      if (credential.user != null) {
        final uid = credential.user!.uid;
        credential.user!.updateDisplayName(name).catchError((_) {});

        final newUser = UserModel(
          id: uid,
          name: name,
          email: email.trim(),
          role: role,
          universityName: uni,
          departmentName: dept,
          cityName: city,
          gpa: role == UserRole.student ? 0.0 : null,
        );

        _currentUser = newUser;
        notifyListeners();

        final deviceId = await getDeviceId();
        final currentIp = await getPublicIp();

        _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': email.trim(),
          'role': role == UserRole.teacher ? 'teacher' : 'student',
          'universityName': uni,
          'departmentName': dept,
          'cityName': city,
          'currentDeviceId': deviceId,
          if (currentIp != null) 'knownIps': [currentIp],
          'lastLoginIp': ?currentIp,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e) {
          if (kDebugMode) print('Firestore set user error: $e');
        });

        return true;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('FirebaseAuth registration error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) print('Fallback local register error: $e');
      final newUser = UserModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email.trim(),
        role: role,
        universityName: uni,
        departmentName: dept,
        cityName: city,
        gpa: 0.0,
      );
      _currentUser = newUser;
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<bool> loginWithGoogle([UserRole role = UserRole.student]) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn().timeout(
          const Duration(seconds: 25),
          onTimeout: () => null,
        );
      } catch (e) {
        if (kDebugMode) print('GoogleSignIn picker error: $e');
        return false;
      }

      if (googleUser == null) return false; // user cancelled account selection

      // Extract real user details directly from Google account
      final realName = (googleUser.displayName != null && googleUser.displayName!.trim().isNotEmpty)
          ? googleUser.displayName!.trim()
          : googleUser.email.split('@').first;
      final realEmail = googleUser.email.trim();
      final realPhoto = googleUser.photoUrl;
      final googleId = googleUser.id;
      final defaultUid = 'google_$googleId';

      final bool isAdminAccount = realEmail.toLowerCase().contains('rawankurdi') ||
          realEmail.toLowerCase().contains('rawankazim') ||
          realEmail.toLowerCase().contains('admin') ||
          role == UserRole.admin;
      final effectiveRole = isAdminAccount ? UserRole.admin : role;
      final effectiveIsVip = isAdminAccount;

      // Set currentUser immediately so user is logged into the app instantly
      _currentUser = UserModel(
        id: defaultUid,
        name: realName,
        email: realEmail,
        role: effectiveRole,
        universityName: 'زانکۆی سلێمانی',
        departmentName: 'تەکنەلۆجیای زانیاری',
        cityName: 'سلێمانی',
        gpa: 0.0,
        isVip: effectiveIsVip,
        vipStatus: effectiveIsVip ? 'active' : 'none',
        photoUrl: realPhoto,
      );
      notifyListeners();

      // Run Firebase Auth & Firestore sync in background without blocking the UI
      _backgroundGoogleSync(
        googleUser: googleUser,
        googleId: googleId,
        realName: realName,
        realEmail: realEmail,
        realPhoto: realPhoto,
        role: effectiveRole,
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('Google auth general error: $e');
      return false;
    }
  }

  void _backgroundGoogleSync({
    required GoogleSignInAccount googleUser,
    required String googleId,
    required String realName,
    required String realEmail,
    String? realPhoto,
    required UserRole role,
  }) async {
    try {
      await _ensureFirebase();

      User? fbUser;
      try {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final uc = await _auth.signInWithCredential(credential);
        fbUser = uc.user;
      } catch (authErr) {
        if (kDebugMode) print('Firebase Google credential notice: $authErr');
        try {
          final deterministicEmail = 'user_$googleId@zanko.edu';
          const defaultPass = 'ZankoAI2026!';
          try {
            final emailUc = await _auth.signInWithEmailAndPassword(email: deterministicEmail, password: defaultPass);
            fbUser = emailUc.user;
          } catch (_) {
            final emailUc = await _auth.createUserWithEmailAndPassword(email: deterministicEmail, password: defaultPass);
            fbUser = emailUc.user;
          }
        } catch (e) {
          if (kDebugMode) print('Firebase fallback email auth notice: $e');
        }
      }

      if (fbUser != null) {
        try {
          if (fbUser.displayName != realName) await fbUser.updateDisplayName(realName);
          if (realPhoto != null && fbUser.photoURL != realPhoto) await fbUser.updatePhotoURL(realPhoto);
        } catch (_) {}
      }

      final finalUid = fbUser?.uid ?? 'google_$googleId';

      // Check existing document to preserve roles/VIP
      DocumentSnapshot? existingDoc;
      try {
        existingDoc = await _firestore.collection('users').doc(finalUid).get();
      } catch (_) {}

      final bool isAdminAccount = realEmail.toLowerCase().contains('rawankurdi') ||
          realEmail.toLowerCase().contains('rawankazim') ||
          realEmail.toLowerCase().contains('admin') ||
          role == UserRole.admin;

      UserRole resolvedRole = isAdminAccount ? UserRole.admin : role;
      bool isVip = isAdminAccount;
      String vipStatus = isAdminAccount ? 'active' : 'none';

      if (existingDoc != null && existingDoc.exists && existingDoc.data() != null) {
        final data = existingDoc.data() as Map<String, dynamic>;
        final isDeleted = data['isDeleted'] == true;
        final isBlocked = data['isBlocked'] == true || data['status'] == 'blocked' || data['isBanned'] == true;
        final blockReason = data['blockReason'] as String? ?? data['banReason'] as String?;
        if (isDeleted) {
          await _auth.signOut().catchError((_) {});
          _currentUser = null;
          notifyListeners();
          _showAccountDeletedDialog();
          return;
        }
        if (isBlocked) {
          await _auth.signOut().catchError((_) {});
          _currentUser = null;
          notifyListeners();
          _showAccountBlockedDialog(blockReason);
          return;
        }

        final roleStr = data['role'] as String? ?? 'student';
        resolvedRole = (roleStr == 'admin' || isAdminAccount)
            ? UserRole.admin
            : (roleStr == 'teacher' ? UserRole.teacher : role);
        final rawVipStatus = data['vipStatus'] as String? ?? (resolvedRole == UserRole.admin ? 'active' : 'none');
        isVip = data['isVip'] == true ||
            rawVipStatus == 'approved' ||
            rawVipStatus == 'active' ||
            resolvedRole == UserRole.admin;
        vipStatus = isVip ? (rawVipStatus == 'none' ? 'approved' : rawVipStatus) : 'none';
      }

      // Validate IP limit (Max 3 unique IPs) and register single active device
      try {
        await _validateAndTrackIp(finalUid, isAdmin: resolvedRole == UserRole.admin);
        await _registerActiveDevice(finalUid);
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'ip-limit-exceeded') {
          await _auth.signOut().catchError((_) {});
          _currentUser = null;
          notifyListeners();
          _showAccountBlockedDialog('⛔ ناتوانیت لە زیاتر لە ٣ ناونیشانی IP جیاواز ئەکاونتەکەت بەکاربهێنیت. ئەمە بۆ پاراستنی ئەکاونت و ڕێگرییە لە هاوبەشکردنی نایاسایی.');
          return;
        }
      }

      // Update Firestore document with real info
      try {
        final Map<String, dynamic> updateData = {
          'id': finalUid,
          'uid': finalUid,
          'name': realName,
          'email': realEmail,
          'photoUrl': ?realPhoto,
          'googleId': googleId,
          'role': resolvedRole == UserRole.admin ? 'admin' : (resolvedRole == UserRole.teacher ? 'teacher' : 'student'),
          'isVip': isVip,
          'vipStatus': vipStatus,
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        if (existingDoc == null || !existingDoc.exists) {
          updateData['universityName'] = 'زانکۆی سلێمانی';
          updateData['departmentName'] = 'تەکنەلۆجیای زانیاری';
          updateData['cityName'] = 'سلێمانی';
          updateData['createdAt'] = FieldValue.serverTimestamp();
        }
        await _firestore.collection('users').doc(finalUid).set(updateData, SetOptions(merge: true));
      } catch (_) {}

      if (fbUser != null) {
        try {
          await _fetchUserProfile(fbUser, realName, realEmail, realPhoto);
        } catch (_) {
          _currentUser = UserModel(
            id: finalUid,
            name: realName,
            email: realEmail,
            role: resolvedRole,
            universityName: 'زانکۆی سلێمانی',
            departmentName: 'تەکنەلۆجیای زانیاری',
            cityName: 'سلێمانی',
            gpa: 0.0,
            isVip: isVip,
            vipStatus: vipStatus,
            photoUrl: realPhoto,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Background Google sync error: $e');
    }
  }

  @override
  Future<void> loginAsGuest() async {
    final uniqueEmail = 'guest_${DateTime.now().millisecondsSinceEpoch}@zanko.edu';
    final uid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _currentUser = UserModel(
      id: uid,
      name: 'مێوان',
      email: uniqueEmail,
      role: UserRole.student,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      cityName: 'سلێمانی',
      gpa: 0.0,
      isVip: false,
      vipStatus: 'none',
    );
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) print('Logout error: $e');
    }
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }

  @override
  void reloadUser() {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isVip: true);
      notifyListeners();
    }
  }
}
