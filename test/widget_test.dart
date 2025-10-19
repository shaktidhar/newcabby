// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:newcabby/app/app.dart';

void main() {
  testWidgets('smoke', (tester) async {
    await tester.pumpWidget(const NewCabbyApp());
    expect(find.byType(NewCabbyApp), findsOneWidget);
  });
}
