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

  // Delete test ads: 'tt', 'test', 'ڕیکلامی تاقیکاری زانکۆ پریمێم', and old test notifications
  final idsToDelete = [
    '308b2166-911b-4090-a90e-deef96aa149b',
    '41e46045-d735-49bd-8b65-831a453ee723',
    '4568a449-3b24-464b-94b8-8dbb422145ea',
  ];

  for (final id in idsToDelete) {
    final delReq = await client.deleteUrl(Uri.parse('$url/rest/v1/notifications?id=eq.$id'));
    delReq.headers.set('apikey', anonKey);
    delReq.headers.set('Authorization', 'Bearer $accessToken');
    final delRes = await delReq.close();
    print('Delete $id status: ${delRes.statusCode}');
  }

  // Also query remaining
  final listReq = await client.getUrl(Uri.parse('$url/rest/v1/notifications?select=id,title,data&order=created_at.desc'));
  listReq.headers.set('apikey', anonKey);
  listReq.headers.set('Authorization', 'Bearer $accessToken');
  final listRes = await listReq.close();
  final listBody = await utf8.decodeStream(listRes);
  print('Remaining notifications: $listBody');

  client.close();
}
