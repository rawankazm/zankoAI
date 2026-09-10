import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final anonKey = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  // 1. Sign in with the created admin credentials to get a fresh JWT
  final signinReq = await client.postUrl(Uri.parse('$url/auth/v1/token?grant_type=password'));
  signinReq.headers.set('apikey', anonKey);
  signinReq.headers.set('Content-Type', 'application/json');
  signinReq.add(utf8.encode(jsonEncode({
    'email': 'admin@zankoai.com',
    'password': 'ZankoAdmin2026!Secure',
  })));
  final signinRes = await signinReq.close();
  final signinBody = await utf8.decodeStream(signinRes);
  final tokenData = jsonDecode(signinBody);
  final accessToken = tokenData['access_token'] as String?;
  print('Sign-in status: ${signinRes.statusCode}, token present: ${accessToken != null}');

  if (accessToken == null) {
    print('Failed to get access token: $signinBody');
    client.close();
    return;
  }

  // 2. Check profile
  final profReq = await client.getUrl(Uri.parse('$url/rest/v1/profiles?select=*'));
  profReq.headers.set('apikey', anonKey);
  profReq.headers.set('Authorization', 'Bearer $accessToken');
  final profRes = await profReq.close();
  final profBody = await utf8.decodeStream(profRes);
  print('GET /profiles status: ${profRes.statusCode}, body: $profBody');

  // 3. Try to insert notification
  final notifReq = await client.postUrl(Uri.parse('$url/rest/v1/notifications'));
  notifReq.headers.set('apikey', anonKey);
  notifReq.headers.set('Authorization', 'Bearer $accessToken');
  notifReq.headers.set('Content-Type', 'application/json');
  notifReq.headers.set('Prefer', 'return=representation');
  notifReq.add(utf8.encode(jsonEncode({
    'title': 'تاقیکردنەوەی سەرکەوتووی پەیام',
    'body': 'سڵاو! ئەم ئاگادارکردنەوەیە لە وێبسایتی ئەدمینەوە نێردراوە بۆ ئەپەکە.',
    'type': 'announcement'
  })));
  final notifRes = await notifReq.close();
  final notifBody = await utf8.decodeStream(notifRes);
  print('POST /notifications status: ${notifRes.statusCode}, body: $notifBody');

  // 4. Test authenticated read
  final authReadReq = await client.getUrl(Uri.parse('$url/rest/v1/notifications?select=*'));
  authReadReq.headers.set('apikey', anonKey);
  authReadReq.headers.set('Authorization', 'Bearer $accessToken');
  final authReadRes = await authReadReq.close();
  final authReadBody = await utf8.decodeStream(authReadRes);
  print('AUTH GET /notifications: status ${authReadRes.statusCode}, body: $authReadBody');

  // 5. Test anon read
  final anonReq = await client.getUrl(Uri.parse('$url/rest/v1/notifications?select=*'));
  anonReq.headers.set('apikey', anonKey);
  anonReq.headers.set('Authorization', 'Bearer $anonKey');
  final anonRes = await anonReq.close();
  final anonBody = await utf8.decodeStream(anonRes);
  print('ANON GET /notifications: status ${anonRes.statusCode}, body: $anonBody');

  client.close();
}
