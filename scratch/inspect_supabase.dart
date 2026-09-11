import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final anonKey = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  final req = await client.getUrl(Uri.parse('$url/rest/v1/'));
  req.headers.set('apikey', anonKey);
  final res = await req.close();
  final body = await utf8.decodeStream(res);
  final json = jsonDecode(body);
  print('Keys: ${json.keys}');
  if (json['paths'] != null) {
    print('Paths: ${(json['paths'] as Map).keys.take(20).toList()}');
  }
}
