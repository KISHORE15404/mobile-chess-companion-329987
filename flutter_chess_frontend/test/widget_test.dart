import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_frontend/main.dart';

void main() {
  testWidgets('App boots and shows Chess title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Let initial async load start; UI shows progress first.
    await tester.pump();

    expect(find.text('Chess'), findsOneWidget);
  });
}
