import 'package:flutter_test/flutter_test.dart';
import 'package:cellar_sage/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CellarSageApp());
    expect(find.text('Cellar Sage'), findsOneWidget);
  });
}
