import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afet_analiz/presentation/widgets/metric_card.dart';
import 'package:afet_analiz/presentation/widgets/status_badge.dart';

void main() {
  group('UI Components Widget Tests', () {
    testWidgets('StatusBadge renders correct label and style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Güvenli Bölge',
              type: StatusType.safe,
              icon: Icons.check_circle_outline,
            ),
          ),
        ),
      );

      expect(find.text('Güvenli Bölge'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('MetricCard renders title, value and status badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Mahalle Nüfusu',
              value: '42.100',
              subtitle: 'Altıeylül Bahçelievler',
              icon: Icons.people_alt_outlined,
              badge: StatusBadge(
                label: 'Yoğun Nüfus',
                type: StatusType.warning,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Mahalle Nüfusu'), findsOneWidget);
      expect(find.text('42.100'), findsOneWidget);
      expect(find.text('Altıeylül Bahçelievler'), findsOneWidget);
      expect(find.text('Yoğun Nüfus'), findsOneWidget);
    });
  });
}
