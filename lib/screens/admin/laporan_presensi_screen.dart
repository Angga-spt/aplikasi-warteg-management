import 'package:flutter/material.dart';

import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';

class LaporanPresensiScreen extends StatelessWidget {
  const LaporanPresensiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final employees = service.employees;

    final morningShift = employees
        .where((e) => (e['shift'] as String? ?? '').contains('Pagi'))
        .toList();
    final eveningShift = employees
        .where((e) => (e['shift'] as String? ?? '').contains('Sore'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Laporan Presensi & Jadwal',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mengekspor rekapitulasi presensi harian ke WhatsApp & Excel.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Bar (from Stitch)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                              Icons.calendar_today,
                              size: 16,
                              color: WartegTheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '24 Okt 2024 (Hari Ini)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: WartegTheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WartegTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sync,
                    color: WartegTheme.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Shift Pagi Section
            Row(
              children: [
                const Icon(
                  Icons.wb_sunny_outlined,
                  color: Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Shift Pagi (07:00 - 15:00)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${morningShift.length} Kru',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WartegTheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...morningShift.map((emp) => _buildScheduleRow(emp)),
            const SizedBox(height: 24),

            // Shift Sore Section
            Row(
              children: [
                const Icon(
                  Icons.nightlight_round_outlined,
                  color: Color(0xFF6366F1),
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Shift Sore & Malam (15:00 - 23:00)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${eveningShift.length} Kru',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WartegTheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (eveningShift.isNotEmpty)
              ...eveningShift.map((emp) => _buildScheduleRow(emp))
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'Kru shift malam dijadwalkan masuk pukul 15.00 WIB',
                    style: TextStyle(fontSize: 12, color: WartegTheme.outline),
                  ),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleRow(Map<String, dynamic> emp) {
    final status = emp['attendance_today'] as String? ?? 'Hadir';
    final isPresent = status == 'Hadir';
    final isLate = status == 'Terlambat';
    final isLeave = status == 'Izin';

    Color badgeColor = WartegTheme.surfaceContainerLow;
    Color textColor = WartegTheme.outline;
    if (isPresent) {
      badgeColor = WartegTheme.successContainer;
      textColor = const Color(0xFF065F46);
    } else if (isLate) {
      badgeColor = WartegTheme.warningContainer;
      textColor = const Color(0xFF92400E);
    } else if (isLeave) {
      badgeColor = WartegTheme.errorContainer;
      textColor = WartegTheme.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(
              emp['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${emp['role']} • ${emp['branch_name']}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: WartegTheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Jam: ${emp['clock_in'] ?? '-'}',
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
  }
}
