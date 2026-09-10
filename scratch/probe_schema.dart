import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final key = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  // Fetch OpenAPI definition of PostgREST to see all tables and columns!
  try {
    final req = await client.getUrl(Uri.parse('$url/rest/v1/'));
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('OpenAPI spec status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final spec = jsonDecode(body);
      final definitions = spec['definitions'] as Map<String, dynamic>?;
      if (definitions != null) {
        print('Available tables in schema: ${definitions.keys.toList()}');
        if (definitions.containsKey('notifications')) {
          print('notifications columns: ${(definitions['notifications']['properties'] as Map).keys.toList()}');
        }
        if (definitions.containsKey('universities')) {
          print('universities columns: ${(definitions['universities']['properties'] as Map).keys.toList()}');
        }
        if (definitions.containsKey('courses')) {
          print('courses columns: ${(definitions['courses']['properties'] as Map).keys.toList()}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  client.close();
}
