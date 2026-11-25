/// Application entry point for QR Code Reader.
///
/// Initializes Flutter bindings, configures the system UI chrome,
/// loads persisted scan history, and launches the root widget.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'logic/scan_history_provider.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status bar blends with the camera preview on the scanner tab.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // History is loaded before the first frame so the list is ready immediately.
  final historyProvider = ScanHistoryProvider();
  await historyProvider.loadHistory();

  runApp(QrScannerApp(historyProvider: historyProvider));
}

/// Root widget that provides Material theming and injects the shared
/// [ScanHistoryProvider] into the widget tree.
class QrScannerApp extends StatelessWidget {
  final ScanHistoryProvider historyProvider;

  const QrScannerApp({super.key, required this.historyProvider});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: MainNavigationScreen(historyProvider: historyProvider),
    );
  }
}
