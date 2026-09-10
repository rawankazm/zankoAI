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

  // Test PATCH on row '308b2166-911b-4090-a90e-deef96aa149b'
  final patchReq = await client.patchUrl(Uri.parse('$url/rest/v1/notifications?id=eq.308b2166-911b-4090-a90e-deef96aa149b'));
  patchReq.headers.set('apikey', anonKey);
  patchReq.headers.set('Authorization', 'Bearer $accessToken');
  patchReq.headers.set('Content-Type', 'application/json');
  patchReq.headers.set('Prefer', 'return=representation');
  patchReq.add(utf8.encode(jsonEncode({
    'data': {
      'is_ad': true,
      'title': 'tt',
      'isActive': true,
      'showOnScreens': ['home', 'all']
    }
  })));
  final patchRes = await patchReq.close();
  final patchBody = await utf8.decodeStream(patchRes);
  print('PATCH status: ${patchRes.statusCode}, body: $patchBody');

  client.close();
}
