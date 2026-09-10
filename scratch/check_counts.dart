import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final key = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  final tables = [
    'universities',
    'faculties',
    'departments',
    'courses',
    'profiles',
    'notifications',
    'subscriptions',
    'payments',
    'audit_logs',
    'flashcards',
    'quizzes'
  ];

  for (final t in tables) {
    try {
      final req = await client.getUrl(Uri.parse('$url/rest/v1/$t?select=count'));
      req.headers.set('apikey', key);
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.set('Prefer', 'count=exact');
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final range = res.headers.value('content-range') ?? 'none';
      print('$t: status ${res.statusCode}, content-range: $range, body: $body');
    } catch (e) {
      print('$t: ERROR $e');
    }
  }

  client.close();
}
