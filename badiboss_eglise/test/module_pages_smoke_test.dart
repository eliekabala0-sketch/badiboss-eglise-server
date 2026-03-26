import 'package:badiboss_eglise/reports/ui/reports_page.dart';
import 'package:badiboss_eglise/screens/modules/announcements_page.dart';
import 'package:badiboss_eglise/screens/modules/messages_page.dart';
import 'package:badiboss_eglise/screens/modules/secretariat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  testWidgets('reports page renders', (tester) async {
    await _pump(tester, const ReportsPage());
    expect(find.textContaining('Rapports'), findsWidgets);
  });

  testWidgets('announcements page renders', (tester) async {
    await _pump(tester, const AnnouncementsPage());
    expect(find.textContaining('Annonces'), findsWidgets);
  });

  testWidgets('messages page renders', (tester) async {
    await _pump(tester, const MessagesPage());
    expect(find.textContaining('Messages'), findsWidgets);
  });

  testWidgets('secretariat page renders', (tester) async {
    await _pump(tester, const SecretariatPage());
    expect(find.textContaining('Secrétariat'), findsWidgets);
  });
}
