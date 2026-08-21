import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/ui_components.dart';

void main() {
  group('InventoryPageLayout Tests', () {
    testWidgets('Renders layout without avatar when imageUrl is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InventoryPageLayout(
            title: 'Test Title',
            imageUrl: null,
            slivers: [
              SliverToBoxAdapter(
                child: Text('Content'),
              ),
            ],
          ),
        ),
      );

      // Verify title is rendered
      expect(find.text('Test Title'), findsOneWidget);

      // Verify no InventoryNetworkImage is present
      expect(find.byType(InventoryNetworkImage), findsNothing);
    });

    testWidgets('Renders layout with avatar when imageUrl is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InventoryPageLayout(
            title: 'Test Title With Image',
            imageUrl: 'https://example.com/image.jpg',
            slivers: [
              SliverToBoxAdapter(
                child: Text('Content'),
              ),
            ],
          ),
        ),
      );

      // Verify title is rendered
      expect(find.text('Test Title With Image'), findsOneWidget);

      // Verify InventoryNetworkImage is present (representing the avatar)
      expect(find.byType(InventoryNetworkImage), findsOneWidget);
    });
  });
}
