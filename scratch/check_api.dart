import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  client.connectionTimeout = Duration(seconds: 5);

  final urls = [
    'https://api.zankoai.com/health',
    'https://api.zankoai.com/api/health',
    'https://api.zankoai.com/api/v1/health',
  ];

  for (final u in urls) {
    try {
      final req = await client.getUrl(Uri.parse(u));
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      print('$u: status ${res.statusCode}, body: $body');
    } catch (e) {
      print('$u: ERROR $e');
    }
  }
  client.close();
}
