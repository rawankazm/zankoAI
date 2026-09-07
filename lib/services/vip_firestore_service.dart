import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Bridges ZankoAI Flutter application directly into the admin panel's Firestore
/// project (tomartv-67cda):
/// 1. Synchronizes all active users into Firestore `users` collection so they appear
///    in real-time on https://zanko-admin.vercel.app/users ("بەکارهێنەران").
/// 2. Posts VIP purchase requests to Firestore `vip_requests` collection
///    so they appear on https://zanko-admin.vercel.app/vip ("داواکاریەکانی VIP").
/// 3. Detects VIP approval from the admin panel and automatically promotes the user
///    to VIP in Supabase and the mobile app.
class VipFirestoreService {
  static const String _firebaseApiKey = 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA';
  static const String _firebaseProjectId = 'tomartv-67cda';

  /// Obtains a persistent, authenticated Firebase session tied to the user's email
  static Future<Map<String, String>?> _getFirebaseAuthToken({
    required String userEmail,
    String? userId,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase().isNotEmpty
        ? userEmail.trim().toLowerCase()
        : '${userId ?? "user"}@zanko.edu';

    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenKey = 'zanko_fb_token_$cleanEmail';
      final expKey = 'zanko_fb_exp_$cleanEmail';
      final localIdKey = 'zanko_fb_uid_$cleanEmail';
      final refreshKey = 'zanko_fb_refresh_$cleanEmail';

      final cachedToken = prefs.getString(tokenKey);
      final cachedLocalId = prefs.getString(localIdKey);
      final expMs = prefs.getInt(expKey) ?? 0;
      final cachedRefresh = prefs.getString(refreshKey);

      // 1. If cached token is valid for at least 5 more minutes, use it
      if (cachedToken != null &&
          cachedLocalId != null &&
          expMs > DateTime.now().millisecondsSinceEpoch + 300000) {
        return {'idToken': cachedToken, 'localId': cachedLocalId};
      }

      final client = HttpClient();

      // 2. If we have a refresh token, refresh it to keep the exact same localId
      if (cachedRefresh != null && cachedRefresh.isNotEmpty) {
        try {
          final refreshUri = Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_firebaseApiKey');
          final rReq = await client.postUrl(refreshUri);
          rReq.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
          rReq.write('grant_type=refresh_token&refresh_token=$cachedRefresh');
          final rResp = await rReq.close();
          final rBody = await rResp.transform(utf8.decoder).join();
          if (rResp.statusCode == 200) {
            final rParsed = jsonDecode(rBody) as Map<String, dynamic>;
            final newIdToken = rParsed['id_token']?.toString();
            final uid = rParsed['user_id']?.toString() ?? cachedLocalId ?? '';
            final newRefresh = rParsed['refresh_token']?.toString() ?? cachedRefresh;
            final expiresIn = int.tryParse(rParsed['expires_in']?.toString() ?? '3600') ?? 3600;

            if (newIdToken != null && uid.isNotEmpty) {
              await prefs.setString(tokenKey, newIdToken);
              await prefs.setString(localIdKey, uid);
              await prefs.setString(refreshKey, newRefresh);
              await prefs.setInt(expKey, DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000));
              client.close();
              return {'idToken': newIdToken, 'localId': uid};
            }
          }
        } catch (_) {}
      }

      // 3. Authenticate with deterministic sync password for this user
      final syncPassword = 'ZankoFbSync2026_${cleanEmail.hashCode.abs()}';

      // Try signIn first
      final signInUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_firebaseApiKey');
      var req = await client.postUrl(signInUri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'email': cleanEmail,
        'password': syncPassword,
        'returnSecureToken': true,
      }));
      var resp = await req.close();
      var body = await resp.transform(utf8.decoder).join();
      var parsed = jsonDecode(body) as Map<String, dynamic>;

      // If signIn failed, create the Firebase account
      if (resp.statusCode != 200) {
        final signUpUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseApiKey');
        req = await client.postUrl(signUpUri);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'email': cleanEmail,
          'password': syncPassword,
          'returnSecureToken': true,
        }));
        resp = await req.close();
        body = await resp.transform(utf8.decoder).join();
        parsed = jsonDecode(body) as Map<String, dynamic>;
      }

      // Fallback: anonymous sign-in if email registration fails
      if (resp.statusCode != 200) {
        final anonUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseApiKey');
        req = await client.postUrl(anonUri);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'returnSecureToken': true}));
        resp = await req.close();
        body = await resp.transform(utf8.decoder).join();
        parsed = jsonDecode(body) as Map<String, dynamic>;
      }

      client.close();

      final idToken = parsed['idToken']?.toString();
      final localId = parsed['localId']?.toString();
      final refreshToken = parsed['refreshToken']?.toString();
      final expiresIn = int.tryParse(parsed['expiresIn']?.toString() ?? '3600') ?? 3600;

      if (idToken != null && localId != null) {
        await prefs.setString(tokenKey, idToken);
        await prefs.setString(localIdKey, localId);
        if (refreshToken != null) await prefs.setString(refreshKey, refreshToken);
        await prefs.setInt(expKey, DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000));
        return {'idToken': idToken, 'localId': localId};
      }
    } catch (e) {
      debugPrint('Error obtaining Firebase auth token: $e');
    }
    return null;
  }

  /// Synchronizes a user's profile directly to the Firestore `users` collection.
  /// This ensures every user appears in the admin panel under "بەکارهێنەران".
  static Future<void> syncUserToFirestore(UserModel user) async {
    if (user.isGuest || user.email.isEmpty) return;

    try {
      final auth = await _getFirebaseAuthToken(userEmail: user.email, userId: user.id);
      final idToken = auth?['idToken'];
      final localId = auth?['localId'];
      if (idToken == null || localId == null) return;

      final client = HttpClient();
      final userUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents/users/$localId',
      );
      final req = await client.patchUrl(userUri);
      req.headers.contentType = ContentType.json;
      req.headers.set('Authorization', 'Bearer $idToken');

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'fields': {
          'name': {'stringValue': user.name.trim().isNotEmpty ? user.name.trim() : 'بەکارهێنەر'},
          'email': {'stringValue': user.email.trim().toLowerCase()},
          'role': {'stringValue': user.role.name},
          'university': {'stringValue': user.universityName ?? ''},
          'department': {'stringValue': user.departmentName ?? ''},
          'city': {'stringValue': user.cityName ?? ''},
          'isVip': {'booleanValue': user.isVip},
          'vipStatus': {'stringValue': user.vipStatus},
          'status': {'stringValue': 'active'},
          'isBlocked': {'booleanValue': false},
          'lastLoginAt': {'timestampValue': nowIso},
          'createdAt': {'timestampValue': nowIso},
          'supabaseId': {'stringValue': user.id},
        }
      };

      req.write(jsonEncode(payload));
      final resp = await req.close();
      await resp.drain();
      client.close();
      debugPrint('Synced user "${user.name}" to Firestore users/$localId: status ${resp.statusCode}');
    } catch (e) {
      debugPrint('Error syncing user to Firestore: $e');
    }
  }

  /// Submits a VIP upgrade request to Firestore `vip_requests` collection
  /// so it appears immediately on `zanko-admin.vercel.app/vip`.
  static Future<bool> submitVipRequest({
    required String userId,
    required String userName,
    required String userEmail,
    required String planId,
    required int amountIqd,
    required String paymentMethod,
    String? transactionId,
    String? receiptImageUrl,
  }) async {
    bool firestoreSuccess = false;

    try {
      final auth = await _getFirebaseAuthToken(userEmail: userEmail, userId: userId);
      final idToken = auth?['idToken'];
      final localId = auth?['localId'] ?? userId;

      final client = HttpClient();

      // 1. Post to vip_requests collection
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents/vip_requests',
      );
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      if (idToken != null) {
        req.headers.set('Authorization', 'Bearer $idToken');
      }

      final payload = {
        'fields': {
          'userId': {'stringValue': localId},
          'appUserId': {'stringValue': userId},
          'userName': {'stringValue': userName.trim().isNotEmpty ? userName.trim() : 'خوێندکار'},
          'userEmail': {'stringValue': userEmail.trim().toLowerCase()},
          'plan': {'stringValue': planId},
          'price': {'doubleValue': amountIqd.toDouble()},
          'paymentMethod': {'stringValue': paymentMethod},
          'transactionId': {'stringValue': transactionId?.trim() ?? ''},
          'receiptImageUrl': {'stringValue': receiptImageUrl?.trim() ?? ''},
          'status': {'stringValue': 'pending'},
          'requestedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        }
      };

      req.write(jsonEncode(payload));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        firestoreSuccess = true;
        debugPrint('Successfully submitted VIP request to Firestore: $body');
      } else {
        debugPrint('Firestore submit returned status ${resp.statusCode}: $body');
      }

      // 2. Also ensure users/$localId is set to pending in Firestore
      try {
        final userUri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents/users/$localId',
        );
        final uReq = await client.patchUrl(userUri);
        uReq.headers.contentType = ContentType.json;
        if (idToken != null) {
          uReq.headers.set('Authorization', 'Bearer $idToken');
        }
        uReq.write(jsonEncode({
          'fields': {
            'email': {'stringValue': userEmail.trim().toLowerCase()},
            'name': {'stringValue': userName.trim()},
            'vipStatus': {'stringValue': 'pending'},
            'isVip': {'booleanValue': false},
            'role': {'stringValue': 'student'},
            'status': {'stringValue': 'active'},
            'isBlocked': {'booleanValue': false},
            'lastLoginAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          }
        }));
        final uResp = await uReq.close();
        await uResp.drain();
      } catch (_) {}

      client.close();
    } catch (e) {
      debugPrint('Error posting VIP request to Firestore: $e');
    }

    // Persist in Supabase as a local audit record
    try {
      await Supabase.instance.client.from('payment_transactions').insert({
        'user_id': userId,
        'plan_id': planId,
        'amount_iqd': amountIqd,
        'gateway': paymentMethod,
        'transaction_reference': transactionId,
        'receipt_url': receiptImageUrl,
        'status': 'pending',
      });
    } catch (supaErr) {
      debugPrint('Notice saving to Supabase payment_transactions: $supaErr');
    }

    return firestoreSuccess;
  }

  /// Checks if the admin approved VIP on the admin web panel (Firestore users collection)
  /// and syncs the status to Supabase profiles. Returns true if VIP is active.
  static Future<bool> checkAndSyncVipStatus({
    required String userId,
    required String userEmail,
  }) async {
    try {
      final auth = await _getFirebaseAuthToken(userEmail: userEmail, userId: userId);
      final idToken = auth?['idToken'];
      final localId = auth?['localId'];

      if (localId == null || idToken == null) return false;

      final client = HttpClient();
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents/users/$localId',
      );
      final req = await client.getUrl(uri);
      req.headers.set('Authorization', 'Bearer $idToken');

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode == 200) {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        final fields = parsed['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final isVip = fields['isVip']?['booleanValue'] == true;
          final vipStatus = fields['vipStatus']?['stringValue']?.toString().toLowerCase();

          if (isVip || vipStatus == 'active' || vipStatus == 'approved') {
            // Update Supabase profile
            try {
              await Supabase.instance.client.from('profiles').update({
                'is_vip': true,
                'vip_status': 'active',
                'plan': 'vip_unlimited',
              }).eq('id', userId);
            } catch (_) {}
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing VIP status from Firestore: $e');
    }
    return false;
  }
}
