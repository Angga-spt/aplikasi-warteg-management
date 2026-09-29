import 'package:flutter/material.dart';

import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';

class RiwayatPresensiScreen extends StatefulWidget {
  const RiwayatPresensiScreen({super.key});

  @override
  State<RiwayatPresensiScreen> createState() => _RiwayatPresensiScreenState();
}

class _RiwayatPresensiScreenState extends State<RiwayatPresensiScreen> {
  int selectedDay = 24;

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final history = service.attendanceHistory;
    final summary = history['monthly_summary'] as Map<String, dynamic>? ?? {};
    final calendar = history['weekly_calendar'] as List<dynamic>? ?? [];
    final records = history['records'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Presensi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {},
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: WartegTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      summary['month'] ?? 'Oktober 2024',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stat Summary Cards (from Stitch)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Hadir',
                    value: '${summary['total_present_days'] ?? 20} Hari',
                    color: WartegTheme.primary,
                    bgColor: WartegTheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Terlambat',
                    value: '${summary['total_late_count'] ?? 2} Kali',
                    color: WartegTheme.warning,
                    bgColor: WartegTheme.warningContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Izin / Cuti',
                    value: '${summary['total_leave_days'] ?? 1} Hari',
                    color: WartegTheme.secondary,
                    bgColor: const Color(0xFFFFEAD8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weekly Calendar Strip (from Stitch)
            const Text(
              'Pekan Ini (Minggu ke-4)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: WartegTheme.outline,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: calendar.map((day) {
                  final isSelected = day['day_num'] == selectedDay;
                  final status = day['status'] as String?;
                  Color statusDotColor = Colors.transparent;
                  if (status == 'present') statusDotColor = WartegTheme.primary;
                  if (status == 'late') statusDotColor = WartegTheme.warning;
                  if (status == 'off') statusDotColor = Colors.grey;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDay = day['day_num'] as int;
                      });
                    },
                    child: Container(
                      width: 48,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? WartegTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? WartegTheme.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            day['day_code'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : WartegTheme.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day['day_num'] ?? ''}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : WartegTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : statusDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Daily Records List (from Stitch)
            const Text(
              'Log Presensi Harian',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: WartegTheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ...records.map((rec) {
              final isSuccess = rec['status_type'] == 'success';
              final isWarning = rec['status_type'] == 'warning';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                        Text(
                          rec['date_display'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? WartegTheme.successContainer
                                : isWarning
                                ? WartegTheme.warningContainer
                                : WartegTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rec['status_badge'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSuccess
                                  ? const Color(0xFF065F46)
                                  : isWarning
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.login,
                                size: 16,
                                color: WartegTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: WartegTheme.outline,
                                    ),
                                  ),
                                  Text(
                                    rec['clock_in'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 16,
                                color: WartegTheme.secondary,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pulang',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: WartegTheme.outline,
                                    ),
                                  ),
                                  Text(
                                    rec['clock_out'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timelapse,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Durasi',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: WartegTheme.outline,
                                      ),
                                    ),
                                    Text(
                                      rec['work_duration'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: WartegTheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rec['location'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: WartegTheme.outline,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.face,
                              size: 14,
                              color: WartegTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${rec['face_match_percent']}% Match',
                              style: const TextStyle(
                                fontSize: 11,
                                color: WartegTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
