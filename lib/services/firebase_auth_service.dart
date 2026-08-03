import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

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
      try {
        await Firebase.initializeApp();
      } catch (_) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA',
            appId: '1:658020179072:android:75f948816199e3eed2da65',
            messagingSenderId: '658020179072',
            projectId: 'tomartv-67cda',
            storageBucket: 'tomartv-67cda.firebasestorage.app',
          ),
        );
      }
    }
  }

  void _listenToAuthState() {
    if (!_isFirebaseInitialized) return;
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        notifyListeners();
      } else {
        await _fetchUserProfile(firebaseUser);
      }
    });
  }

  Future<void> _fetchUserProfile(User firebaseUser) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final roleStr = data['role'] as String? ?? 'student';
        final role = roleStr == 'teacher' ? UserRole.teacher : UserRole.student;

        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: data['name'] ?? firebaseUser.displayName ?? 'خوێندکار',
          email: firebaseUser.email ?? '',
          role: role,
          universityName: data['universityName'] ?? 'زانکۆی سلێمانی',
          departmentName: data['departmentName'] ?? 'تەکنەلۆجیای زانیاری',
          cityName: data['cityName'] ?? 'سلێمانی',
          gpa: role == UserRole.student ? (data['gpa'] as num?)?.toDouble() ?? 3.65 : null,
        );
      } else {
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'خوێندکار',
          email: firebaseUser.email ?? '',
          role: UserRole.student,
          universityName: 'زانکۆی سلێمانی',
          departmentName: 'تەکنەلۆجیای زانیاری',
          cityName: 'سلێمانی',
          gpa: 3.65,
        );
      }
    } catch (e) {
      _currentUser = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'خوێندکار',
        email: firebaseUser.email ?? '',
        role: UserRole.student,
        universityName: 'زانکۆی سلێمانی',
        departmentName: 'تەکنەلۆجیای زانیاری',
        cityName: 'سلێمانی',
        gpa: 3.65,
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
        gpa: 3.65,
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
          gpa: role == UserRole.student ? 3.65 : null,
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
        gpa: 3.65,
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
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential credential = await _auth.signInWithPopup(googleProvider);

      if (credential.user != null) {
        await _fetchUserProfile(credential.user!);
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Google auth error: $e');
    }
    return false;
  }

  @override
  Future<void> loginAsGuest() async {
    _currentUser = UserModel(
      id: 'guest_user_${DateTime.now().millisecondsSinceEpoch}',
      name: 'مێوان',
      email: 'guest@zanko.edu',
      role: UserRole.student,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: 3.65,
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
    _currentUser = null;
    notifyListeners();
  }
}
