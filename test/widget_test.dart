import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nex_pos_desktop/app.dart';

void main() {
  testWidgets('Login page renders auth UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'TEST-DEVICE-ID',
      'is_activated': true,
    });

    await tester.pumpWidget(const NexPosApp());
    await tester.pumpAndSettle();

    expect(find.text('NexPos'), findsOneWidget);
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
