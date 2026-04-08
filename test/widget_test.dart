import 'package:flutter_test/flutter_test.dart';

import 'package:nex_pos_desktop/app.dart';

void main() {
  testWidgets('Login page renders auth UI', (WidgetTester tester) async {
    await tester.pumpWidget(const NexPosApp());

    expect(find.text('NexPos'), findsOneWidget);
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
