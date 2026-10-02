import 'package:flutter/material.dart';

import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';
import '../auth/role_selection_screen.dart';
import 'manajemen_karyawan_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToKaryawan;
  final VoidCallback onNavigateToGeofence;
  final VoidCallback onNavigateToPayroll;
  final VoidCallback? onLogout;

  const AdminDashboardScreen({
    super.key,
    required this.onNavigateToKaryawan,
    required this.onNavigateToGeofence,
    required this.onNavigateToPayroll,
    this.onLogout,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: WartegTheme.error),
            SizedBox(width: 8),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Pemilik / Admin? Token sesi login Anda akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WartegTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Hapus bearer / JWT token yang tersimpan di memori dan service
    await WartegDataService().clearAuth();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Berhasil keluar dari akun.'),
          ],
        ),
        backgroundColor: WartegTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Arahkan kembali ke halaman login (RoleSelectionScreen) dan bersihkan tumpukan navigasi
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );

    onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final admin = service.adminProfile;
    final stats = admin['stats_overview'] as Map<String, dynamic>? ?? {};
    final feed = service.liveAttendanceFeed;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(left: 20.0),
              decoration: BoxDecoration(
                color: WartegTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store,
                color: WartegTheme.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Warteg Mobile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Panel Pemilik (Owner Mode)',
                    style: TextStyle(
                      fontSize: 11,
                      color: WartegTheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notifikasi operasional cabang: Semua shift pagi berjalan aman.',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.logout,
              size: 22,
              color: WartegTheme.outline,
            ),
            tooltip: 'Keluar Mode Pemilik',
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await service.init(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch Selector Bar (from Stitch)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.storefront,
                          color: WartegTheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Semua Cabang / Warteg Bahari Group',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.expand_more,
                      color: WartegTheme.outline,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Greeting & Shift Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: WartegTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 14,
                          color: WartegTheme.onPrimaryContainer,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Shift Pagi Berlangsung',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: WartegTheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '24 Okt 2024',
                    style: TextStyle(
                      fontSize: 12,
                      color: WartegTheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Selamat Pagi, ${admin['name'] ?? 'Pak Haji Mansur'}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: WartegTheme.onSurface,
                ),
              ),
              const Text(
                'Pantauan Operasional 4 Cabang Warteg Bahari',
                style: TextStyle(fontSize: 13, color: WartegTheme.outline),
              ),
              const SizedBox(height: 18),

              // Stat Grid (2x2)
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      title: 'Staf Aktif',
                      value: '${stats['total_active_staff'] ?? 24}',
                      badge: '+${stats['new_staff_count'] ?? 2} Baru',
                      icon: Icons.group,
                      color: WartegTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      title: 'Hadir Tepat Waktu',
                      value: '${stats['today_present'] ?? 21}',
                      badge: '88% Presensi',
                      icon: Icons.check_circle_outline,
                      color: WartegTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Aksi Cepat Pemilik (from Stitch)
              const Text(
                'Aksi Cepat Pemilik',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAdminActionButton(
                      icon: Icons.person_add,
                      label: 'Tambah Kru',
                      color: WartegTheme.primary,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder: (ctx) => const ModalTambahKaryawan(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAdminActionButton(
                      icon: Icons.payments_outlined,
                      label: 'Payroll',
                      color: const Color(0xFF2563EB),
                      onTap: onNavigateToPayroll,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Aktivitas Presensi Terkini (Live Feed from Stitch)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aktivitas Presensi Terkini',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: WartegTheme.successContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: WartegTheme.success,
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Live Feed',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...feed.map((item) {
                final isWarning = item['status_type'] == 'warning';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(
                          item['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['employee_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${item['role']} • ${item['branch_name']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: WartegTheme.outline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.face,
                                  size: 12,
                                  color: isWarning
                                      ? WartegTheme.warning
                                      : WartegTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Face ${item['face_score']} • Radius ${item['distance']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isWarning
                                        ? WartegTheme.warning
                                        : WartegTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isWarning
                                  ? WartegTheme.warningContainer
                                  : WartegTheme.successContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['status'] ?? '',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isWarning
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['timestamp'] ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: WartegTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: WartegTheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
