import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final key = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  try {
    final req = await client.postUrl(Uri.parse('$url/auth/v1/signup'));
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Content-Type', 'application/json');
    final payload = jsonEncode({
      'email': 'admin@zankoai.com',
      'password': 'ZankoAdmin2026!Secure',
      'data': {
        'full_name': 'ZankoAI Admin',
        'role': 'admin'
      }
    });
    final bytes = utf8.encode(payload);
    req.headers.set('Content-Length', bytes.length.toString());
    req.add(bytes);

    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('Auth signUp status: ${res.statusCode}, body: $body');
  } catch (e) {
    print('Auth error: $e');
  }

  client.close();
}
