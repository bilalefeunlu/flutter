/// Root navigation screen with a bottom navigation bar.
///
/// Contains two tabs:
/// - **Tara** (Scan): Live camera and gallery QR scanner.
/// - **Geçmiş** (History): Date-grouped list of previous scans.
///
/// Uses [IndexedStack] so that both tabs retain their scroll position
/// and widget state when switching between them.
library;

import 'package:material_ui/material_ui.dart';

import '../../logic/scan_history_provider.dart';
import 'history_screen.dart';
import 'scanner_screen.dart';

/// Stateful shell that hosts the scanner and history screens behind
/// a two-destination [NavigationBar].
class MainNavigationScreen extends StatefulWidget {
  final ScanHistoryProvider historyProvider;

  const MainNavigationScreen({super.key, required this.historyProvider});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ScannerScreen(historyProvider: widget.historyProvider),
          HistoryScreen(
            historyProvider: widget.historyProvider,
            onGoToScan: () {
              setState(() => _currentIndex = 0);
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Tara',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Geçmiş',
          ),
        ],
      ),
    );
  }
}
