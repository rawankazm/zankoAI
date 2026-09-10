import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://kjslmvoaanoqrizawllh.supabase.co';
  final anonKey = 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
  final client = HttpClient();

  // Sign in as admin
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

  // Insert Ad into notifications table with is_ad: true
  final adReq = await client.postUrl(Uri.parse('$url/rest/v1/notifications'));
  adReq.headers.set('apikey', anonKey);
  adReq.headers.set('Authorization', 'Bearer $accessToken');
  adReq.headers.set('Content-Type', 'application/json');
  adReq.headers.set('Prefer', 'return=representation');
  adReq.add(utf8.encode(jsonEncode({
    'title': 'داشکاندنی تایبەتی زانکۆ ئەی ئای VIP',
    'body': 'ئێستا بەشداربە لە پلانە تایبەتەکان بە 50% داشکاندن',
    'type': 'broadcast',
    'data': {
      'is_ad': true,
      'titleAr': 'خصم خاص على اشتراك VIP',
      'titleEn': 'Special 50% Discount on VIP',
      'descAr': 'اشترك الآن بخصم 50% على جميع باقات الذكاء الاصطناعي',
      'descEn': 'Subscribe now with 50% discount on all AI plans',
      'buttonTextKu': 'ئێستا بەشداربە',
      'buttonTextAr': 'اشترك الآن',
      'buttonTextEn': 'Subscribe Now',
      'imageUrl': 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=800',
      'linkUrl': 'https://zankoai.com/vip',
      'isActive': true,
      'showOnScreens': ['home', 'all']
    }
  })));

  final adRes = await adReq.close();
  final adBody = await utf8.decodeStream(adRes);
  print('Insert Ad status: ${adRes.statusCode}, body: $adBody');

  client.close();
}
