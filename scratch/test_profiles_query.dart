import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final anonKey = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  // Sign in as admin
  final signinReq = await client.postUrl(Uri.parse('$url/auth/v1/token?grant_type=password'));
  signinReq.headers.set('apikey', anonKey);
  signinReq.headers.set('Content-Type', 'application/json');
  signinReq.add(utf8.encode(jsonEncode({
    'email': 'admin@zankoai.com',
    'password': 'ZankoAdmin2026!Secure',
  })));
  final signinRes = await signinReq.close();
  final signinBody = await utf8.decodeStream(signinRes);
  print('Auth response status: ${signinRes.statusCode}');
  final signinJson = jsonDecode(signinBody);
  final accessToken = signinJson['access_token'];
  print('Access token obtained: ${accessToken != null}');

  // 1. Try querying profiles table
  final req = await client.getUrl(Uri.parse('$url/rest/v1/profiles?select=*'));
  req.headers.set('apikey', anonKey);
  if (accessToken != null) {
    req.headers.set('Authorization', 'Bearer $accessToken');
  }
  final res = await req.close();
  final body = await utf8.decodeStream(res);
  print('Profiles status: ${res.statusCode}');
  print('Profiles response: $body');

  // 2. Try querying user_profiles or auth.users or users
  final req2 = await client.getUrl(Uri.parse('$url/rest/v1/users?select=*'));
  req2.headers.set('apikey', anonKey);
  if (accessToken != null) {
    req2.headers.set('Authorization', 'Bearer $accessToken');
  }
  final res2 = await req2.close();
  final body2 = await utf8.decodeStream(res2);
  print('users table status: ${res2.statusCode}');
  print('users response: $body2');
}
