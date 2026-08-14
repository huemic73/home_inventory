import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final a = SharedPreferencesAuthStore(p);
    await tester.pumpWidget(HomeInventoryApp(prefs: p, authStore: a));
    expect(find.byType(HomeInventoryApp), findsOneWidget);
  });
}
