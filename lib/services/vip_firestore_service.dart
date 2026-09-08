import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
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
  static const String _firebaseApiKey =
      'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA';
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

      // 2. If we have a refresh token (either email-specific or global), refresh it to keep the exact same localId
      final effectiveRefresh =
          (cachedRefresh != null && cachedRefresh.isNotEmpty)
          ? cachedRefresh
          : prefs.getString('zanko_fb_global_refresh');
      final effectiveUid = (cachedLocalId != null && cachedLocalId.isNotEmpty)
          ? cachedLocalId
          : prefs.getString('zanko_fb_global_uid');

      if (effectiveRefresh != null && effectiveRefresh.isNotEmpty) {
        try {
          final refreshUri = Uri.parse(
            'https://securetoken.googleapis.com/v1/token?key=' +
                _firebaseApiKey,
          );
          final rReq = await client.postUrl(refreshUri);
          rReq.headers.contentType = ContentType.parse(
            'application/x-www-form-urlencoded',
          );
          rReq.write(
            'grant_type=refresh_token&refresh_token=' + effectiveRefresh,
          );
          final rResp = await rReq.close();
          final rBody = await rResp.transform(utf8.decoder).join();
          if (rResp.statusCode == 200) {
            final rParsed = jsonDecode(rBody) as Map<String, dynamic>;
            final newIdToken =
                rParsed['id_token']?.toString() ??
                rParsed['access_token']?.toString();
            final uid = rParsed['user_id']?.toString() ?? effectiveUid ?? '';
            final newRefresh =
                rParsed['refresh_token']?.toString() ?? effectiveRefresh;
            final expiresIn =
                int.tryParse(rParsed['expires_in']?.toString() ?? '3600') ??
                3600;

            if (newIdToken != null && uid.isNotEmpty) {
              await prefs.setString(tokenKey, newIdToken);
              await prefs.setString(localIdKey, uid);
              await prefs.setString(refreshKey, newRefresh);
              await prefs.setString('zanko_fb_global_uid', uid);
              await prefs.setString('zanko_fb_global_refresh', newRefresh);
              await prefs.setInt(
                expKey,
                DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
              );
              client.close();
              return {'idToken': newIdToken, 'localId': uid};
            }
          }
        } catch (_) {}
      }

      // 3. Authenticate with deterministic sync password for this user
      final syncPassword =
          'ZankoFbSync2026_' + cleanEmail.hashCode.abs().toString();

      // Try signIn first
      final signInUri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' +
            _firebaseApiKey,
      );
      var req = await client.postUrl(signInUri);
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'email': cleanEmail,
          'password': syncPassword,
          'returnSecureToken': true,
        }),
      );
      var resp = await req.close();
      var body = await resp.transform(utf8.decoder).join();
      var parsed = jsonDecode(body) as Map<String, dynamic>;

      // If signIn failed, create the Firebase account
      if (resp.statusCode != 200) {
        final signUpUri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=' +
              _firebaseApiKey,
        );
        req = await client.postUrl(signUpUri);
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'email': cleanEmail,
            'password': syncPassword,
            'returnSecureToken': true,
          }),
        );
        resp = await req.close();
        body = await resp.transform(utf8.decoder).join();
        parsed = jsonDecode(body) as Map<String, dynamic>;
      }

      // Fallback: anonymous sign-in if email registration fails
      if (resp.statusCode != 200) {
        final anonUri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=' +
              _firebaseApiKey,
        );
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
      final expiresIn =
          int.tryParse(parsed['expiresIn']?.toString() ?? '3600') ?? 3600;

      if (idToken != null && localId != null) {
        await prefs.setString(tokenKey, idToken);
        await prefs.setString(localIdKey, localId);
        await prefs.setString('zanko_fb_global_uid', localId);
        if (refreshToken != null) {
          await prefs.setString(refreshKey, refreshToken);
          await prefs.setString('zanko_fb_global_refresh', refreshToken);
        }
        await prefs.setInt(
          expKey,
          DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
        );
        return {'idToken': idToken, 'localId': localId};
      }
    } catch (e) {
      debugPrint('Error obtaining Firebase auth token: ' + e.toString());
    }
    return null;
  }

  /// Synchronizes a user profile directly to the Firestore `users` collection.
  /// CRITICAL: Uses updateMask so it NEVER overwrites an admin VIP approval with false!
  static Future<void> syncUserToFirestore(UserModel user) async {
    if (user.isGuest || user.email.isEmpty) return;

    try {
      final auth = await _getFirebaseAuthToken(
        userEmail: user.email,
        userId: user.id,
      );
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
        'name': {
          'stringValue': user.name.trim().isNotEmpty
              ? user.name.trim()
              : 'بەکارهێنەر',
        },
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
        fieldsMap['vipStatus'] = {
          'stringValue': user.vipStatus.isNotEmpty ? user.vipStatus : 'active',
        };
        if (user.vipExpiry != null) {
          maskPaths.add('vipExpiry');
          fieldsMap['vipExpiry'] = {
            'timestampValue': user.vipExpiry!.toUtc().toIso8601String(),
          };
        }
      }

      final maskQuery = maskPaths
          .map((p) => 'updateMask.fieldPaths=' + p)
          .join('&');
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
      debugPrint(
        'Synced user "' +
            user.name +
            '" to Firestore users/' +
            localId +
            ': status ' +
            resp.statusCode.toString(),
      );
    } catch (e) {
      debugPrint('Error syncing user to Firestore: ' + e.toString());
    }
  }

  /// Calculates VIP plan duration in days:
  /// - 9 months (academic year) -> 270 days
  /// - 3 months (quarter / semester) -> 90 days
  /// - 1 month -> 30 days
  /// - custom explicit days or price-based fallback
  static int calculatePlanDays({
    String? plan,
    num? price,
    int? durationDays,
    String? expiryIso,
  }) {
    if (durationDays != null && durationDays > 0) return durationDays;

    final p = (plan ?? '').trim().toLowerCase();
    if (p == '9_months' ||
        p == '9months' ||
        p == '9_month' ||
        p == '9m' ||
        p == 'annual' ||
        p == 'academic_year') {
      return 270; // 9 months
    }
    if (p == '3_months' ||
        p == '3months' ||
        p == '3_month' ||
        p == '3m' ||
        p == 'semester' ||
        p == 'quarterly') {
      return 90; // 3 months
    }
    if (p == '1_year' || p == 'yearly' || p == '12_months') {
      return 365; // 1 year
    }
    if (p == '1_month' || p == '1month' || p == 'monthly') {
      return 30; // 1 month
    }

    // Fallback based on IQD price
    if (price != null) {
      final pr = price.toInt();
      if (pr >= 35000) return 270; // 40,000 IQD -> 9 months
      if (pr >= 10000) return 90; // 12,000 IQD -> 3 months
      if (pr > 0) return 30; // 5,000 IQD -> 1 month
    }

    return 30;
  }

  /// Fetches authoritative payment configuration (numbers, accounts, prices)
  /// directly from Firestore `config/payment_config` where `zanko-admin.vercel.app` writes.
  static Future<Map<String, dynamic>?> getPaymentConfig() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ));
      final resp = await dio.get<Map<String, dynamic>>(
        'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents/config/payment_config',
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final fields = resp.data!['fields'] as Map<String, dynamic>? ?? {};
        final config = <String, dynamic>{};

        for (final entry in fields.entries) {
          final val = entry.value;
          if (val is Map) {
            if (val.containsKey('stringValue')) {
              config[entry.key] = val['stringValue'];
            } else if (val.containsKey('integerValue')) {
              config[entry.key] = int.tryParse(val['integerValue'].toString()) ?? val['integerValue'];
            } else if (val.containsKey('doubleValue')) {
              config[entry.key] = double.tryParse(val['doubleValue'].toString()) ?? val['doubleValue'];
            } else if (val.containsKey('booleanValue')) {
              config[entry.key] = val['booleanValue'];
            }
          } else {
            config[entry.key] = val;
          }
        }
        return config;
      }
    } catch (e) {
      debugPrint('Notice fetching Firestore payment config: $e');
    }
    return null;
  }

  /// Updates payment numbers in Firestore `config/payment_config` so they
  /// immediately reflect in both `zanko-admin.vercel.app` and mobile app clients.
  static Future<bool> savePaymentConfig({
    required String whatsapp,
    required String telegram,
    required String fib,
    required String fastpay,
    required String zaincash,
  }) async {
    try {
      final tokenData = await _getFirebaseAuthToken(userEmail: 'admin@zanko.edu');
      final idToken = tokenData?['idToken'];

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      final url = 'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents/config/payment_config'
          '?updateMask.fieldPaths=whatsappNumber'
          '&updateMask.fieldPaths=telegramUsername'
          '&updateMask.fieldPaths=fibNumber'
          '&updateMask.fieldPaths=fastPayNumber'
          '&updateMask.fieldPaths=zainCashNumber'
          '&updateMask.fieldPaths=updatedAt';

      final resp = await dio.patch(
        url,
        options: Options(
          headers: {
            if (idToken != null) 'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'fields': {
            'whatsappNumber': {'stringValue': whatsapp},
            'telegramUsername': {'stringValue': telegram},
            'fibNumber': {'stringValue': fib},
            'fastPayNumber': {'stringValue': fastpay},
            'zainCashNumber': {'stringValue': zaincash},
            'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          },
        },
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('Notice saving Firestore payment config: $e');
      return false;
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
    final planDays = calculatePlanDays(plan: planId, price: amountIqd);
    final durationMonths = planId == '9_months'
        ? 9
        : (planId == '3_months' ? 3 : 1);

    try {
      final auth = await _getFirebaseAuthToken(
        userEmail: userEmail,
        userId: userId,
      );
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
          'userName': {
            'stringValue': userName.trim().isNotEmpty
                ? userName.trim()
                : 'خوێندکار',
          },
          'userEmail': {'stringValue': userEmail.trim().toLowerCase()},
          'plan': {'stringValue': planId},
          'planDays': {'integerValue': planDays.toString()},
          'durationMonths': {'integerValue': durationMonths.toString()},
          'price': {'doubleValue': amountIqd.toDouble()},
          'paymentMethod': {'stringValue': paymentMethod},
          'transactionId': {'stringValue': transactionId?.trim() ?? ''},
          'receiptImageUrl': {'stringValue': receiptImageUrl?.trim() ?? ''},
          'status': {'stringValue': 'pending'},
          'requestedAt': {
            'timestampValue': DateTime.now().toUtc().toIso8601String(),
          },
        },
      };

      req.write(jsonEncode(payload));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        firestoreSuccess = true;
        debugPrint('Successfully submitted VIP request to Firestore: ' + body);

        // Store created document ID and request context for instant polling & approval detection
        try {
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          final docName = parsed['name']?.toString() ?? '';
          final docId = docName.split('/').last;
          if (docId.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('zanko_last_vip_req_id_' + userId, docId);
            await prefs.setString('zanko_last_vip_req_plan_' + userId, planId);
            await prefs.setInt('zanko_last_vip_req_days_' + userId, planDays);
            await prefs.setString(
              'zanko_last_vip_req_local_id_' + userId,
              localId,
            );

            final existingList =
                prefs.getStringList('zanko_vip_req_ids_' + userId) ?? [];
            if (!existingList.contains(docId)) {
              existingList.insert(0, docId);
              await prefs.setStringList(
                'zanko_vip_req_ids_' + userId,
                existingList.take(10).toList(),
              );
            }
          }
        } catch (saveErr) {
          debugPrint(
            'Notice caching created VIP request ID: ' + saveErr.toString(),
          );
        }
      } else {
        debugPrint(
          'Firestore submit returned status ' +
              resp.statusCode.toString() +
              ': ' +
              body,
        );
      }

      // 2. Also ensure users/$localId is set to pending with requested plan in Firestore
      try {
        final maskQuery =
            'updateMask.fieldPaths=email&updateMask.fieldPaths=name&updateMask.fieldPaths=vipStatus&updateMask.fieldPaths=role&updateMask.fieldPaths=status&updateMask.fieldPaths=plan&updateMask.fieldPaths=requestedPlan&updateMask.fieldPaths=requestedDays';
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
        uReq.write(
          jsonEncode({
            'fields': {
              'email': {'stringValue': userEmail.trim().toLowerCase()},
              'name': {'stringValue': userName.trim()},
              'vipStatus': {'stringValue': 'pending'},
              'role': {'stringValue': 'student'},
              'status': {'stringValue': 'active'},
              'plan': {'stringValue': planId},
              'requestedPlan': {'stringValue': planId},
              'requestedDays': {'integerValue': planDays.toString()},
            },
          }),
        );
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
        'metadata': {'plan_days': planDays, 'duration_months': durationMonths},
      });
    } catch (supaErr) {
      debugPrint(
        'Notice saving to Supabase payment_transactions: ' + supaErr.toString(),
      );
    }

    return firestoreSuccess;
  }

  /// Checks if the admin approved VIP on the admin web panel (Firestore users or vip_requests)
  /// and syncs the status to Supabase profiles and local cache with the EXACT requested duration:
  /// - 3 months -> 90 days
  /// - 9 months -> 270 days
  /// - 1 month -> 30 days
  static Future<bool> checkAndSyncVipStatus({
    required String userId,
    required String userEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final auth = await _getFirebaseAuthToken(
        userEmail: userEmail,
        userId: userId,
      );
      final idToken = auth?['idToken'];
      final localId =
          auth?['localId'] ??
          prefs.getString('zanko_last_vip_req_local_id_' + userId);

      if (idToken == null) return false;

      final client = HttpClient();
      bool isApproved = false;

      String? detectedPlan = prefs.getString(
        'zanko_last_vip_req_plan_' + userId,
      );
      num? detectedPrice;
      int? detectedDays = prefs.getInt('zanko_last_vip_req_days_' + userId);
      String? detectedExpiry;

      // ── Path 1: Check known vip_requests document IDs directly ─────────────
      // Firestore security rules allow the owner to read specific documents by ID!
      final knownReqIds = <String>[];
      final lastReqId = prefs.getString('zanko_last_vip_req_id_' + userId);
      if (lastReqId != null && lastReqId.isNotEmpty) {
        knownReqIds.add(lastReqId);
      }
      final allReqIds =
          prefs.getStringList('zanko_vip_req_ids_' + userId) ?? [];
      for (final id in allReqIds) {
        if (!knownReqIds.contains(id)) knownReqIds.add(id);
      }

      for (final reqDocId in knownReqIds) {
        try {
          final docUri = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/' +
                _firebaseProjectId +
                '/databases/(default)/documents/vip_requests/' +
                reqDocId,
          );
          final dReq = await client.getUrl(docUri);
          dReq.headers.set('Authorization', 'Bearer ' + idToken);
          final dResp = await dReq.close();
          final dBody = await dResp.transform(utf8.decoder).join();

          if (dResp.statusCode == 200) {
            final parsed = jsonDecode(dBody) as Map<String, dynamic>;
            final fields = parsed['fields'] as Map<String, dynamic>?;
            if (fields != null) {
              final rStatus = fields['status']?['stringValue']
                  ?.toString()
                  .toLowerCase();
              final rPlan =
                  fields['plan']?['stringValue']?.toString() ??
                  fields['planId']?['stringValue']?.toString();
              final rPrice =
                  (fields['price']?['doubleValue'] ??
                          fields['price']?['integerValue'])
                      as num?;
              final rExpiry =
                  fields['expiresAt']?['timestampValue']?.toString() ??
                  fields['expiresAt']?['stringValue']?.toString();
              final rDays = int.tryParse(
                fields['planDays']?['integerValue']?.toString() ?? '',
              );

              if (rPlan != null && rPlan.isNotEmpty) detectedPlan = rPlan;
              if (rPrice != null) detectedPrice = rPrice;
              if (rDays != null && rDays > 0) detectedDays = rDays;
              if (rExpiry != null && rExpiry.isNotEmpty)
                detectedExpiry = rExpiry;

              if (rStatus == 'approved') {
                isApproved = true;
                debugPrint(
                  'Detected VIP approval from vip_requests/' +
                      reqDocId +
                      ' (plan: ' +
                      (detectedPlan ?? '3_months') +
                      ')',
                );
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Notice checking doc ' + reqDocId + ': ' + e.toString());
        }
      }

      // ── Path 2: Query vip_requests WHERE userId == localId ────────────────
      // Firestore rule: resource.data.userId == request.auth.uid (200 OK!)
      if (!isApproved && localId != null && localId.isNotEmpty) {
        try {
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
              'from': [
                {'collectionId': 'vip_requests'},
              ],
              'where': {
                'fieldFilter': {
                  'field': {'fieldPath': 'userId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': localId},
                },
              },
              'limit': 5,
            },
          };

          qReq.write(jsonEncode(qPayload));
          final qResp = await qReq.close();
          final qBody = await qResp.transform(utf8.decoder).join();

          if (qResp.statusCode == 200) {
            final results = jsonDecode(qBody) as List<dynamic>;
            for (final item in results) {
              if (item is Map<String, dynamic> && item['document'] != null) {
                final rFields =
                    item['document']['fields'] as Map<String, dynamic>?;
                if (rFields != null) {
                  final rStatus = rFields['status']?['stringValue']
                      ?.toString()
                      .toLowerCase();
                  final rPlan =
                      rFields['plan']?['stringValue']?.toString() ??
                      rFields['planId']?['stringValue']?.toString();
                  final rPrice =
                      (rFields['price']?['doubleValue'] ??
                              rFields['price']?['integerValue'])
                          as num?;
                  final rExpiry =
                      rFields['expiresAt']?['timestampValue']?.toString() ??
                      rFields['expiresAt']?['stringValue']?.toString();
                  final rDays = int.tryParse(
                    rFields['planDays']?['integerValue']?.toString() ?? '',
                  );

                  if (rPlan != null && rPlan.isNotEmpty) detectedPlan = rPlan;
                  if (rPrice != null) detectedPrice = rPrice;
                  if (rDays != null && rDays > 0) detectedDays = rDays;
                  if (rExpiry != null && rExpiry.isNotEmpty)
                    detectedExpiry = rExpiry;

                  if (rStatus == 'approved') {
                    isApproved = true;
                    debugPrint(
                      'Detected VIP approval from runQuery userId filter (plan: ' +
                          (detectedPlan ?? '3_months') +
                          ')',
                    );
                    break;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Notice querying vip_requests: ' + e.toString());
        }
      }

      // ── Path 3: Check users/$localId document ─────────────────────────────
      if (!isApproved && localId != null && localId.isNotEmpty) {
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
              final vipStatusVal = fields['vipStatus']?['stringValue']
                  ?.toString()
                  .toLowerCase();

              if (isVipVal ||
                  vipStatusVal == 'active' ||
                  vipStatusVal == 'approved') {
                isApproved = true;
              }

              detectedPlan ??=
                  fields['plan']?['stringValue']?.toString() ??
                  fields['requestedPlan']?['stringValue']?.toString() ??
                  fields['vipPlan']?['stringValue']?.toString();
              detectedPrice ??=
                  (fields['price']?['doubleValue'] ??
                          fields['price']?['integerValue'])
                      as num?;
              detectedExpiry ??=
                  fields['vipExpiry']?['timestampValue']?.toString() ??
                  fields['expiresAt']?['timestampValue']?.toString() ??
                  fields['vipExpiresAt']?['timestampValue']?.toString() ??
                  fields['vipExpiry']?['stringValue']?.toString() ??
                  fields['expiresAt']?['stringValue']?.toString();
              detectedDays ??= int.tryParse(
                fields['vipDurationDays']?['integerValue']?.toString() ??
                    fields['requestedDays']?['integerValue']?.toString() ??
                    '',
              );
            }
          }
        } catch (e) {
          debugPrint('Notice checking users doc: ' + e.toString());
        }
      }

      // ── Path 4: Check users/$userId document (Supabase UUID) ───────────────
      if (!isApproved && userId.isNotEmpty && userId != localId) {
        try {
          final uUri = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/' +
                _firebaseProjectId +
                '/databases/(default)/documents/users/' +
                userId,
          );
          final uReq = await client.getUrl(uUri);
          uReq.headers.set('Authorization', 'Bearer ' + idToken);

          final uResp = await uReq.close();
          final uBody = await uResp.transform(utf8.decoder).join();

          if (uResp.statusCode == 200) {
            final parsed = jsonDecode(uBody) as Map<String, dynamic>;
            final fields = parsed['fields'] as Map<String, dynamic>?;
            if (fields != null) {
              final isVipVal = fields['isVip']?['booleanValue'] == true;
              final vipStatusVal = fields['vipStatus']?['stringValue']
                  ?.toString()
                  .toLowerCase();

              if (isVipVal ||
                  vipStatusVal == 'active' ||
                  vipStatusVal == 'approved') {
                isApproved = true;
                detectedPlan ??= fields['plan']?['stringValue']?.toString();
              }
            }
          }
        } catch (_) {}
      }

      client.close();

      // ── Path 5: Fallback to Supabase payment_transactions ─────────────────
      if (detectedPlan == null) {
        try {
          final tx = await Supabase.instance.client
              .from('payment_transactions')
              .select('plan_id, amount_iqd, status')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (tx != null) {
            detectedPlan = tx['plan_id']?.toString();
            detectedPrice = tx['amount_iqd'] is num
                ? (tx['amount_iqd'] as num)
                : null;
            if (tx['status'] == 'approved' || tx['status'] == 'completed') {
              isApproved = true;
            }
          }
        } catch (_) {}
      }

      // ── Path 6: Calculate exact plan days (3 months -> 90 days, 9 months -> 270 days) ───
      final finalDays = calculatePlanDays(
        plan: detectedPlan,
        price: detectedPrice,
        durationDays: detectedDays,
        expiryIso: detectedExpiry,
      );
      final finalDbPlan = finalDays >= 250
          ? 'PREMIUM_YEARLY'
          : (finalDays >= 75 ? 'PREMIUM_MONTHLY' : 'PREMIUM_MONTHLY');

      // ── Apply Approval & Synchronize ──────────────────────────────────────
      if (isApproved) {
        // Calculate new expiry date: extend from active expiry if already active in future
        final now = DateTime.now();
        DateTime baseDate = now;
        final cachedExpIso = prefs.getString('zanko_user_vip_expiry_' + userId);
        if (cachedExpIso != null && cachedExpIso.isNotEmpty) {
          final parsedExp = DateTime.tryParse(cachedExpIso);
          if (parsedExp != null && parsedExp.isAfter(now)) {
            baseDate = parsedExp;
          }
        }
        final newExpiry = baseDate.add(Duration(days: finalDays));

        // Cache locally for offline and instant UI persistence
        try {
          await prefs.setBool('zanko_user_is_vip_' + userId, true);
          await prefs.setString('zanko_user_vip_status_' + userId, 'active');
          await prefs.setInt('zanko_user_vip_days_' + userId, finalDays);
          await prefs.setString(
            'zanko_user_vip_expiry_' + userId,
            newExpiry.toIso8601String(),
          );
          await prefs.setString('zanko_user_vip_plan_' + userId, finalDbPlan);
        } catch (_) {}

        // 1. Sync the corrected 270-day or 90-day expiry directly back to Firestore users collection
        // so the web admin panel (zanko-admin.vercel.app) immediately changes from 30 days to 270 or 90 days!
        if (localId != null && localId.isNotEmpty) {
          try {
            final maskQuery =
                'updateMask.fieldPaths=isVip&updateMask.fieldPaths=vipStatus&updateMask.fieldPaths=vipExpiresAt&updateMask.fieldPaths=vipExpiry&updateMask.fieldPaths=vipDurationDays&updateMask.fieldPaths=plan';
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
            uReq.headers.set('Authorization', 'Bearer ' + idToken);
            uReq.write(
              jsonEncode({
                'fields': {
                  'isVip': {'booleanValue': true},
                  'vipStatus': {'stringValue': 'approved'},
                  'vipExpiresAt': {
                    'timestampValue': newExpiry.toUtc().toIso8601String(),
                  },
                  'vipExpiry': {
                    'timestampValue': newExpiry.toUtc().toIso8601String(),
                  },
                  'vipDurationDays': {'integerValue': finalDays.toString()},
                  'plan': {'stringValue': finalDbPlan},
                },
              }),
            );
            final uResp = await uReq.close();
            await uResp.drain();
            debugPrint(
              'Auto-corrected Firestore users/' +
                  localId +
                  ' vipExpiresAt to ' +
                  finalDays.toString() +
                  ' days (' +
                  newExpiry.toIso8601String() +
                  ')',
            );
          } catch (e) {
            debugPrint(
              'Notice syncing corrected vipExpiresAt to Firestore: ' +
                  e.toString(),
            );
          }
        }

        // 2. Call PostgreSQL SECURITY DEFINER RPC to update profiles & subscriptions
        try {
          await Supabase.instance.client.rpc(
            'sync_admin_approved_vip',
            params: {
              'p_user_id': userId,
              'p_plan': finalDbPlan,
              'p_days': finalDays,
            },
          );
          debugPrint(
            'Successfully synced admin VIP approval via RPC for ' +
                userId +
                ' (plan: ' +
                finalDbPlan +
                ', days: ' +
                finalDays.toString() +
                ')',
          );
        } catch (rpcErr) {
          debugPrint(
            'RPC sync notice (local VIP cache active): ' + rpcErr.toString(),
          );
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({
                  'is_vip': true,
                  'vip_status': 'active',
                  'vip_expiry': newExpiry.toUtc().toIso8601String(),
                })
                .eq('id', userId);
          } catch (_) {}
        }

        return true;
      } else {
        // Admin has not approved yet: ONLY reset if existing local expiry is expired!
        final cachedExpIso = prefs.getString('zanko_user_vip_expiry_' + userId);
        if (cachedExpIso != null && cachedExpIso.isNotEmpty) {
          final parsedExp = DateTime.tryParse(cachedExpIso);
          if (parsedExp != null && parsedExp.isAfter(DateTime.now())) {
            // Still active VIP locally!
            return true;
          }
        }
        try {
          await prefs.setBool('zanko_user_is_vip_' + userId, false);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error syncing VIP status from Firestore: ' + e.toString());
    }
    return false;
  }
}
