import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final anonKey = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  final signinReq = await client.postUrl(Uri.parse('$url/auth/v1/token?grant_type=password'));
  signinReq.headers.set('apikey', anonKey);
  signinReq.headers.set('Content-Type', 'application/json');
  signinReq.add(utf8.encode(jsonEncode({
    'email': 'admin@zankoai.com',
    'password': 'ZankoAdmin2026!Secure',
  })));
  final signinRes = await signinReq.close();
  final signinBody = await utf8.decodeStream(signinRes);
  final accessToken = jsonDecode(signinBody)['access_token'] as String;

  final idsToSoftDelete = [
    '308b2166-911b-4090-a90e-deef96aa149b',
    '41e46045-d735-49bd-8b65-831a453ee723',
    '4568a449-3b24-464b-94b8-8dbb422145ea',
  ];

  for (final id in idsToSoftDelete) {
    final patchReq = await client.patchUrl(Uri.parse('$url/rest/v1/notifications?id=eq.$id'));
    patchReq.headers.set('apikey', anonKey);
    patchReq.headers.set('Authorization', 'Bearer $accessToken');
    patchReq.headers.set('Content-Type', 'application/json');
    patchReq.add(utf8.encode(jsonEncode({
      'data': {
        'is_ad': false,
        'is_deleted': true
      }
    })));
    final patchRes = await patchReq.close();
    print('Soft-delete $id status: ${patchRes.statusCode}');
  }

  // Now query all active ads from notifications
  final getReq = await client.getUrl(Uri.parse('$url/rest/v1/notifications?select=id,title,data&order=created_at.desc'));
  getReq.headers.set('apikey', anonKey);
  getReq.headers.set('Authorization', 'Bearer $accessToken');
  final getRes = await getReq.close();
  final getBody = await utf8.decodeStream(getRes);
  final List<dynamic> rows = jsonDecode(getBody);
  final activeAds = rows.where((r) => r['data'] != null && r['data']['is_ad'] == true && r['data']['is_deleted'] != true).toList();
  print('Active Ads count now: ${activeAds.length}');
  for (final a in activeAds) {
    print('Ad: ${a['title']}');
  }

  client.close();
}
