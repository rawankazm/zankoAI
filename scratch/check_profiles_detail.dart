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

  // Check own profile
  final req = await client.getUrl(Uri.parse('$url/rest/v1/profiles?id=eq.5422b9af-71a2-41e1-9eff-d0d68e976cff'));
  req.headers.set('apikey', anonKey);
  req.headers.set('Authorization', 'Bearer $accessToken');
  final res = await req.close();
  print('Own profile status: ${res.statusCode}');
  print('Own profile body: ${await utf8.decodeStream(res)}');

  // Check all profiles count
  final reqAll = await client.getUrl(Uri.parse('$url/rest/v1/profiles?select=*'));
  reqAll.headers.set('apikey', anonKey);
  reqAll.headers.set('Authorization', 'Bearer $accessToken');
  final resAll = await reqAll.close();
  print('All profiles body: ${await utf8.decodeStream(resAll)}');
}
