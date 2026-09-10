import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  final url = 'https://zankoai.rawankurdi181.workers.dev/send';

  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('X-Secret-Key', 'zanko-notification-secret-2026');
    req.add(utf8.encode(jsonEncode({
      'title': 'تاقیكردنەوەی زانكۆ',
      'body': 'سڵاو لە زانکۆ ئەی ئای',
      'topic': 'all_students'
    })));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('POST /send status: ${res.statusCode}, body: $body');
  } catch (e) {
    print('Error: $e');
  }

  client.close();
}
