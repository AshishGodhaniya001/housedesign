import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/main.dart';
import 'package:test_app/screens/input_screen.dart';

void main() {
  testWidgets('shows startup screen then opens planner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('RoyalNest Planner'), findsOneWidget);
    expect(find.byType(InputScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(InputScreen), findsOneWidget);
  });
}
