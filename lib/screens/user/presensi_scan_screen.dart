import 'package:flutter/material.dart';
import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';
import 'registrasi_wajah_modal.dart';

class PresensiScanScreen extends StatefulWidget {
  final VoidCallback onAttendanceSuccess;

  const PresensiScanScreen({super.key, required this.onAttendanceSuccess});

  @override
  State<PresensiScanScreen> createState() => _PresensiScanScreenState();
}

class _PresensiScanScreenState extends State<PresensiScanScreen> {
  bool isClockInMode = true;
  bool isProcessing = false;

  void _executeAttendance() async {
    setState(() => isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    WartegDataService().recordAttendance(
      isClockIn: isClockInMode,
      time: timeStr,
    );

    if (!mounted) return;
    setState(() => isProcessing = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              child: const Icon(Icons.check_circle, color: WartegTheme.success, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              isClockInMode ? 'Absen Masuk Berhasil!' : 'Absen Pulang Berhasil!',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Biometrik Wajah 98.4% Terverifikasi\n$timeStr WIB • Warteg Bahari Kemang',
              style: const TextStyle(fontSize: 13, color: WartegTheme.outline),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Presensi Biometrik Wajah',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Beralih ke Kamera Belakang')),
              );
            },
          ),
        ],
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
                          color: isClockInMode ? WartegTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, color: isClockInMode ? Colors.white : WartegTheme.outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Absen Masuk',
                              style: TextStyle(
                                color: isClockInMode ? Colors.white : WartegTheme.outline,
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
                          color: !isClockInMode ? WartegTheme.secondary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: !isClockInMode ? Colors.white : WartegTheme.outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Absen Pulang',
                              style: TextStyle(
                                color: !isClockInMode ? Colors.white : WartegTheme.outline,
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
                  // Background camera mock with staff portrait
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=600&q=80',
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
                          color: WartegTheme.primaryContainer.withValues(alpha: 0.35),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, color: WartegTheme.primaryContainer, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'AI Face Detection Ready',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Detection Metrics inside Camera View
                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.face, color: WartegTheme.primaryContainer, size: 16),
                          SizedBox(width: 6),
                          Text('Wajah 98.4%', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          SizedBox(width: 12),
                          Icon(Icons.wb_sunny_outlined, color: Colors.amberAccent, size: 16),
                          SizedBox(width: 6),
                          Text('Cahaya Cukup', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
                            CircularProgressIndicator(color: WartegTheme.primaryContainer),
                            SizedBox(height: 12),
                            Text(
                              'Memverifikasi Biometrik Wajah...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                    decoration: const BoxDecoration(
                      color: WartegTheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_drop, color: WartegTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verifikasi Lokasi Kerja',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '35m dari Warteg Bahari Kemang (Radius Maks 50m)',
                          style: TextStyle(fontSize: 11, color: WartegTheme.outline),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: WartegTheme.successContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Akurat',
                      style: TextStyle(
                        color: Color(0xFF065F46),
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
                  backgroundColor: isClockInMode ? WartegTheme.primary : WartegTheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isProcessing ? null : _executeAttendance,
                icon: const Icon(Icons.photo_camera, size: 22),
                label: Text(
                  isClockInMode ? 'Ambil Foto & Absen Masuk' : 'Ambil Foto & Absen Pulang',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (ctx) => const RegistrasiWajahModal(),
                );
              },
              icon: const Icon(Icons.face_retouching_natural, size: 18, color: WartegTheme.primary),
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
