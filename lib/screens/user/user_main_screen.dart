import 'package:flutter/material.dart';

import '../../theme/warteg_theme.dart';
import 'user_dashboard_screen.dart';
import 'presensi_scan_screen.dart';
import 'riwayat_presensi_screen.dart';
import 'slip_gaji_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _currentIndex = 0;
  bool _presensiIsClockIn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        indicatorColor: WartegTheme.primaryContainer,
        elevation: 4,
        onDestinationSelected: (idx) {
          if (idx == 1 && _currentIndex != 1) {
            _presensiIsClockIn = true;
          }
          setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home,
              color: WartegTheme.onPrimaryContainer,
            ),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(
              Icons.qr_code_scanner,
              color: WartegTheme.onPrimaryContainer,
            ),
            label: 'Presensi',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(
              Icons.history,
              color: WartegTheme.onPrimaryContainer,
            ),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(
              Icons.receipt_long,
              color: WartegTheme.onPrimaryContainer,
            ),
            label: 'Slip Gaji',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return UserDashboardScreen(
          onNavigateToPresensi: ({bool isClockIn = true}) {
            setState(() {
              _presensiIsClockIn = isClockIn;
              _currentIndex = 1;
            });
          },
        );
      case 1:
        return PresensiScanScreen(
          key: ValueKey(_presensiIsClockIn),
          initialClockInMode: _presensiIsClockIn,
          onAttendanceSuccess: () => setState(() => _currentIndex = 0),
        );
      case 2:
        return const RiwayatPresensiScreen();
      case 3:
        return const SlipGajiScreen();
      default:
        return UserDashboardScreen(
          onNavigateToPresensi: ({bool isClockIn = true}) {},
        );
    }
  }
}
