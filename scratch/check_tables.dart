import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final key = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  final tables = [
    'notifications',
    'announcements',
    'system_announcements',
    'ads',
    'advertisements',
    'banners',
    'promotions',
    'universities',
    'faculties',
    'departments',
    'courses',
    'profiles',
    'subscriptions',
    'payments',
    'app_configs',
    'system_settings',
    'audit_logs',
    'course_materials',
    'flashcards',
    'quizzes'
  ];

  for (final t in tables) {
    try {
      final req = await client.getUrl(Uri.parse('$url/rest/v1/$t?select=*&limit=1'));
      req.headers.set('apikey', key);
      req.headers.set('Authorization', 'Bearer $key');
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      if (res.statusCode == 200) {
        print('[EXISTS] $t: 200 OK -> $body');
      } else {
        print('[NOT FOUND / ERROR] $t: ${res.statusCode} -> ${body.length > 80 ? body.substring(0, 80) : body}');
      }
    } catch (e) {
      print('[EXCEPTION] $t: $e');
    }
  }
  client.close();
}
