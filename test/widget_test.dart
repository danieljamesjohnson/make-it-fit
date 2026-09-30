import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_fit/main.dart';

void main() {
  testWidgets('shows the three steps', (WidgetTester tester) async {
    await tester.pumpWidget(const MakeItFitApp());
    expect(find.text('1. Size limit'), findsOneWidget);
    expect(find.text('2. Video'), findsOneWidget);
    expect(find.text('3. Make it fit'), findsOneWidget);
    expect(find.text('Email 25'), findsOneWidget);
  });
}
