import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nex_pos_desktop/app.dart';

void main() {
  testWidgets('Login page renders auth UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'TEST-DEVICE-ID',
      'is_activated': true,
      'setup_app_mode': 'offline',
      'setup_admin_email': 'admin@example.com',
      'setup_admin_password_hash':
          '240be518fabd2724ddb6f04eeb3c8dd59bb59d76124db85c6b53de41fc9f1f0f',
      'setup_login_pin': '1234',
      'setup_default_login_method': 'emailPassword',
      'setup_shop_name': 'Test Shop',
    });

    await tester.pumpWidget(const NexPosApp());
    await tester.pumpAndSettle();

    expect(find.text('NexPos'), findsOneWidget);
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
