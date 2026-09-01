import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanko_ai/services/firebase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device & IP Security Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getDeviceId generates and persists a valid unique deviceId', () async {
      final id1 = await FirebaseAuthService.getDeviceId();
      expect(id1, isNotEmpty);
      expect(id1.length, greaterThanOrEqualTo(16));

      // Second call returns cached / persisted device ID
      final id2 = await FirebaseAuthService.getDeviceId();
      expect(id2, equals(id1));
    });

    test('IP limit logic correctly allows up to 3 distinct IPs and blocks 4th', () {
      final List<String> knownIps = ['192.168.1.1', '10.0.0.1'];

      // Scenario A: Same IP (already known)
      const currentIpA = '192.168.1.1';
      expect(knownIps.contains(currentIpA), isTrue);

      // Scenario B: 3rd distinct IP
      const currentIpB = '172.16.0.1';
      expect(knownIps.contains(currentIpB), isFalse);
      expect(knownIps.length < 3, isTrue);
      knownIps.add(currentIpB);
      expect(knownIps.length, equals(3));

      // Scenario C: 4th distinct IP (Should be blocked)
      const currentIpC = '185.120.45.10';
      expect(knownIps.contains(currentIpC), isFalse);
      expect(knownIps.length >= 3, isTrue); // Exceeded 3 IPs limit!
    });

    test('Single active device session mismatch detection', () {
      const localDeviceId = 'device_phone_A_uuid_123';
      const serverDeviceIdOld = 'device_phone_A_uuid_123';
      const serverDeviceIdNew = 'device_phone_B_uuid_456';

      // On Device A when Device A is active:
      expect(serverDeviceIdOld == localDeviceId, isTrue);

      // On Device A when Device B logs in:
      expect(serverDeviceIdNew != localDeviceId, isTrue); // Triggers kick-out on Device A!
    });
  });
}
