import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';

class RiwayatPresensiScreen extends StatefulWidget {
  const RiwayatPresensiScreen({super.key});

  @override
  State<RiwayatPresensiScreen> createState() => _RiwayatPresensiScreenState();
}

class _RiwayatPresensiScreenState extends State<RiwayatPresensiScreen> {
  late DateTime _selectedMonth;
  int _selectedWeekIndex = 0;
  DateTime? _selectedDayDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _apiAttendances = [];
  bool _showAllMonthRecords = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    final weeks = _getWeeksForMonth(_selectedMonth.year, _selectedMonth.month);
    _selectedWeekIndex = _findInitialWeekIndex(weeks, now);
    _fetchAttendances();
  }

  int _findInitialWeekIndex(List<List<DateTime>> weeks, DateTime target) {
    for (int i = 0; i < weeks.length; i++) {
      for (final d in weeks[i]) {
        if (d.year == target.year &&
            d.month == target.month &&
            d.day == target.day) {
          return i;
        }
      }
    }
    return 0;
  }

  Future<void> _fetchAttendances() async {
    setState(() {
      _isLoading = true;
    });

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate =
        '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final result = await AuthService().getMyAttendances(
      startDate: startDate,
      endDate: endDate,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _apiAttendances = result;
    });
  }

  void _onPrevMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      final weeks = _getWeeksForMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      final now = DateTime.now();
      _selectedWeekIndex = _findInitialWeekIndex(weeks, now);
      _selectedDayDate = null;
    });
    _fetchAttendances();
  }

  void _onNextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
      final weeks = _getWeeksForMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      final now = DateTime.now();
      _selectedWeekIndex = _findInitialWeekIndex(weeks, now);
      _selectedDayDate = null;
    });
    _fetchAttendances();
  }

  List<List<DateTime>> _getWeeksForMonth(int year, int month) {
    final totalDays = DateTime(year, month + 1, 0).day;
    final List<List<DateTime>> weeks = [];
    List<DateTime> currentWeek = [];

    for (int day = 1; day <= totalDays; day++) {
      final dt = DateTime(year, month, day);
      currentWeek.add(dt);

      // Minggu berakhir pada hari Minggu (weekday == 7) atau hari terakhir bulan tersebut
      if (dt.weekday == DateTime.sunday || day == totalDays) {
        weeks.add(List.from(currentWeek));
        currentWeek.clear();
      }
    }
    return weeks.isEmpty
        ? [
            [DateTime(year, month, 1)],
          ]
        : weeks;
  }

  String _formatMonthYearIndo(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getShortDayNameIndo(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Sen';
      case DateTime.tuesday:
        return 'Sel';
      case DateTime.wednesday:
        return 'Rab';
      case DateTime.thursday:
        return 'Kam';
      case DateTime.friday:
        return 'Jum';
      case DateTime.saturday:
        return 'Sab';
      case DateTime.sunday:
        return 'Min';
      default:
        return '';
    }
  }

  String _getDayNameIndo(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Senin';
      case DateTime.tuesday:
        return 'Selasa';
      case DateTime.wednesday:
        return 'Rabu';
      case DateTime.thursday:
        return 'Kamis';
      case DateTime.friday:
        return 'Jumat';
      case DateTime.saturday:
        return 'Sabtu';
      case DateTime.sunday:
        return 'Minggu';
      default:
        return '';
    }
  }

  String _formatDateDisplay(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dayName = _getDayNameIndo(dt.weekday);
    return '$dayName, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(dynamic timeVal) {
    if (timeVal == null) return '-';
    final s = timeVal.toString().trim();
    if (s.isEmpty || s == '-') return '-';
    if (s.length >= 5) {
      return '${s.substring(0, 5)} WIB';
    }
    return '$s WIB';
  }

  String _getFullPhotoUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return photoUrl;
    }
    final baseUrl = AuthService().backendUrl.replaceAll(RegExp(r'/$'), '');
    final cleanPath = photoUrl.startsWith('/') ? photoUrl : '/$photoUrl';
    return '$baseUrl$cleanPath';
  }

  void _showPhotoPreview(
    BuildContext context,
    String photoUrl, {
    String title = 'Foto Bukti Presensi',
  }) {
    final fullUrl = _getFullPhotoUrl(photoUrl);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: WartegTheme.primary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Gagal memuat gambar foto presensi',
                      style: TextStyle(color: WartegTheme.outline),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context,
    String? photoUrl, {
    String? label,
    String title = 'Foto Bukti Presensi',
  }) {
    final bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final Widget thumbnailContent = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasPhoto ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
          ),
        ),
        child: hasPhoto
            ? Image.network(
                _getFullPhotoUrl(photoUrl),
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade100,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 14,
                    color: WartegTheme.outline,
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  );
                },
              )
            : const Icon(
                Icons.no_photography_outlined,
                size: 14,
                color: WartegTheme.outline,
              ),
      ),
    );

    final Widget clickableThumbnail = GestureDetector(
      onTap: hasPhoto
          ? () => _showPhotoPreview(context, photoUrl, title: title)
          : null,
      child: thumbnailContent,
    );

    if (label != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          clickableThumbnail,
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: WartegTheme.outline,
            ),
          ),
        ],
      );
    }

    return clickableThumbnail;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _getWeeksForMonth(_selectedMonth.year, _selectedMonth.month);
    if (_selectedWeekIndex >= weeks.length) {
      _selectedWeekIndex = weeks.length - 1;
    }
    final currentWeekDays = weeks[_selectedWeekIndex];

    // Kelompokkan data absensi dari API berdasarkan tanggal
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final att in _apiAttendances) {
      final date = att['date']?.toString() ?? '';
      if (date.isEmpty) continue;
      if (!grouped.containsKey(date)) {
        grouped[date] = {
          'date': date,
          'masuk': null,
          'pulang': null,
          'schedule': att['schedule'],
          'notes': att['notes'],
          'location':
              att['location'] ??
              WartegDataService().currentUser['kantor']?['nama_cabang'] ??
              'Outlet Warteg',
        };
      }
      final type = (att['attendance_type'] ?? '').toString().toLowerCase();
      if (type == 'masuk') {
        grouped[date]!['masuk'] = att;
      } else if (type == 'pulang') {
        grouped[date]!['pulang'] = att;
      }
    }

    final totalDaysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final attendedDates = grouped.keys.toSet();
    final totalHadir = attendedDates.length;
    final totalAbsen = (totalDaysInMonth - totalHadir).clamp(
      0,
      totalDaysInMonth,
    );

    // Kumpulan tanggal pada minggu yang sedang dipilih
    final weekDateStrings = currentWeekDays.map((d) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }).toSet();

    // Filter catatan harian
    List<Map<String, dynamic>> displayedRecords = [];
    if (_selectedDayDate != null) {
      final selectedDateStr =
          '${_selectedDayDate!.year}-${_selectedDayDate!.month.toString().padLeft(2, '0')}-${_selectedDayDate!.day.toString().padLeft(2, '0')}';
      if (grouped.containsKey(selectedDateStr)) {
        displayedRecords = [grouped[selectedDateStr]!];
      } else {
        displayedRecords = [];
      }
    } else if (_showAllMonthRecords) {
      displayedRecords = grouped.values.toList();
    } else {
      displayedRecords = grouped.values
          .where((r) => weekDateStrings.contains(r['date']))
          .toList();
    }

    // Urutkan tanggal terbaru di atas
    displayedRecords.sort(
      (a, b) => b['date'].toString().compareTo(a['date'].toString()),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Presensi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAttendances,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    onPressed: _onPrevMonth,
                    tooltip: 'Bulan Sebelumnya',
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
                        _formatMonthYearIndo(_selectedMonth),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _onNextMonth,
                    tooltip: 'Bulan Selanjutnya',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stat Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Hadir',
                      value: '$totalHadir Hari',
                      color: WartegTheme.primary,
                      bgColor: WartegTheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Absen',
                      value: '$totalAbsen Hari',
                      color: WartegTheme.secondary,
                      bgColor: const Color(0xFFFFEAD8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Weekly Header & Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pekan Ini (Minggu ke-${_selectedWeekIndex + 1})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: WartegTheme.outline,
                    ),
                  ),
                  Text(
                    '${currentWeekDays.length} Hari',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WartegTheme.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Pilihan Minggu dalam Bulan Ini
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(weeks.length, (idx) {
                    final isSelected = idx == _selectedWeekIndex;
                    final weekDays = weeks[idx];
                    final firstDay = weekDays.first.day;
                    final lastDay = weekDays.last.day;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Minggu ${idx + 1} ($firstDay-$lastDay)'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedWeekIndex = idx;
                              _selectedDayDate = null;
                            });
                          }
                        },
                        selectedColor: WartegTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : WartegTheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? WartegTheme.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // Strip Hari untuk Minggu yang Dipilih
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: currentWeekDays.map((day) {
                    final isSelected =
                        _selectedDayDate != null &&
                        _selectedDayDate!.year == day.year &&
                        _selectedDayDate!.month == day.month &&
                        _selectedDayDate!.day == day.day;

                    final dateStr =
                        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final isAttended = attendedDates.contains(dateStr);

                    Color statusDotColor = Colors.transparent;
                    if (isAttended) {
                      statusDotColor = WartegTheme.primary;
                    } else if (day.isBefore(DateTime.now()) &&
                        day.weekday != DateTime.sunday) {
                      statusDotColor = WartegTheme.secondary;
                    } else if (day.weekday == DateTime.sunday) {
                      statusDotColor = Colors.grey.shade400;
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedDayDate = null;
                          } else {
                            _selectedDayDate = day;
                          }
                        });
                      },
                      child: Container(
                        width: 48,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? WartegTheme.primary
                              : Colors.white,
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
                              _getShortDayNameIndo(day.weekday),
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
                              '${day.day}',
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
                                color: isSelected
                                    ? Colors.white
                                    : statusDotColor,
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

              // Daily Records List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedDayDate != null
                          ? 'Log Presensi: ${_formatDateDisplay('${_selectedDayDate!.year}-${_selectedDayDate!.month.toString().padLeft(2, '0')}-${_selectedDayDate!.day.toString().padLeft(2, '0')}')}'
                          : 'Log Presensi Harian',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: WartegTheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedDayDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDayDate = null;
                        });
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showAllMonthRecords = !_showAllMonthRecords;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          _showAllMonthRecords
                              ? 'Pekan Ini'
                              : 'Semua Bulan Ini',
                          style: const TextStyle(
                            fontSize: 12,
                            color: WartegTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (displayedRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 44,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedDayDate != null
                            ? 'Tidak ada data presensi pada tanggal ini'
                            : 'Belum ada presensi pada periode yang dipilih',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: WartegTheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...displayedRecords.map((rec) {
                  final masuk = rec['masuk'] as Map<String, dynamic>?;
                  final pulang = rec['pulang'] as Map<String, dynamic>?;
                  final schedule =
                      rec['schedule'] as Map<String, dynamic>? ??
                      masuk?['schedule'] as Map<String, dynamic>? ??
                      pulang?['schedule'] as Map<String, dynamic>?;

                  final clockIn = masuk != null
                      ? _formatTime(masuk['time'])
                      : '-';
                  final clockOut = pulang != null
                      ? _formatTime(pulang['time'])
                      : '-';

                  final masukPhotoUrl = masuk?['photo_url'] as String?;
                  final pulangPhotoUrl = pulang?['photo_url'] as String?;

                  final isComplete = masuk != null && pulang != null;
                  final statusBadge = isComplete
                      ? 'Selesai Shift'
                      : (masuk != null
                            ? 'Masuk Tepat Waktu'
                            : 'Pulang Selesai');
                  final isSuccess = isComplete || masuk != null;

                  final shiftName = schedule?['shift_name'] ?? 'Shift Kerja';
                  final locationName =
                      rec['location'] ??
                      WartegDataService()
                          .currentUser['kantor']?['nama_cabang'] ??
                      'Warteg Cabang';

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
                              _formatDateDisplay(rec['date'] ?? ''),
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
                                    : WartegTheme.warningContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSuccess
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kolom Masuk
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.login,
                                    size: 16,
                                    color: WartegTheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: WartegTheme.outline,
                                        ),
                                      ),
                                      Text(
                                        clockIn,
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
                            // Kolom Pulang
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.logout,
                                    size: 16,
                                    color: WartegTheme.secondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pulang',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: WartegTheme.outline,
                                        ),
                                      ),
                                      Text(
                                        clockOut,
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
                            // Kolom Foto Masuk & Pulang
                            Expanded(
                              flex: 5,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 16,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Foto (M / P)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: WartegTheme.outline,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          _buildPhotoThumbnail(
                                            context,
                                            masukPhotoUrl,
                                            label: 'Masuk',
                                            title: 'Foto Presensi Masuk',
                                          ),
                                          const SizedBox(width: 6),
                                          _buildPhotoThumbnail(
                                            context,
                                            pulangPhotoUrl,
                                            label: 'Pulang',
                                            title: 'Foto Presensi Pulang',
                                          ),
                                        ],
                                      ),
                                    ],
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
                                  Icons.storefront_outlined,
                                  size: 14,
                                  color: WartegTheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  locationName,
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
                                  Icons.schedule,
                                  size: 14,
                                  color: WartegTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shiftName,
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
