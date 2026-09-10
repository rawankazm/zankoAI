import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final anonKey = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  // 1. Sign in as admin
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

  if (accessToken == null) {
    print('Failed to authenticate');
    client.close();
    return;
  }
  print('Admin authenticated successfully');

  // 2. Try to insert a university
  final uniReq = await client.postUrl(Uri.parse('$url/rest/v1/universities'));
  uniReq.headers.set('apikey', anonKey);
  uniReq.headers.set('Authorization', 'Bearer $accessToken');
  uniReq.headers.set('Content-Type', 'application/json');
  uniReq.headers.set('Prefer', 'return=representation');
  uniReq.add(utf8.encode(jsonEncode({
    'name': 'Salahaddin University - Erbil',
    'name_ku': 'زانکۆی سەڵاحەدین - هەولێر',
    'name_ar': 'جامعة صلاح الدين - أربيل',
    'code': 'SUE',
    'city': 'Erbil',
    'country': 'Iraq'
  })));
  final uniRes = await uniReq.close();
  final uniBody = await utf8.decodeStream(uniRes);
  print('POST /universities status: ${uniRes.statusCode}, body: $uniBody');

  // 3. Test reading universities with anon key (Flutter app)
  final readReq = await client.getUrl(Uri.parse('$url/rest/v1/universities?select=*'));
  readReq.headers.set('apikey', anonKey);
  readReq.headers.set('Authorization', 'Bearer $anonKey');
  final readRes = await readReq.close();
  final readBody = await utf8.decodeStream(readRes);
  print('ANON GET /universities status: ${readRes.statusCode}, body: $readBody');

  client.close();
}
