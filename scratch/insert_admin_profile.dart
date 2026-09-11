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
  final accessToken = jsonDecode(signinBody)['access_token'];

  // Try insert own profile
  final insertReq = await client.postUrl(Uri.parse('$url/rest/v1/profiles'));
  insertReq.headers.set('apikey', anonKey);
  insertReq.headers.set('Authorization', 'Bearer $accessToken');
  insertReq.headers.set('Content-Type', 'application/json');
  insertReq.headers.set('Prefer', 'return=representation');
  insertReq.add(utf8.encode(jsonEncode({
    'id': '5422b9af-71a2-41e1-9eff-d0d68e976cff',
    'email': 'admin@zankoai.com',
    'full_name': 'ZankoAI Admin',
    'role': 'admin',
    'status': 'active',
  })));
  final insertRes = await insertReq.close();
  print('Insert status: ${insertRes.statusCode}');
  print('Insert body: ${await utf8.decodeStream(insertRes)}');
}
