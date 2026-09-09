import 'dart:io';

void main() {
  final file = File(r'C:\dev\zanko-admin\src\services\adminService.js');
  var text = file.readAsStringSync().replaceAll('\r\n', '\n');

  text = text.replaceAll('async function {', 'async function triggerFcmPush() {');
  text = text.replaceAll(
    "    if (token) {\n    } else {\n    }\n",
    "    // Firebase FCM push disabled: Zero traffic to Firebase\n"
  );
  text = text.replaceAll(
    "const topic = target === 'user' ? null : (target === 'vip' ? 'vip_students' : 'all_students');",
    "// Pure Supabase: Notifications stream directly to app"
  );
  text = text.replaceAll(
    "title || 'U_U UOO U.UO OO UOO\"U O U,U  OU O_U.UOU+U U^U '",
    "title || 'پەیامی تایبەت لە ئەدمینەوە'"
  );

  file.writeAsStringSync(text);
  print('Cleaned adminService.js successfully');
}
