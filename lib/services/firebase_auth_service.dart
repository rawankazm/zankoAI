import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
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
        await Firebase.initializeApp();
    }
  }

  StreamSubscription? _authStateSub;
  StreamSubscription? _userDocSub;
  bool? _lastNotifiedVip;

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
        notifyListeners();
      } else {
        _userDocSub = _firestore.collection('users').doc(firebaseUser.uid).snapshots().listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final roleStr = data['role'] as String? ?? 'student';
            final role = roleStr == 'admin'
                ? UserRole.admin
                : (roleStr == 'teacher' ? UserRole.teacher : UserRole.student);

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

            final newUser = UserModel(
              id: firebaseUser.uid,
              name: realName,
              email: (data['email'] as String?)?.isNotEmpty == true ? data['email'] : (firebaseUser.email ?? ''),
              role: role,
              universityName: data['universityName'] ?? 'زانکۆی سلێمانی',
              departmentName: data['departmentName'] ?? 'تەکنەلۆجیای زانیاری',
              cityName: data['cityName'] ?? 'سلێمانی',
              gpa: role == UserRole.student ? (data['gpa'] as num?)?.toDouble() ?? 0.0 : null,
              isVip: isVip,
              photoUrl: realPhoto,
              vipStatus: vipStatus,
            );

            // Auto-heal old generic placeholder name in Firestore
            if (data['name'] != realName && realName != 'خوێندکار') {
              _firestore.collection('users').doc(firebaseUser.uid).set({
                'name': realName,
                if (realPhoto != null) 'photoUrl': realPhoto,
              }, SetOptions(merge: true));
            }

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
          } else {
            // New distinct user document creation
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
                'name': realName,
                'email': realEmail,
                'role': 'student',
                'universityName': 'زانکۆی سلێمانی',
                'departmentName': 'تەکنەلۆجیای زانیاری',
                'cityName': 'سلێمانی',
                'gpa': 0.0,
                'isVip': false,
                'vipStatus': 'none',
                if (realPhoto != null) 'photoUrl': realPhoto,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
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

        if (data['name'] != realName && realName != 'خوێندکار') {
          try {
            await _firestore.collection('users').doc(firebaseUser.uid).set({
              'name': realName,
              if (realPhoto != null) 'photoUrl': realPhoto,
            }, SetOptions(merge: true));
          } catch (_) {}
        }
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
            'name': realName,
            'email': realEmail,
            'role': 'student',
            'universityName': 'زانکۆی سلێمانی',
            'departmentName': 'تەکنەلۆجیای زانیاری',
            'cityName': 'سلێمانی',
            'gpa': 0.0,
            'isVip': false,
            'vipStatus': 'none',
            if (realPhoto != null) 'photoUrl': realPhoto,
            'createdAt': FieldValue.serverTimestamp(),
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
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
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

      // Set currentUser immediately so user is logged into the app instantly
      _currentUser = UserModel(
        id: defaultUid,
        name: realName,
        email: realEmail,
        role: role,
        universityName: 'زانکۆی سلێمانی',
        departmentName: 'تەکنەلۆجیای زانیاری',
        cityName: 'سلێمانی',
        gpa: 0.0,
        isVip: false,
        vipStatus: 'none',
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
        role: role,
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
          final anonCred = await _auth.signInAnonymously();
          fbUser = anonCred.user;
        } catch (_) {}
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

      UserRole resolvedRole = role;
      bool isVip = false;
      String vipStatus = 'none';

      if (existingDoc != null && existingDoc.exists && existingDoc.data() != null) {
        final data = existingDoc.data() as Map<String, dynamic>;
        final roleStr = data['role'] as String? ?? 'student';
        resolvedRole = roleStr == 'admin'
            ? UserRole.admin
            : (roleStr == 'teacher' ? UserRole.teacher : role);
        isVip = data['isVip'] == true || resolvedRole == UserRole.admin;
        vipStatus = data['vipStatus'] as String? ?? 'none';
      }

      // Update Firestore document with real info
      try {
        final Map<String, dynamic> updateData = {
          'id': finalUid,
          'name': realName,
          'email': realEmail,
          if (realPhoto != null) 'photoUrl': realPhoto,
          'googleId': googleId,
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        if (existingDoc == null || !existingDoc.exists) {
          updateData['role'] = role == UserRole.admin ? 'admin' : (role == UserRole.teacher ? 'teacher' : 'student');
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
    const defaultPass = 'ZankoAI2026!';
    try {
      await _auth.createUserWithEmailAndPassword(email: uniqueEmail, password: defaultPass);
    } catch (_) {}

    final firebaseUser = _auth.currentUser;
    _currentUser = UserModel(
      id: firebaseUser?.uid ?? 'guest_user_${DateTime.now().millisecondsSinceEpoch}',
      name: 'مێوان',
      email: uniqueEmail,
      role: UserRole.student,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: 0.0,
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
