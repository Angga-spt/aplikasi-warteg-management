import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/warteg_data_service.dart';
import '../../services/auth_service.dart';
import '../../theme/warteg_theme.dart';

class UserDashboardScreen extends StatefulWidget {
  final void Function({bool isClockIn}) onNavigateToPresensi;
  final VoidCallback? onLogout;

  const UserDashboardScreen({
    super.key,
    required this.onNavigateToPresensi,
    this.onLogout,
  });

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _isLoadingUser = false;
  String? _apiError;
  Timer? _clockTimer;
  String _currentTimeDisplay = '';

  // GPS & Radius Realtime
  Position? _currentPosition;
  double? _distanceToOffice;
  bool _isInRange = false;
  bool _isGpsLoading = true;
  String? _gpsError;
  StreamSubscription<Position>? _positionStream;

  // Data Absensi Hari Ini dari /api/attendances/today
  List<Map<String, dynamic>> _todayAttendances = [];

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateClock();
      }
    });
    _fetchUserDetail();
    _fetchTodayAttendance();
    _initRealtimeGps();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initRealtimeGps() async {
    setState(() {
      _isGpsLoading = true;
      _gpsError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isGpsLoading = false;
          _gpsError = 'GPS tidak aktif di perangkat';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isGpsLoading = false;
            _gpsError = 'Izin akses lokasi ditolak';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isGpsLoading = false;
          _gpsError = 'Izin lokasi ditolak permanen';
        });
        return;
      }

      try {
        final initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _updatePosition(initialPos);
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _updatePosition(lastKnown);
        }
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      );

      _positionStream?.cancel();
      _positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
                (Position position) {
                  _updatePosition(position);
                },
                onError: (e) {
                  if (mounted) {
                    setState(() {
                      _gpsError = 'Koneksi GPS terputus';
                    });
                  }
                },
              );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGpsLoading = false;
          _gpsError = 'Gagal mengakses GPS';
        });
      }
    }
  }

  void _updatePosition(Position position) {
    if (!mounted) return;

    final user = WartegDataService().currentUser;
    final kantor = user['kantor'] as Map<String, dynamic>?;

    double officeLat = -6.2088;
    double officeLng = 106.8456;
    double officeRadius = 50.0;

    if (kantor != null) {
      if (kantor['latitude'] != null) {
        officeLat = (kantor['latitude'] as num).toDouble();
      }
      if (kantor['longitude'] != null) {
        officeLng = (kantor['longitude'] as num).toDouble();
      }
      if (kantor['radius'] != null) {
        officeRadius = (kantor['radius'] as num).toDouble();
      }
    } else {
      final geofence = user['geofence'] as Map<String, dynamic>? ?? {};
      if (geofence['radius_limit_meters'] != null) {
        officeRadius = (geofence['radius_limit_meters'] as num).toDouble();
      }
    }

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );

    setState(() {
      _currentPosition = position;
      _distanceToOffice = distance;
      _isInRange = distance <= officeRadius;
      _isGpsLoading = false;
      _gpsError = null;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    setState(() {
      _currentTimeDisplay = '$h:$m:$s WIB';
    });
  }

  String _getTodayDayName() {
    switch (DateTime.now().weekday) {
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

  Map<String, dynamic>? _getTodaySchedule(dynamic schedules) {
    if (schedules is! List || schedules.isEmpty) return null;
    final today = _getTodayDayName().toLowerCase().trim();
    for (final item in schedules) {
      if (item is Map) {
        final day = (item['day'] ?? '').toString().toLowerCase().trim();
        if (day == today) {
          return Map<String, dynamic>.from(item);
        }
      }
    }
    return null;
  }

  Future<void> _fetchTodayAttendance() async {
    final token = WartegDataService().authToken;
    if (token == null || token.isEmpty) return;

    final result = await AuthService().getTodayAttendance();
    if (!mounted) return;

    setState(() {
      _todayAttendances = result;
    });
  }

  String _formatAttendanceTime(dynamic timeVal, String fallback) {
    if (timeVal == null) return fallback;
    final s = timeVal.toString().trim();
    if (s.isEmpty || s == '-') return fallback;
    if (s.length >= 5) {
      return '${s.substring(0, 5)} WIB';
    }
    return '$s WIB';
  }

  Future<void> _fetchUserDetail() async {
    final token = WartegDataService().authToken;
    if (token == null || token.isEmpty) return;

    setState(() {
      _isLoadingUser = true;
      _apiError = null;
    });

    final result = await AuthService().getCurrentUser();
    if (!mounted) return;

    setState(() {
      _isLoadingUser = false;
      if (result.isSuccess && result.user != null) {
        WartegDataService().setLoggedInUser(result.user!, token);
        if (_currentPosition != null) {
          _updatePosition(_currentPosition!);
        }
      } else {
        _apiError = result.errorMessage;
      }
    });

    _fetchTodayAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final user = service.currentUser;
    final shift = user['shift_today'] as Map<String, dynamic>? ?? {};
    final geofence = user['geofence'] as Map<String, dynamic>? ?? {};

    // Ambil jadwal hari ini dari user['schedules']
    final todayName = _getTodayDayName();
    final todaySchedule = _getTodaySchedule(user['schedules']);
    final hasTodaySchedule = todaySchedule != null;

    final shiftName = hasTodaySchedule
        ? (todaySchedule['shift_name'] ?? 'Shift $todayName')
        : 'Tidak Ada Shift Hari Ini ($todayName)';

    String clockInFormatted = '-';
    String clockOutFormatted = '-';
    String periodDisplay = '';

    if (hasTodaySchedule) {
      final inRaw = (todaySchedule['clock_in'] ?? '').toString();
      final outRaw = (todaySchedule['clock_out'] ?? '').toString();
      clockInFormatted = inRaw.length >= 5 ? inRaw.substring(0, 5) : inRaw;
      clockOutFormatted = outRaw.length >= 5 ? outRaw.substring(0, 5) : outRaw;
      periodDisplay = '$clockInFormatted - $clockOutFormatted WIB';
    } else {
      periodDisplay = 'Hari $todayName tidak ada jadwal kerja';
    }

    final notes = hasTodaySchedule
        ? (todaySchedule['notes'] ?? '').toString()
        : '';
    final subTitleDisplay = notes.isNotEmpty
        ? '$periodDisplay • $notes'
        : periodDisplay;

    // Cari data absen masuk dan pulang hari ini dari API /api/attendances/today
    Map<String, dynamic>? todayMasuk;
    Map<String, dynamic>? todayPulang;

    for (final att in _todayAttendances) {
      final type = (att['attendance_type'] ?? '').toString().toLowerCase();
      if (type == 'masuk') {
        todayMasuk = att;
      } else if (type == 'pulang') {
        todayPulang = att;
      }
    }

    final hasClockIn = todayMasuk != null;
    final hasClockOut = todayPulang != null;
    final isFullyPresent = hasClockIn && hasClockOut;

    // Tentukan status presensi untuk badge
    final String attendanceStatusText;
    final Color statusBadgeBgColor;
    final Color statusBadgeTextColor;

    if (isFullyPresent) {
      attendanceStatusText = 'Hadir';
      statusBadgeBgColor = WartegTheme.successContainer;
      statusBadgeTextColor = const Color(0xFF065F46);
    } else if (hasClockIn) {
      attendanceStatusText = 'Sudah Absen Masuk';
      statusBadgeBgColor = WartegTheme.successContainer;
      statusBadgeTextColor = const Color(0xFF065F46);
    } else if (hasClockOut) {
      attendanceStatusText = 'Sudah Absen Pulang';
      statusBadgeBgColor = WartegTheme.successContainer;
      statusBadgeTextColor = const Color(0xFF065F46);
    } else {
      if (!hasTodaySchedule) {
        attendanceStatusText = 'Libur Hari Ini';
        statusBadgeBgColor = Colors.white24;
        statusBadgeTextColor = Colors.white;
      } else {
        attendanceStatusText = 'Belum Absen Masuk';
        statusBadgeBgColor = const Color(0xFFFD761A);
        statusBadgeTextColor = Colors.white;
      }
    }

    // Ambil jam masuk dan jam pulang aktual dari field time attendance hari ini
    final String masukDisplayTime = todayMasuk != null
        ? _formatAttendanceTime(todayMasuk['time'], '-')
        : (hasTodaySchedule
              ? '$clockInFormatted WIB'
              : (shift['clock_in_target'] ?? '-'));

    final String pulangDisplayTime = todayPulang != null
        ? _formatAttendanceTime(todayPulang['time'], '-')
        : (hasTodaySchedule
              ? '$clockOutFormatted WIB'
              : (shift['clock_out_target'] ?? '-'));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.fromLTRB(20, 0, 0, 0),
              decoration: BoxDecoration(
                color: WartegTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.soup_kitchen,
                color: WartegTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Warteg Mobile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: WartegTheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user['kantor']?['nama_cabang'] ?? '',
                    style: const TextStyle(
                      fontSize: 11,
                      color: WartegTheme.outline,
                      fontWeight: FontWeight.w500,
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
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, size: 26),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: WartegTheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada notifikasi baru.')),
              );
            },
          ),
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(
                Icons.logout,
                size: 22,
                color: WartegTheme.outline,
              ),
              tooltip: 'Keluar Mode Staf',
              onPressed: widget.onLogout,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await service.init();
          await _fetchUserDetail();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Card
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      user['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Halo, ${user['full_name'] ?? ''}!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: WartegTheme.onSurface,
                              ),
                            ),
                            if (_isLoadingUser) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (user['username'] != null &&
                            user['username'].toString().isNotEmpty)
                          Text(
                            user['username'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WartegTheme.outline,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: WartegTheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user['role'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: WartegTheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            Text(
                              'NIK: ${user['nik'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: WartegTheme.outline,
                              ),
                            ),
                            if (user['email'] != null)
                              Text(
                                '• ${user['email']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: WartegTheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_apiError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: WartegTheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: WartegTheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _apiError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: WartegTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Hero Attendance Card (from Stitch)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006C4A), Color(0xFF004D34)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: WartegTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentTimeDisplay.isNotEmpty
                                  ? _currentTimeDisplay
                                  : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBadgeBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            attendanceStatusText,
                            style: TextStyle(
                              color: statusBadgeTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      shiftName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$subTitleDisplay • ${isFullyPresent ? 'Presensi hari ini selesai' : (hasClockIn ? 'Menunggu absen pulang' : (hasTodaySchedule ? 'Gerbang absen dibuka' : 'Gerbang absen ditutup'))}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Geofence status container
                    _buildGeofenceCard(user, geofence),
                    const SizedBox(height: 18),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: isFullyPresent
                              ? const Color(0xFF065F46)
                              : WartegTheme.primary,
                          disabledBackgroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF065F46),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isFullyPresent
                            ? null
                            : () {
                                // Jika sudah absen masuk (Presensi Pulang Shift), arahkan langsung ke tab Absen Pulang (isClockIn: false)
                                final targetIsClockIn = !hasClockIn;
                                widget.onNavigateToPresensi(
                                  isClockIn: targetIsClockIn,
                                );
                              },
                        icon: Icon(
                          isFullyPresent
                              ? Icons.check_circle_outline
                              : (hasClockIn
                                    ? Icons.logout
                                    : Icons.qr_code_scanner),
                          size: 20,
                        ),
                        label: Text(
                          isFullyPresent
                              ? 'Presensi Hari Ini Selesai (Hadir)'
                              : (hasClockIn
                                    ? 'Presensi Pulang Shift'
                                    : 'Lakukan Presensi Sekarang'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ringkasan Hari Ini Section
              const Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: WartegTheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Jam Masuk',
                      value: masukDisplayTime,
                      icon: Icons.login,
                      iconColor: WartegTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Jam Pulang',
                      value: pulangDisplayTime,
                      icon: Icons.logout,
                      iconColor: WartegTheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Upah Harian',
                      value: 'Rp 120rb',
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF0058BE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeofenceCard(
    Map<String, dynamic> user,
    Map<String, dynamic> geofence,
  ) {
    final kantor = user['kantor'] as Map<String, dynamic>?;
    final officeName =
        kantor?['nama_cabang'] ?? user['branch_name'] ?? 'Outlet Warteg';
    final officeRadius = kantor?['radius'] != null
        ? (kantor!['radius'] as num).toDouble()
        : (geofence['radius_limit_meters'] != null
              ? (geofence['radius_limit_meters'] as num).toDouble()
              : 5.0);

    String radiusTitle;
    String radiusSubtitle;
    String statusBadgeText;
    Color geofenceIconBg;
    Color geofenceIconColor;
    Color geofenceBadgeBg;
    Color geofenceBadgeTextColor;

    if (_gpsError != null) {
      radiusTitle = 'GPS Tidak Aktif / Ditolak';
      radiusSubtitle = _gpsError!;
      statusBadgeText = 'GPS Off';
      geofenceIconBg = const Color(0xFFFFD8D8);
      geofenceIconColor = Colors.red.shade700;
      geofenceBadgeBg = const Color(0xFFFFD8D8);
      geofenceBadgeTextColor = Colors.red.shade900;
    } else if (_isGpsLoading && _currentPosition == null) {
      radiusTitle = 'Mendeteksi Lokasi GPS...';
      radiusSubtitle = 'Menghubungkan ke satelit GPS perangkat';
      statusBadgeText = 'Mencari...';
      geofenceIconBg = Colors.white.withValues(alpha: 0.2);
      geofenceIconColor = Colors.white;
      geofenceBadgeBg = Colors.white.withValues(alpha: 0.2);
      geofenceBadgeTextColor = Colors.white;
    } else if (_distanceToOffice != null) {
      final distStr = _formatDistance(_distanceToOffice!);
      final radStr = _formatDistance(officeRadius);

      if (_isInRange) {
        radiusTitle = 'Radius Terverifikasi Aman';
        radiusSubtitle = '$distStr dari outlet $officeName (Maks $radStr)';
        statusBadgeText = 'In-Range';
        geofenceIconBg = WartegTheme.primaryContainer;
        geofenceIconColor = WartegTheme.onPrimaryContainer;
        geofenceBadgeBg = WartegTheme.primaryContainer;
        geofenceBadgeTextColor = WartegTheme.onPrimaryContainer;
      } else {
        radiusTitle = 'Di Luar Radius Kantor';
        radiusSubtitle = '$distStr dari outlet $officeName (Maks $radStr)';
        statusBadgeText = 'Luar Radius';
        geofenceIconBg = const Color(0xFFFFD8D8);
        geofenceIconColor = Colors.red.shade700;
        geofenceBadgeBg = const Color(0xFFFFD8D8);
        geofenceBadgeTextColor = Colors.red.shade900;
      }
    } else {
      radiusTitle = 'Radius Terverifikasi Aman';
      radiusSubtitle = geofence['status_detail'] ?? '35m dari outlet Kemang';
      statusBadgeText = geofence['status_label'] ?? 'In-Range';
      geofenceIconBg = WartegTheme.primaryContainer;
      geofenceIconColor = WartegTheme.onPrimaryContainer;
      geofenceBadgeBg = WartegTheme.primaryContainer;
      geofenceBadgeTextColor = WartegTheme.onPrimaryContainer;
    }

    return InkWell(
      onTap: _initRealtimeGps,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: geofenceIconBg,
                shape: BoxShape.circle,
              ),
              child: _isGpsLoading && _currentPosition == null
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.location_on, color: geofenceIconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    radiusTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    radiusSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: geofenceBadgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusBadgeText,
                style: TextStyle(
                  color: geofenceBadgeTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: WartegTheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: WartegTheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
