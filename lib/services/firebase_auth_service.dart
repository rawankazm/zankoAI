import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool? _lastNotifiedAdmin;
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

  void _showAccountBlockedDialog() {
    if (_isHandlingBlockedOrDeleted) return;
    _isHandlingBlockedOrDeleted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E222B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(CupertinoIcons.slash_circle_fill, color: Colors.redAccent, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'ئاگاداری بلۆککردن',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'بلۆک کرایت بەهۆی پابەند نەبوونت بە یاسا و ڕێساکانی ئەپەکە.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    rootNavigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                    _isHandlingBlockedOrDeleted = false;
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text(
                    'باشە',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        _isHandlingBlockedOrDeleted = false;
      }
    });
  }

  void _showPromotedToAdminDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;

      // Fetch admin website URL dynamically from config
      String adminUrl = 'https://zankoai-admin.web.app';
      try {
        final cfgDoc = await _firestore.collection('config').doc('app_config').get();
        if (cfgDoc.exists && cfgDoc.data() != null) {
          final fetched = cfgDoc.data()!['admin_website_url'] ?? cfgDoc.data()!['admin_url'];
          if (fetched != null && fetched.toString().trim().isNotEmpty) {
            adminUrl = fetched.toString().trim();
          }
        }
      } catch (_) {}

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
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
          );
        },
      );
    });
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
      if (firebaseUser == null) {
        _currentUser = null;
        _lastNotifiedVip = null;
        _lastNotifiedAdmin = null;
        notifyListeners();
      } else {
        _userDocSub = _firestore.collection('users').doc(firebaseUser.uid).snapshots().listen((doc) {
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
                'photoUrl': ?realPhoto,
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
              _lastNotifiedAdmin = null;
              notifyListeners();
              _showAccountDeletedDialog();
            }
            return;
          }

          // 2. Check if user was blocked by Admin from website
          final isBlocked = data['isBlocked'] == true || data['status'] == 'blocked' || data['isBanned'] == true;
          if (isBlocked) {
            if (!_isHandlingBlockedOrDeleted) {
              _auth.signOut().catchError((_) {});
              _currentUser = null;
              _lastNotifiedVip = null;
              _lastNotifiedAdmin = null;
              notifyListeners();
              _showAccountBlockedDialog();
            }
            return;
          }

          final roleStr = data['role'] as String? ?? 'student';
          final role = roleStr == 'admin'
              ? UserRole.admin
              : (roleStr == 'teacher' ? UserRole.teacher : UserRole.student);

          // 3. Check if user was promoted to Admin
          if (role == UserRole.admin && _lastNotifiedAdmin != true) {
            _lastNotifiedAdmin = true;
            _showPromotedToAdminDialog();
          }

          bool isVip = data['isVip'] == true || role == UserRole.admin;
          final vipStatus = data['vipStatus'] as String? ?? 'none';
          final vipExpiresAt = data['vipExpiresAt'] as Timestamp?;

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

          // Auto-heal name & ensure email and latest login timestamp exist in Firestore
          try {
            _firestore.collection('users').doc(firebaseUser.uid).set({
              'id': firebaseUser.uid,
              'uid': firebaseUser.uid,
              'name': realName,
              if (realEmail.isNotEmpty) 'email': realEmail,
              'photoUrl': ?realPhoto,
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}

          // Only notify if user model actually changed
          final changed = _currentUser == null ||
              _currentUser!.id != newUser.id ||
              _currentUser!.isVip != newUser.isVip ||
              _currentUser!.vipStatus != newUser.vipStatus ||
              _currentUser!.name != newUser.name ||
              _currentUser!.role != newUser.role ||
              _currentUser!.photoUrl != newUser.photoUrl ||
              _currentUser!.email != newUser.email;

          _currentUser = newUser;

          if (_lastNotifiedVip != isVip) {
            _lastNotifiedVip = isVip;
            NotificationService().listenToAdminNotifications(firebaseUser.uid, isVip);
          }

          if (changed) {
            notifyListeners();
          }
        });
      }
    });
  }


  Future<void> _fetchUserProfile(User firebaseUser, [String? fallbackName, String? fallbackEmail, String? fallbackPhoto]) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
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
        if (isBlocked) {
          await _auth.signOut().catchError((_) {});
          _currentUser = null;
          notifyListeners();
          _showAccountBlockedDialog();
          return;
        }

        final roleStr = data['role'] as String? ?? 'student';
        final role = roleStr == 'admin'
            ? UserRole.admin
            : (roleStr == 'teacher' ? UserRole.teacher : UserRole.student);

        // ─── VIP expiry check ───────────────────────────────────────────
        bool isVip = data['isVip'] == true || role == UserRole.admin;
        final vipStatus = data['vipStatus'] as String? ?? 'none';
        final vipExpiresAt = data['vipExpiresAt'] as Timestamp?;

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
      await _ensureFirebase();
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        await _fetchUserProfile(credential.user!);
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(role: role);
          try {
            await _firestore.collection('users').doc(credential.user!.uid).set({
              'role': role == UserRole.teacher ? 'teacher' : 'student',
            }, SetOptions(merge: true));
          } catch (_) {}
        }
        notifyListeners();
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
      await _ensureFirebase();
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        final uid = credential.user!.uid;
        await credential.user!.updateDisplayName(name);

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

        try {
          await _firestore.collection('users').doc(uid).set({
            'uid': uid,
            'name': name,
            'email': email.trim(),
            'role': 'student',
            'universityName': uni,
            'departmentName': dept,
            'cityName': city,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if (kDebugMode) print('Firestore set user error: $e');
        }

        _currentUser = newUser;
        notifyListeners();
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
        googleUser = await googleSignIn.signIn();
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
          _showAccountBlockedDialog();
          return;
        }

        final roleStr = data['role'] as String? ?? 'student';
        resolvedRole = (roleStr == 'admin' || isAdminAccount)
            ? UserRole.admin
            : (roleStr == 'teacher' ? UserRole.teacher : role);
        isVip = data['isVip'] == true || resolvedRole == UserRole.admin;
        vipStatus = data['vipStatus'] as String? ?? (resolvedRole == UserRole.admin ? 'active' : 'none');
      }

      // Update Firestore document with real info
      try {
        final Map<String, dynamic> updateData = {
          'id': finalUid,
          'name': realName,
          'email': realEmail,
          'photoUrl': ?realPhoto,
          'googleId': googleId,
          'role': resolvedRole == UserRole.admin ? 'admin' : (resolvedRole == UserRole.teacher ? 'teacher' : 'student'),
          if (resolvedRole == UserRole.admin) 'isVip': true,
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
