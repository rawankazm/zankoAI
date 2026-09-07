import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Bridges ZankoAI Flutter application directly into the admin panel Firestore
/// project (tomartv-67cda):
/// 1. Synchronizes active users into Firestore `users` collection without overwriting admin VIP approval.
/// 2. Posts VIP purchase requests to Firestore `vip_requests` collection.
/// 3. Detects VIP approval from the admin panel and automatically promotes the user
///    to VIP in Supabase PostgreSQL and the mobile app.
class VipFirestoreService {
  static const String _firebaseApiKey = 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA';
  static const String _firebaseProjectId = 'tomartv-67cda';

  /// Obtains a persistent, authenticated Firebase session tied to the user email
  static Future<Map<String, String>?> _getFirebaseAuthToken({
    required String userEmail,
    String? userId,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase().isNotEmpty
        ? userEmail.trim().toLowerCase()
        : ((userId ?? 'user') + '@zanko.edu');

    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenKey = 'zanko_fb_token_' + cleanEmail;
      final expKey = 'zanko_fb_exp_' + cleanEmail;
      final localIdKey = 'zanko_fb_uid_' + cleanEmail;
      final refreshKey = 'zanko_fb_refresh_' + cleanEmail;

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
          final refreshUri = Uri.parse('https://securetoken.googleapis.com/v1/token?key=' + _firebaseApiKey);
          final rReq = await client.postUrl(refreshUri);
          rReq.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
          rReq.write('grant_type=refresh_token&refresh_token=' + cachedRefresh);
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
      final syncPassword = 'ZankoFbSync2026_' + cleanEmail.hashCode.abs().toString();

      // Try signIn first
      final signInUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + _firebaseApiKey);
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
        final signUpUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=' + _firebaseApiKey);
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
        final anonUri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=' + _firebaseApiKey);
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
      debugPrint('Error obtaining Firebase auth token: ' + e.toString());
    }
    return null;
  }

  /// Synchronizes a user profile directly to the Firestore `users` collection.
  /// CRITICAL: Uses updateMask so it NEVER overwrites an admin approval with false!
  static Future<void> syncUserToFirestore(UserModel user) async {
    if (user.isGuest || user.email.isEmpty) return;

    try {
      final auth = await _getFirebaseAuthToken(userEmail: user.email, userId: user.id);
      final idToken = auth?['idToken'];
      final localId = auth?['localId'];
      if (idToken == null || localId == null) return;

      final client = HttpClient();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Build updateMask field paths
      final maskPaths = <String>[
        'name',
        'email',
        'role',
        'university',
        'department',
        'city',
        'status',
        'lastLoginAt',
        'supabaseId',
      ];

      final fieldsMap = <String, dynamic>{
        'name': {'stringValue': user.name.trim().isNotEmpty ? user.name.trim() : 'بەکارهێنەر'},
        'email': {'stringValue': user.email.trim().toLowerCase()},
        'role': {'stringValue': user.role.name},
        'university': {'stringValue': user.universityName ?? ''},
        'department': {'stringValue': user.departmentName ?? ''},
        'city': {'stringValue': user.cityName ?? ''},
        'status': {'stringValue': 'active'},
        'isBlocked': {'booleanValue': false},
        'lastLoginAt': {'timestampValue': nowIso},
        'supabaseId': {'stringValue': user.id},
      };

      // ONLY include isVip and vipStatus when user is actually VIP!
      // This prevents ever clearing an admin approval from the client.
      if (user.isVip) {
        maskPaths.add('isVip');
        maskPaths.add('vipStatus');
        fieldsMap['isVip'] = {'booleanValue': true};
        fieldsMap['vipStatus'] = {'stringValue': user.vipStatus.isNotEmpty ? user.vipStatus : 'active'};
      }

      final maskQuery = maskPaths.map((p) => 'updateMask.fieldPaths=' + p).join('&');
      final userUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/' +
            _firebaseProjectId +
            '/databases/(default)/documents/users/' +
            localId +
            '?' +
            maskQuery,
      );

      final req = await client.patchUrl(userUri);
      req.headers.contentType = ContentType.json;
      req.headers.set('Authorization', 'Bearer ' + idToken);

      req.write(jsonEncode({'fields': fieldsMap}));
      final resp = await req.close();
      await resp.drain();
      client.close();
      debugPrint('Synced user "' + user.name + '" to Firestore users/' + localId + ': status ' + resp.statusCode.toString());
    } catch (e) {
      debugPrint('Error syncing user to Firestore: ' + e.toString());
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
        'https://firestore.googleapis.com/v1/projects/' +
            _firebaseProjectId +
            '/databases/(default)/documents/vip_requests',
      );
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      if (idToken != null) {
        req.headers.set('Authorization', 'Bearer ' + idToken);
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
        debugPrint('Successfully submitted VIP request to Firestore: ' + body);
      } else {
        debugPrint('Firestore submit returned status ' + resp.statusCode.toString() + ': ' + body);
      }

      // 2. Also ensure users/$localId is set to pending in Firestore
      try {
        final maskQuery = 'updateMask.fieldPaths=email&updateMask.fieldPaths=name&updateMask.fieldPaths=vipStatus&updateMask.fieldPaths=role&updateMask.fieldPaths=status';
        final userUri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/' +
              _firebaseProjectId +
              '/databases/(default)/documents/users/' +
              localId +
              '?' +
              maskQuery,
        );
        final uReq = await client.patchUrl(userUri);
        uReq.headers.contentType = ContentType.json;
        if (idToken != null) {
          uReq.headers.set('Authorization', 'Bearer ' + idToken);
        }
        uReq.write(jsonEncode({
          'fields': {
            'email': {'stringValue': userEmail.trim().toLowerCase()},
            'name': {'stringValue': userName.trim()},
            'vipStatus': {'stringValue': 'pending'},
            'role': {'stringValue': 'student'},
            'status': {'stringValue': 'active'},
          }
        }));
        final uResp = await uReq.close();
        await uResp.drain();
      } catch (_) {}

      client.close();
    } catch (e) {
      debugPrint('Error posting VIP request to Firestore: ' + e.toString());
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
      debugPrint('Notice saving to Supabase payment_transactions: ' + supaErr.toString());
    }

    return firestoreSuccess;
  }

  /// Checks if the admin approved VIP on the admin web panel (Firestore users or vip_requests)
  /// and syncs the status to Supabase profiles. Returns true ONLY when admin has approved.
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
      bool isApproved = false;

      // 1. Check users/$localId document
      try {
        final uri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/' +
              _firebaseProjectId +
              '/databases/(default)/documents/users/' +
              localId,
        );
        final req = await client.getUrl(uri);
        req.headers.set('Authorization', 'Bearer ' + idToken);

        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();

        if (resp.statusCode == 200) {
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          final fields = parsed['fields'] as Map<String, dynamic>?;
          if (fields != null) {
            final isVipVal = fields['isVip']?['booleanValue'] == true;
            final vipStatusVal = fields['vipStatus']?['stringValue']?.toString().toLowerCase();

            if (isVipVal || vipStatusVal == 'active' || vipStatusVal == 'approved') {
              isApproved = true;
            }
          }
        }
      } catch (e) {
        debugPrint('Notice checking users doc: ' + e.toString());
      }

      // 2. Also check vip_requests collection via runQuery for status == "approved"
      if (!isApproved) {
        try {
          final cleanEmail = userEmail.trim().toLowerCase();
          final qUri = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/' +
                _firebaseProjectId +
                '/databases/(default)/documents:runQuery',
          );
          final qReq = await client.postUrl(qUri);
          qReq.headers.contentType = ContentType.json;
          qReq.headers.set('Authorization', 'Bearer ' + idToken);

          final qPayload = {
            'structuredQuery': {
              'from': [{'collectionId': 'vip_requests'}],
              'where': {
                'compositeFilter': {
                  'op': 'AND',
                  'filters': [
                    {
                      'fieldFilter': {
                        'field': {'fieldPath': 'userEmail'},
                        'op': 'EQUAL',
                        'value': {'stringValue': cleanEmail},
                      }
                    },
                    {
                      'fieldFilter': {
                        'field': {'fieldPath': 'status'},
                        'op': 'EQUAL',
                        'value': {'stringValue': 'approved'},
                      }
                    },
                  ],
                },
              },
              'limit': 1,
            },
          };

          qReq.write(jsonEncode(qPayload));
          final qResp = await qReq.close();
          final qBody = await qResp.transform(utf8.decoder).join();

          if (qResp.statusCode == 200) {
            final results = jsonDecode(qBody) as List<dynamic>;
            for (final item in results) {
              if (item is Map<String, dynamic> && item['document'] != null) {
                isApproved = true;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Notice checking vip_requests: ' + e.toString());
        }
      }

      client.close();

      // If admin approved:
      if (isApproved) {
        // Cache locally for offline and instant UI persistence
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('zanko_user_is_vip_' + userId, true);
        } catch (_) {}

        // Call PostgreSQL SECURITY DEFINER RPC to update profiles & subscriptions
        try {
          await Supabase.instance.client.rpc(
            'sync_admin_approved_vip',
            params: {
              'p_user_id': userId,
              'p_plan': 'PREMIUM_MONTHLY',
              'p_days': 365,
            },
          );
          debugPrint('Successfully synced admin VIP approval via RPC for ' + userId);
        } catch (rpcErr) {
          debugPrint('RPC sync notice (falling back to direct update): ' + rpcErr.toString());
          try {
            await Supabase.instance.client.from('profiles').update({
              'plan': 'premium',
              'vip_expiry': DateTime.now().add(const Duration(days: 365)).toUtc().toIso8601String(),
            }).eq('id', userId);
          } catch (_) {}
        }

        return true;
      } else {
        // Admin has not approved yet
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('zanko_user_is_vip_' + userId, false);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error syncing VIP status from Firestore: ' + e.toString());
    }
    return false;
  }
}
