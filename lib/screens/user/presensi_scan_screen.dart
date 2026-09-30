import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../services/warteg_data_service.dart';
import '../../services/auth_service.dart';
import '../../theme/warteg_theme.dart';
import 'registrasi_wajah_modal.dart';

class PresensiScanScreen extends StatefulWidget {
  final VoidCallback onAttendanceSuccess;
  final bool initialClockInMode;

  const PresensiScanScreen({
    super.key,
    required this.onAttendanceSuccess,
    this.initialClockInMode = true,
  });

  @override
  State<PresensiScanScreen> createState() => _PresensiScanScreenState();
}

class _PresensiScanScreenState extends State<PresensiScanScreen> {
  late bool isClockInMode;
  bool isProcessing = false;
  Uint8List? _capturedImageBytes;

  Position? _currentPosition;
  double? _distanceToOffice;
  bool _isInRange = false;
  bool _isGpsLoading = true;
  String? _gpsError;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    isClockInMode = widget.initialClockInMode;
    _initRealtimeGps();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PresensiScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialClockInMode != widget.initialClockInMode) {
      setState(() {
        isClockInMode = widget.initialClockInMode;
      });
    }
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
            _gpsError = 'Izin lokasi ditolak';
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

  /// Fungsi untuk mengompresi byte foto menjadi lebih kecil (resize max width 480px, JPEG quality 60%)
  Future<Uint8List> _compressPhoto(Uint8List rawBytes) async {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      // Resize jika dimensi foto terlalu besar agar payload ringan
      final resized = (decoded.width > 480 || decoded.height > 640)
          ? img.copyResize(decoded, width: 480)
          : decoded;

      // Kompres ke format JPEG dengan kualitas 60%
      final compressed = img.encodeJpg(resized, quality: 60);
      return Uint8List.fromList(compressed);
    } catch (_) {
      return rawBytes;
    }
  }

  /// Ambil foto wajah murni HANYA dari kamera depan, lalu kompres dan kirim ke backend
  Future<void> _takePhotoAndExecuteAttendance() async {
    final service = WartegDataService();
    final user = service.currentUser;
    final schedules = user['schedules'];

    final todayName = _getTodayDayName();
    final todaySchedule = _getTodaySchedule(schedules);

    int? scheduleId = todaySchedule != null
        ? todaySchedule['id'] as int?
        : null;

    // Fallback jika belum ada jadwal yang pas untuk hari ini, gunakan jadwal pertama yang tersedia
    if (scheduleId == null && schedules is List && schedules.isNotEmpty) {
      final first = schedules.first;
      if (first is Map && first['id'] != null) {
        scheduleId = first['id'] as int?;
      }
    }

    if (scheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jadwal kerja untuk hari $todayName tidak ditemukan. Pastikan jadwal telah diatur oleh admin.',
          ),
          backgroundColor: WartegTheme.error,
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      // Khusus kamera saja (tidak diizinkan dari galeri)
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );

      if (photo == null) return;

      final rawBytes = await photo.readAsBytes();

      // Kompres foto sebelum dikirim ke API
      final compressedBytes = await _compressPhoto(rawBytes);

      setState(() {
        _capturedImageBytes = compressedBytes;
      });

      final base64Image =
          'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
      await _sendAttendanceToApi(
        scheduleId: scheduleId,
        todaySchedule: todaySchedule,
        photoBase64: base64Image,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kamera tidak dapat diakses ($e). Pastikan izin kamera aktif.',
          ),
          backgroundColor: WartegTheme.error,
        ),
      );
    }
  }

  Future<void> _sendAttendanceToApi({
    required int scheduleId,
    required Map<String, dynamic>? todaySchedule,
    required String photoBase64,
  }) async {
    setState(() => isProcessing = true);

    final service = WartegDataService();
    final authService = AuthService();
    final todayName = _getTodayDayName();

    final result = await authService.submitAttendance(
      scheduleId: scheduleId,
      attendanceType: isClockInMode ? 'masuk' : 'pulang',
      photoBase64: photoBase64,
      latitude: _currentPosition?.latitude ?? -6.2088,
      longitude: _currentPosition?.longitude ?? 106.8456,
      notes: 'Presensi selfie AI dari kamera ($todayName)',
    );

    if (!mounted) return;
    setState(() => isProcessing = false);

    if (result.isSuccess) {
      final resData = result.user ?? {};
      final serverTime = (resData['time'] ?? '').toString();
      final displayTime = serverTime.length >= 5
          ? '${serverTime.substring(0, 5)} WIB'
          : '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB';

      service.recordAttendance(isClockIn: isClockInMode, time: displayTime);

      final shiftTitle = todaySchedule != null
          ? (todaySchedule['shift_name'] ?? 'Shift $todayName')
          : 'Shift Warteg (ID: $scheduleId)';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: WartegTheme.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: WartegTheme.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isClockInMode
                    ? 'Absen Masuk Berhasil!'
                    : 'Absen Pulang Berhasil!',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tersimpan di Server Backend Warteg\n$displayTime • $shiftTitle\nStatus: ${resData['status'] ?? 'sukses'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: WartegTheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onAttendanceSuccess();
                  },
                  child: const Text('Kembali ke Beranda'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: WartegTheme.error),
              SizedBox(width: 8),
              Text(
                'Presensi Gagal',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            result.errorMessage ?? 'Gagal memproses presensi ke backend API.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final user = service.currentUser;
    final todaySchedule = _getTodaySchedule(user['schedules']);
    final todayName = _getTodayDayName();
    final kantor = user['kantor'] as Map<String, dynamic>?;
    final geofence = user['geofence'] as Map<String, dynamic>? ?? {};
    final branchName =
        kantor?['nama_cabang'] ??
        user['office_name'] ??
        'Warteg Kharisma Bahari';
    final officeRadius =
        (kantor?['radius'] as num?)?.toDouble() ??
        (geofence['radius_limit_meters'] as num?)?.toDouble() ??
        50.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Presensi Biometrik Wajah',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.flip_camera_ios_outlined),
        //     tooltip: 'Buka Kamera Depan',
        //     onPressed: isProcessing ? null : _takePhotoAndExecuteAttendance,
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Mode Toggle (Absen Masuk / Absen Pulang)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: WartegTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isClockInMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isClockInMode
                              ? WartegTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login,
                              color: isClockInMode
                                  ? Colors.white
                                  : WartegTheme.outline,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Absen Masuk',
                              style: TextStyle(
                                color: isClockInMode
                                    ? Colors.white
                                    : WartegTheme.outline,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isClockInMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isClockInMode
                              ? WartegTheme.secondary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout,
                              color: !isClockInMode
                                  ? Colors.white
                                  : WartegTheme.outline,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Absen Pulang',
                              style: TextStyle(
                                color: !isClockInMode
                                    ? Colors.white
                                    : WartegTheme.outline,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Camera Viewfinder & Face Biometric Scanner Frame (from Stitch design)
            Container(
              width: double.infinity,
              height: 380,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background camera mock with staff portrait OR captured image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _capturedImageBytes != null
                        ? Image.memory(
                            _capturedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.network(
                            user['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=600&q=80',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  ),

                  // Dark overlay vignette
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        radius: 0.9,
                      ),
                    ),
                  ),

                  // Biometric Oval Guide (from Stitch)
                  Container(
                    width: 220,
                    height: 290,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(110),
                      border: Border.all(
                        color: WartegTheme.primaryContainer,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: WartegTheme.primaryContainer.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Top Status Pill
                  Positioned(
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            color: WartegTheme.primaryContainer,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            todaySchedule != null
                                ? 'Jadwal Hari Ini: ${todaySchedule['day']}'
                                : 'Hari: $todayName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Detection Metrics inside Camera View
                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.face,
                            color: WartegTheme.primaryContainer,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _capturedImageBytes != null
                                ? 'Foto Terkompresi'
                                : 'Kamera Siap',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.amberAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Cahaya Cukup',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isProcessing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: WartegTheme.primaryContainer,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Mengirim Presensi ke Server...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Geolocation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _gpsError != null
                          ? WartegTheme.errorContainer.withValues(alpha: 0.5)
                          : (_isGpsLoading
                                ? WartegTheme.surfaceContainerLow
                                : (_isInRange
                                      ? WartegTheme.successContainer.withValues(
                                          alpha: 0.5,
                                        )
                                      : WartegTheme.errorContainer.withValues(
                                          alpha: 0.5,
                                        ))),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pin_drop,
                      color: _gpsError != null
                          ? WartegTheme.error
                          : (_isGpsLoading
                                ? WartegTheme.outline
                                : (_isInRange
                                      ? WartegTheme.primary
                                      : WartegTheme.error)),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verifikasi Lokasi Kerja',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _gpsError != null
                              ? _gpsError!
                              : (_isGpsLoading
                                    ? 'Mendeteksi posisi GPS...'
                                    : (_distanceToOffice != null
                                          ? '${_distanceToOffice! >= 1000 ? "${(_distanceToOffice! / 1000).toStringAsFixed(1)} km" : "${_distanceToOffice!.toInt()}m"} dari $branchName (Radius Maks ${officeRadius.toInt()}m)'
                                          : 'Menghitung jarak ke kantor...')),
                          style: TextStyle(
                            fontSize: 11,
                            color: _gpsError != null
                                ? WartegTheme.error
                                : WartegTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _gpsError != null
                          ? WartegTheme.errorContainer
                          : (_isGpsLoading
                                ? WartegTheme.surfaceContainerLow
                                : (_isInRange
                                      ? WartegTheme.successContainer
                                      : WartegTheme.errorContainer)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _isGpsLoading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _gpsError != null
                                ? 'Error'
                                : (_isInRange ? 'Akurat' : 'Luar Radius'),
                            style: TextStyle(
                              color: _gpsError != null
                                  ? WartegTheme.error
                                  : (_isInRange
                                        ? const Color(0xFF065F46)
                                        : WartegTheme.error),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Main Trigger Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClockInMode
                      ? WartegTheme.primary
                      : WartegTheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isProcessing ? null : _takePhotoAndExecuteAttendance,
                icon: const Icon(Icons.photo_camera, size: 22),
                label: Text(
                  isClockInMode
                      ? 'Ambil Foto & Absen Masuk'
                      : 'Ambil Foto & Absen Pulang',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Re-register face biometrics link
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (ctx) => const RegistrasiWajahModal(),
                );
              },
              icon: const Icon(
                Icons.face_retouching_natural,
                size: 18,
                color: WartegTheme.primary,
              ),
              label: const Text(
                'Daftarkan Ulang Wajah Biometrik',
                style: TextStyle(
                  color: WartegTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
