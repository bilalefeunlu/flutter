/// Widget tests for the main navigation shell.
///
/// Verifies that both tabs are rendered, that switching to the history tab
/// shows the empty-state message, and that the "Hemen Tara" button navigates
/// back to the scanner tab.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_code_reader/core/theme/app_theme.dart';
import 'package:qr_code_reader/logic/scan_history_provider.dart';
import 'package:qr_code_reader/presentation/screens/main_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tab switching and empty-state navigation work correctly', (tester) async {
    final provider = ScanHistoryProvider();
    await provider.loadHistory();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MainNavigationScreen(historyProvider: provider),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Both navigation destinations should be visible.
    expect(find.text('Tara'), findsOneWidget);
    expect(find.text('Geçmiş'), findsOneWidget);

    // Switch to the History tab.
    await tester.tap(find.text('Geçmiş'));
    await tester.pump(const Duration(milliseconds: 300));

    // Empty-state content should be displayed.
    expect(find.text('Tarama Geçmişi'), findsOneWidget);
    expect(find.text('Henüz taranmış bir kod yok'), findsOneWidget);
    expect(find.text('Hemen Tara'), findsOneWidget);

    // Tapping "Hemen Tara" should switch back to the scanner tab.
    await tester.tap(find.text('Hemen Tara'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kodu vizöre hizalayın'), findsOneWidget);
  });
}
