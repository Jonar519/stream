// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:stream/main.dart';

void main() {
  testWidgets('muestra el dashboard epidemiologico principal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EpidemiologicalRadarApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Radar Epidemiologico'), findsOneWidget);
    expect(find.text('Registrar reporte'), findsOneWidget);
    expect(find.text('Mapa de calor comunitario'), findsOneWidget);
  });
}
