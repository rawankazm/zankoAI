import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  final url = 'https://zankoai.rawankurdi181.workers.dev';

  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('Worker GET / : status ${res.statusCode}, body: $body');
  } catch (e) {
    print('Worker error: $e');
  }

  client.close();
}
