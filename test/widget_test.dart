import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HomeInventoryApp());
    
    // Da die App nun einen Login-Screen oder die Raum-Liste zeigt,
    // prüfen wir nur, ob die App überhaupt startet.
    expect(find.byType(HomeInventoryApp), findsOneWidget);
  });
}
