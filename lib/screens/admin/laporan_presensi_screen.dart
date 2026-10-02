import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/warteg_theme.dart';

class LaporanPresensiScreen extends StatefulWidget {
  const LaporanPresensiScreen({super.key});

  @override
  State<LaporanPresensiScreen> createState() => _LaporanPresensiScreenState();
}

class _LaporanPresensiScreenState extends State<LaporanPresensiScreen> {
  final _authService = AuthService();

  List<Map<String, dynamic>> _attendances = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  // Filter parameters for /api/attendances
  DateTime? _selectedDate;
  String _selectedAttendanceType = 'semua'; // 'semua', 'masuk', 'pulang'
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String? _formatDateParam(DateTime? date) {
    if (date == null) return null;
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final dateStr = _formatDateParam(_selectedDate);

      final results = await Future.wait([
        _authService.getAttendancesList(
          date: dateStr,
          attendanceType: _selectedAttendanceType,
          userId: _selectedUserId,
          skip: 0,
          limit: 100,
        ),
        _authService.getSchedulesList(
          date: dateStr,
          userId: _selectedUserId,
          skip: 0,
          limit: 100,
        ),
        _authService.getUsersList(excludeAdmin: true),
      ]);

      if (!mounted) return;

      setState(() {
        _attendances = results[0];
        _schedules = results[1];
        _users = results[2];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: WartegTheme.primary,
              onPrimary: Colors.white,
              onSurface: WartegTheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAllData();
    }
  }

  void _showModalTambahJadwal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ModalFormJadwal(
        users: _users,
        onSuccess: () {
          _loadAllData();
        },
      ),
    );
  }

  void _showModalEditJadwal(Map<String, dynamic> sched) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ModalFormJadwal(
        users: _users,
        initialSchedule: sched,
        onSuccess: () {
          _loadAllData();
        },
      ),
    );
  }

  Future<void> _handleDeleteSchedule(Map<String, dynamic> sched) async {
    final scheduleId = sched['id'] as int?;
    if (scheduleId == null) return;

    final userName =
        sched['user']?['full_name'] ?? sched['user']?['username'] ?? 'Karyawan';
    final day = sched['day'] ?? '-';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: WartegTheme.error),
            SizedBox(width: 8),
            Text(
              'Hapus Jadwal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus jadwal $day untuk $userName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WartegTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _authService.deleteSchedule(scheduleId: scheduleId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal kerja berhasil dihapus.'),
          backgroundColor: WartegTheme.primary,
        ),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus jadwal kerja.'),
          backgroundColor: WartegTheme.error,
        ),
      );
    }
  }

  void _showPhotoPreview(String photoUrl, String userName, String time) {
    final cleanBaseUrl = _authService.backendUrl.endsWith('/')
        ? _authService.backendUrl.substring(
            0,
            _authService.backendUrl.length - 1,
          )
        : _authService.backendUrl;
    final fullUrl = '$cleanBaseUrl$photoUrl';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 280,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: WartegTheme.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 240,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gagal memuat foto selfie',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Waktu Absensi: $time',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WartegTheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Laporan Presensi & Jadwal',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Segarkan Data',
              onPressed: _loadAllData,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: WartegTheme.primary,
            indicatorWeight: 3,
            labelColor: WartegTheme.primary,
            unselectedLabelColor: WartegTheme.outline,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: [
              Tab(
                icon: Icon(Icons.co_present_outlined, size: 20),
                text: 'Presensi Shift',
              ),
              Tab(
                icon: Icon(Icons.calendar_month_outlined, size: 20),
                text: 'Jadwal Kerja',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: WartegTheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_task),
          label: const Text(
            'Buat Jadwal',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: _showModalTambahJadwal,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: WartegTheme.primary),
              )
            : TabBarView(children: [_buildPresensiTab(), _buildJadwalTab()]),
      ),
    );
  }

  Widget _buildPresensiTab() {
    // Group attendances by shift
    final morningAttendances = <Map<String, dynamic>>[];
    final eveningAttendances = <Map<String, dynamic>>[];
    final otherAttendances = <Map<String, dynamic>>[];

    for (final att in _attendances) {
      final schedule = att['schedule'] as Map<String, dynamic>?;
      final shiftName = (schedule?['shift_name'] as String? ?? '')
          .toLowerCase();
      final timeStr = att['time'] as String? ?? '';
      int hour = -1;
      if (timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.isNotEmpty) hour = int.tryParse(parts[0]) ?? -1;
      }

      if (shiftName.contains('pagi') || (hour >= 6 && hour < 15)) {
        morningAttendances.add(att);
      } else if (shiftName.contains('sore') ||
          shiftName.contains('malam') ||
          (hour >= 15 && hour <= 23)) {
        eveningAttendances.add(att);
      } else {
        otherAttendances.add(att);
      }
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Bar Container
            _buildFilterBar(),
            const SizedBox(height: 18),

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
                  '${morningAttendances.length} Catatan',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WartegTheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (morningAttendances.isNotEmpty)
              ...morningAttendances.map((att) => _buildAttendanceRow(att))
            else
              _buildEmptyShiftBox('Belum ada data presensi untuk Shift Pagi.'),

            const SizedBox(height: 24),

            // Shift Sore & Malam Section
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
                  '${eveningAttendances.length} Catatan',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WartegTheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (eveningAttendances.isNotEmpty)
              ...eveningAttendances.map((att) => _buildAttendanceRow(att))
            else
              _buildEmptyShiftBox(
                'Belum ada data presensi untuk Shift Sore / Malam.',
              ),

            if (otherAttendances.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.more_time,
                    color: WartegTheme.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Shift Fleksibel / Lainnya',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${otherAttendances.length} Catatan',
                    style: const TextStyle(
                      fontSize: 11,
                      color: WartegTheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...otherAttendances.map((att) => _buildAttendanceRow(att)),
            ],

            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyShiftBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, color: WartegTheme.outline),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final dateLabel = _selectedDate == null
        ? 'Semua Tanggal'
        : '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month)} ${_selectedDate!.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Date picker button (Expanded 50%)
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: WartegTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 15,
                                color: WartegTheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedDate = null);
                              _loadAllData();
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: WartegTheme.outline,
                            ),
                          )
                        else
                          const Icon(
                            Icons.expand_more,
                            size: 18,
                            color: WartegTheme.outline,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // User / Employee filter dropdown (Expanded 50%)
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: WartegTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedUserId,
                      isExpanded: true,
                      isDense: true,
                      hint: const Row(
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 15,
                            color: WartegTheme.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Semua Kru',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      icon: const Icon(
                        Icons.expand_more,
                        size: 18,
                        color: WartegTheme.outline,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 15,
                                color: WartegTheme.primary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Semua Kru',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._users.map((u) {
                          final id = u['id'] as int;
                          final name =
                              u['full_name'] ?? u['username'] ?? 'User #$id';
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 15,
                                  color: WartegTheme.outline,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      selectedItemBuilder: (context) {
                        return [
                          const Row(
                            children: [
                              Icon(
                                Icons.filter_alt_outlined,
                                size: 15,
                                color: WartegTheme.primary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Semua Kru',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ..._users.map((u) {
                            final name =
                                u['full_name'] ?? u['username'] ?? 'User';
                            return Row(
                              children: [
                                const Icon(
                                  Icons.filter_alt_outlined,
                                  size: 15,
                                  color: WartegTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ];
                      },
                      onChanged: (val) {
                        setState(() => _selectedUserId = val);
                        _loadAllData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Attendance Type Filter Chips (Semua, Masuk, Pulang)
          Row(
            children: [
              const Text(
                'Tipe: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: WartegTheme.outline,
                ),
              ),
              const SizedBox(width: 6),
              _buildTypeChip('semua', 'Semua'),
              const SizedBox(width: 6),
              _buildTypeChip('masuk', 'Absen Masuk'),
              const SizedBox(width: 6),
              _buildTypeChip('pulang', 'Absen Pulang'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String typeKey, String label) {
    final isSelected = _selectedAttendanceType == typeKey;
    return GestureDetector(
      onTap: () {
        if (_selectedAttendanceType == typeKey) return;
        setState(() => _selectedAttendanceType = typeKey);
        _loadAllData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? WartegTheme.primary
              : WartegTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? WartegTheme.primary : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : WartegTheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceRow(Map<String, dynamic> att) {
    final user = att['user'] as Map<String, dynamic>? ?? {};
    final schedule = att['schedule'] as Map<String, dynamic>?;
    final userName = user['full_name'] ?? user['username'] ?? 'Karyawan';
    final userRole = user['role'] ?? 'Kru Warteg';
    final attType = (att['attendance_type'] as String? ?? 'masuk')
        .toLowerCase();
    final isMasuk = attType == 'masuk';
    final timeStr = att['time'] as String? ?? '-';
    final dateStr = att['date'] as String? ?? '';
    final statusStr = (att['status'] as String? ?? 'sukses').toUpperCase();
    final notes = att['notes'] as String?;
    final photoUrl = att['photo_url'] as String?;

    final isSuccess =
        statusStr.contains('SUKSES') || statusStr.contains('HADIR');
    final isLate = statusStr.contains('TERLAMBAT');

    Color badgeBg = WartegTheme.successContainer;
    Color badgeText = const Color(0xFF065F46);
    if (isLate) {
      badgeBg = WartegTheme.warningContainer;
      badgeText = const Color(0xFF92400E);
    } else if (!isSuccess) {
      badgeBg = WartegTheme.errorContainer;
      badgeText = WartegTheme.error;
    }

    final cleanBaseUrl = _authService.backendUrl.endsWith('/')
        ? _authService.backendUrl.substring(
            0,
            _authService.backendUrl.length - 1,
          )
        : _authService.backendUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo selfie thumbnail or Avatar
          GestureDetector(
            onTap: () {
              if (photoUrl != null && photoUrl.isNotEmpty) {
                _showPhotoPreview(photoUrl, userName, timeStr);
              }
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isMasuk
                      ? WartegTheme.primary.withValues(alpha: 0.1)
                      : const Color(0xFF6366F1).withValues(alpha: 0.1),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage('$cleanBaseUrl$photoUrl')
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(
                          isMasuk ? Icons.login : Icons.logout,
                          color: isMasuk
                              ? WartegTheme.primary
                              : const Color(0xFF6366F1),
                          size: 20,
                        )
                      : null,
                ),
                if (photoUrl != null && photoUrl.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 10,
                        color: WartegTheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // User details & Notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMasuk
                            ? WartegTheme.primaryContainer.withValues(
                                alpha: 0.5,
                              )
                            : const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isMasuk ? 'MASUK' : 'PULANG',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isMasuk
                              ? WartegTheme.primary
                              : const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  schedule != null
                      ? '$userRole • ${schedule['shift_name'] ?? 'Jadwal'} (${schedule['clock_in'] ?? ''} - ${schedule['clock_out'] ?? ''})'
                      : '$userRole • Presensi Mandiri',
                  style: const TextStyle(
                    fontSize: 11,
                    color: WartegTheme.outline,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: $notes',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: WartegTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Time and status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusStr,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: WartegTheme.onSurface,
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 9,
                    color: WartegTheme.outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJadwalTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: _schedules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 56,
                      color: WartegTheme.outline.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum Ada Jadwal Kerja',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ketuk tombol "Buat Jadwal" di bawah untuk mendaftarkan jadwal kerja staf.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: WartegTheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final sched = _schedules[index];
                final user = sched['user'] as Map<String, dynamic>? ?? {};
                final userName =
                    user['full_name'] ?? user['username'] ?? 'Karyawan';
                final day = sched['day'] ?? '-';
                final shiftName = sched['shift_name'] ?? 'Shift Kerja';
                final clockIn = (sched['clock_in'] as String? ?? '00:00:00')
                    .substring(0, 5);
                final clockOut = (sched['clock_out'] as String? ?? '00:00:00')
                    .substring(0, 5);
                final specificDate = sched['date'] as String?;
                final notes = sched['notes'] as String?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: WartegTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: WartegTheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              day,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: WartegTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: WartegTheme.secondary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    shiftName,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: WartegTheme.secondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$clockIn - $clockOut WIB',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: WartegTheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            if (specificDate != null &&
                                specificDate.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tanggal Khusus: $specificDate',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: WartegTheme.outline,
                                ),
                              ),
                            ],
                            if (notes != null && notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Catatan: $notes',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: WartegTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: WartegTheme.primary,
                              size: 18,
                            ),
                            tooltip: 'Edit Jadwal',
                            onPressed: () => _showModalEditJadwal(sched),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: WartegTheme.error,
                              size: 18,
                            ),
                            tooltip: 'Hapus Jadwal',
                            onPressed: () => _handleDeleteSchedule(sched),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[(month - 1) % 12];
  }
}

class _ModalFormJadwal extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final VoidCallback onSuccess;
  final Map<String, dynamic>? initialSchedule;

  const _ModalFormJadwal({
    required this.users,
    required this.onSuccess,
    this.initialSchedule,
  });

  @override
  State<_ModalFormJadwal> createState() => _ModalFormJadwalState();
}

class _ModalFormJadwalState extends State<_ModalFormJadwal> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool get _isEditing => widget.initialSchedule != null;

  int? _selectedUserId;
  String _selectedDay = 'Senin';
  String _selectedShiftPreset = 'Shift Pagi (07:00 - 15:00)';
  String _customShiftName = 'Shift Pagi';

  TimeOfDay _clockIn = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _clockOut = const TimeOfDay(hour: 15, minute: 0);
  DateTime? _specificDate;

  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.initialSchedule!;
      _selectedUserId = s['user_id'] as int? ?? s['user']?['id'] as int?;
      _selectedDay = s['day'] as String? ?? 'Senin';
      _customShiftName = s['shift_name'] as String? ?? 'Shift Pagi';

      if (_customShiftName.contains('Pagi')) {
        _selectedShiftPreset = 'Shift Pagi (07:00 - 15:00)';
      } else if (_customShiftName.contains('Sore')) {
        _selectedShiftPreset = 'Shift Sore (15:00 - 23:00)';
      } else if (_customShiftName.contains('Malam')) {
        _selectedShiftPreset = 'Shift Malam (23:00 - 07:00)';
      } else {
        _selectedShiftPreset = 'Kustom';
      }

      final cin = s['clock_in'] as String? ?? '07:00:00';
      final cinParts = cin.split(':');
      if (cinParts.length >= 2) {
        _clockIn = TimeOfDay(
          hour: int.tryParse(cinParts[0]) ?? 7,
          minute: int.tryParse(cinParts[1]) ?? 0,
        );
      }

      final cout = s['clock_out'] as String? ?? '15:00:00';
      final coutParts = cout.split(':');
      if (coutParts.length >= 2) {
        _clockOut = TimeOfDay(
          hour: int.tryParse(coutParts[0]) ?? 15,
          minute: int.tryParse(coutParts[1]) ?? 0,
        );
      }

      if (s['date'] != null && s['date'].toString().isNotEmpty) {
        _specificDate = DateTime.tryParse(s['date'].toString());
      }

      _notesController.text = s['notes'] as String? ?? '';
    } else {
      if (widget.users.isNotEmpty) {
        _selectedUserId = widget.users.first['id'] as int?;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onShiftPresetChanged(String preset) {
    setState(() {
      _selectedShiftPreset = preset;
      if (preset == 'Shift Pagi (07:00 - 15:00)') {
        _customShiftName = 'Shift Pagi';
        _clockIn = const TimeOfDay(hour: 7, minute: 0);
        _clockOut = const TimeOfDay(hour: 15, minute: 0);
      } else if (preset == 'Shift Sore (15:00 - 23:00)') {
        _customShiftName = 'Shift Sore';
        _clockIn = const TimeOfDay(hour: 15, minute: 0);
        _clockOut = const TimeOfDay(hour: 23, minute: 0);
      } else if (preset == 'Shift Malam (23:00 - 07:00)') {
        _customShiftName = 'Shift Malam';
        _clockIn = const TimeOfDay(hour: 23, minute: 0);
        _clockOut = const TimeOfDay(hour: 7, minute: 0);
      }
    });
  }

  Future<void> _pickClockInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _clockIn,
    );
    if (picked != null) {
      setState(() => _clockIn = picked);
    }
  }

  Future<void> _pickClockOutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _clockOut,
    );
    if (picked != null) {
      setState(() => _clockOut = picked);
    }
  }

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? now,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _specificDate = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _submitSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      setState(() => _errorMessage = 'Pilih karyawan terlebih dahulu.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final clockInStr = _formatTime(_clockIn);
    final clockOutStr = _formatTime(_clockOut);
    final dateStr = _formatDate(_specificDate);

    final AuthResult result;
    if (_isEditing) {
      final scheduleId = widget.initialSchedule!['id'] as int;
      result = await _authService.updateSchedule(
        scheduleId: scheduleId,
        day: _selectedDay,
        clockIn: clockInStr,
        clockOut: clockOutStr,
        shiftName: _customShiftName.isNotEmpty ? _customShiftName : null,
        date: dateStr,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
    } else {
      result = await _authService.createSchedule(
        userId: _selectedUserId!,
        day: _selectedDay,
        clockIn: clockInStr,
        clockOut: clockOutStr,
        shiftName: _customShiftName.isNotEmpty ? _customShiftName : null,
        date: dateStr,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Jadwal kerja karyawan berhasil diperbarui.'
                : 'Jadwal kerja karyawan berhasil ditambahkan.',
          ),
          backgroundColor: WartegTheme.primary,
        ),
      );
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage =
            result.errorMessage ??
            (_isEditing
                ? 'Gagal memperbarui jadwal kerja.'
                : 'Gagal membuat jadwal kerja.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing
                            ? 'Edit Jadwal Kerja Kru'
                            : 'Buat Jadwal Kerja Kru',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _isEditing
                            ? 'Perbarui shift kru warteg'
                            : 'Jadwalkan shift kru warteg',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WartegTheme.outline,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WartegTheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: WartegTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: WartegTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Dropdown / Card Karyawan (user_id)
              Text(
                _isEditing ? 'Karyawan / Staf' : 'Pilih Karyawan / Staf *',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (_isEditing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: WartegTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 18,
                        color: WartegTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.initialSchedule!['user']?['full_name'] ??
                            widget.initialSchedule!['user']?['username'] ??
                            'User #${widget.initialSchedule!['user_id']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedUserId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: widget.users.map((u) {
                    final id = u['id'] as int;
                    final name = u['full_name'] ?? u['username'] ?? 'User #$id';
                    final role = u['role'] ?? 'user';
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text('$name ($role)'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedUserId = val),
                  validator: (val) =>
                      val == null ? 'Wajib memilih karyawan' : null,
                ),
              const SizedBox(height: 14),

              // Dropdown Pilihan Hari Kerja (day)
              const Text(
                'Hari Kerja (Rutin Mingguan) *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedDay,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: _days.map((d) {
                  return DropdownMenuItem(value: d, child: Text(d));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDay = val);
                },
              ),
              const SizedBox(height: 14),

              // Preset Shift & Nama Shift
              const Text(
                'Pilihan Shift *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedShiftPreset,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items:
                    [
                          'Shift Pagi (07:00 - 15:00)',
                          'Shift Sore (15:00 - 23:00)',
                          'Shift Malam (23:00 - 07:00)',
                          'Kustom',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (val) {
                  if (val != null) _onShiftPresetChanged(val);
                },
              ),
              if (_selectedShiftPreset == 'Kustom') ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: _customShiftName,
                  decoration: const InputDecoration(
                    labelText: 'Nama Shift Kustom',
                    hintText: 'Misal: Shift Khusus Weekend',
                  ),
                  onChanged: (val) => _customShiftName = val,
                ),
              ],
              const SizedBox(height: 14),

              // Jam Masuk (clock_in) & Jam Keluar (clock_out)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jam Masuk (clock_in) *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickClockInTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: WartegTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatTime(_clockIn).substring(0, 5),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const Icon(Icons.access_time, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jam Keluar (clock_out) *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickClockOutTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: WartegTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatTime(_clockOut).substring(0, 5),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const Icon(Icons.access_time_filled, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tanggal Spesifik (Opsional, date)
              const Text(
                'Tanggal Khusus (Opsional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickSpecificDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: WartegTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event,
                            size: 18,
                            color: WartegTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _specificDate == null
                                ? 'Berlaku Mingguan Rutin (Kosongkan)'
                                : _formatDate(_specificDate)!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _specificDate == null
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: _specificDate == null
                                  ? WartegTheme.outline
                                  : WartegTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (_specificDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _specificDate = null),
                          child: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Catatan Tambahan (notes)
              const Text(
                'Catatan Jadwal (Opsional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Misal: Shift persiapan lauk utama',
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSchedule,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Perbarui Jadwal Kerja'
                              : 'Simpan Jadwal Kerja',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
