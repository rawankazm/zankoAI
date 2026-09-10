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

  final notifReq = await client.getUrl(Uri.parse('$url/rest/v1/notifications?select=*&order=created_at.desc'));
  notifReq.headers.set('apikey', anonKey);
  notifReq.headers.set('Authorization', 'Bearer $accessToken');
  final notifRes = await notifReq.close();
  final notifBody = await utf8.decodeStream(notifRes);
  final List<dynamic> list = jsonDecode(notifBody);
  print('Total in notifications: ${list.length}');
  for (final item in list) {
    print('ID: ${item['id']} | Title: ${item['title']} | Data: ${item['data']}');
  }
  client.close();
}
