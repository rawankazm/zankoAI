import 'dart:io';

void main() {
  final file = File(r'C:\dev\zanko-admin\src\services\adminService.js');
  var text = file.readAsStringSync().replaceAll('\r\n', '\n');

  // Neutralize triggerFcmPush completely so ZERO network calls go to Firebase FCM
  final fcmPushRegex = RegExp(
    r'async function triggerFcmPush[\s\S]*?export const sendNotification',
    multiLine: true,
  );

  const disabledFcm = '''async function triggerFcmPush({ title, body, topic = null, token = null }) {
  // Firebase FCM is completely disconnected: zero traffic sent to legacy Firebase users
  return { success: true, disconnected: true, note: 'Firebase FCM is completely disabled' };
}

export const sendNotification''';

  text = text.replaceFirst(fcmPushRegex, disabledFcm);

  // Remove any calls to triggerFcmPush inside approveVipRequest, rejectVipRequest, setUserVipStatus, sendNotification, sendDirectMessage
  text = text.replaceAll(RegExp(r'\s*await triggerFcmPush\(\{[\s\S]*?\}\);?'), '');
  text = text.replaceAll(RegExp(r'\s*triggerFcmPush\(\{[\s\S]*?\}\);?'), '');

  file.writeAsStringSync(text);
  print('Successfully disconnected Firebase FCM from C:\\dev\\zanko-admin\\src\\services\\adminService.js');
}
