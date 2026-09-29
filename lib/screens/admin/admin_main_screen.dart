import 'package:flutter/material.dart';
import '../../theme/warteg_theme.dart';
import 'admin_dashboard_screen.dart';
import 'manajemen_karyawan_screen.dart';
import 'laporan_presensi_screen.dart';
import 'manajemen_cabang_screen.dart';
import 'manajemen_penggajian_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        indicatorColor: WartegTheme.secondaryContainer.withValues(alpha: 0.2),
        elevation: 4,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: WartegTheme.secondary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: WartegTheme.secondary),
            label: 'Kru',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check, color: WartegTheme.secondary),
            label: 'Jadwal',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on, color: WartegTheme.secondary),
            label: 'Cabang',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments, color: WartegTheme.secondary),
            label: 'Payroll',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return AdminDashboardScreen(
          onNavigateToKaryawan: () => setState(() => _currentIndex = 1),
          onNavigateToGeofence: () => setState(() => _currentIndex = 3),
          onNavigateToPayroll: () => setState(() => _currentIndex = 4),
          onLogout: () => Navigator.pop(context),
        );
      case 1:
        return const ManajemenKaryawanScreen();
      case 2:
        return const LaporanPresensiScreen();
      case 3:
        return const ManajemenCabangScreen();
      case 4:
        return const ManajemenPenggajianScreen();
      default:
        return AdminDashboardScreen(
          onNavigateToKaryawan: () {},
          onNavigateToGeofence: () {},
          onNavigateToPayroll: () {},
          onLogout: () => Navigator.pop(context),
        );
    }
  }
}
