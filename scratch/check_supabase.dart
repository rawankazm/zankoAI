import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final key = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  Future<void> checkGet(String endpoint) async {
    try {
      final req = await client.getUrl(Uri.parse('$url/rest/v1/$endpoint'));
      req.headers.set('apikey', key);
      req.headers.set('Authorization', 'Bearer $key');
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      print('GET $endpoint: status ${res.statusCode}, response: ${body.length > 200 ? body.substring(0, 200) + '...' : body}');
    } catch (e) {
      print('GET $endpoint: ERROR $e');
    }
  }

  Future<void> checkInsert(String endpoint, Map<String, dynamic> data) async {
    try {
      final req = await client.postUrl(Uri.parse('$url/rest/v1/$endpoint'));
      req.headers.set('apikey', key);
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Prefer', 'return=representation');
      final bytes = utf8.encode(jsonEncode(data));
      req.headers.set('Content-Length', bytes.length.toString());
      req.add(bytes);
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      print('POST $endpoint: status ${res.statusCode}, response: ${body.length > 200 ? body.substring(0, 200) + '...' : body}');
    } catch (e) {
      print('POST $endpoint: ERROR $e');
    }
  }

  print('--- Checking GET ---');
  await checkGet('ads?select=*');
  await checkGet('notifications?select=*&limit=3');
  await checkGet('universities?select=*&limit=3');
  await checkGet('departments?select=*&limit=3');
  await checkGet('courses?select=*&limit=3');
  await checkGet('profiles?select=id,full_name,role,is_vip&limit=3');

  print('\n--- Checking POST with anon key ---');
  await checkInsert('notifications', {
    'title': 'تاقیکردنەوەی سیستەم',
    'body': 'ئەم پەیامە تاقیکردنەوەی پەیوەندییە لە نێوان وێبسایت و ئەپ',
    'type': 'announcement',
    'status': 'delivered'
  });

  await checkInsert('ads', {
    'title': 'ڕیکلامی تاقیکاری زانکۆ',
    'description': 'تاقیکردنەوەی ڕیکلام لەگەڵ ئەپەکە',
    'isActive': true,
    'showOnScreens': ['home']
  });

  client.close();
}
