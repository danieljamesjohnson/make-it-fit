import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_fit/main.dart';

void main() {
  testWidgets('shows the flow', (WidgetTester tester) async {
    await tester.pumpWidget(const MakeItFitApp());
    expect(find.text('Make it fit.'), findsOneWidget);
    expect(find.text('Choose a video'), findsOneWidget);
    expect(find.text('Fit under'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Make it fit'), findsOneWidget);
  });
}
