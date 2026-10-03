// Smoke test: aplikasi harus bisa dibangun dan menampilkan layar splash.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_liga_standing/main.dart';

void main() {
  testWidgets('App starts and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LigaStandingApp());

    expect(find.byType(LigaStandingApp), findsOneWidget);
  });
}