import 'package:flutter/material.dart';
import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';

class ManajemenCabangScreen extends StatefulWidget {
  const ManajemenCabangScreen({super.key});

  @override
  State<ManajemenCabangScreen> createState() => _ManajemenCabangScreenState();
}

class _ManajemenCabangScreenState extends State<ManajemenCabangScreen> {
  int activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final branches = service.branches;

    final selected = branches.isNotEmpty ? branches[activeIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cabang & Geofence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Form Tambah Outlet Baru: Silakan tentukan titik pin GPS warteg.')),
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
            // Header stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daftar Outlet & Perimeter', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    Text('4 Cabang Terdaftar • Radius Rata-rata 50m', style: TextStyle(fontSize: 12, color: WartegTheme.outline)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: WartegTheme.successContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, size: 14, color: WartegTheme.success),
                      SizedBox(width: 4),
                      Text('GPS Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interactive Geofence Map / Radar Simulation (from Stitch)
            if (selected != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront, color: WartegTheme.primaryContainer, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              selected['name'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Radius: ${selected['radius_meters']}m',
                            style: const TextStyle(color: WartegTheme.primaryContainer, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Radar Simulation Graphic
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: WartegTheme.primary.withValues(alpha: 0.3), width: 1.5),
                          ),
                        ),
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: WartegTheme.primary.withValues(alpha: 0.6), width: 2),
                            color: WartegTheme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: WartegTheme.primary,
                          ),
                          child: const Icon(Icons.store, color: Colors.white, size: 28),
                        ),
                        // Staff dots inside radius
                        const Positioned(
                          top: 50,
                          left: 60,
                          child: CircleAvatar(radius: 6, backgroundColor: WartegTheme.primaryContainer),
                        ),
                        const Positioned(
                          bottom: 55,
                          right: 70,
                          child: CircleAvatar(radius: 6, backgroundColor: WartegTheme.primaryContainer),
                        ),
                        const Positioned(
                          bottom: 40,
                          left: 80,
                          child: CircleAvatar(radius: 6, backgroundColor: WartegTheme.primaryContainer),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${selected['active_staff_count']} Staf Bertugas di Radius Ini',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Branch List Cards
            const Text('Pilih Cabang untuk Konfigurasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            ...List.generate(branches.length, (idx) {
              final b = branches[idx];
              final isSel = idx == activeIndex;

              return GestureDetector(
                onTap: () => setState(() => activeIndex = idx),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSel ? WartegTheme.primary : const Color(0xFFE2E8F0),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSel ? WartegTheme.primaryContainer : WartegTheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: isSel ? WartegTheme.onPrimaryContainer : WartegTheme.outline,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(b['address'] ?? '', style: const TextStyle(fontSize: 11, color: WartegTheme.outline)),
                            const SizedBox(height: 4),
                            Text(
                              'Geofence Radius: ${b['radius_meters']}m • ${b['active_staff_count']} Staf',
                              style: const TextStyle(fontSize: 11, color: WartegTheme.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSel ? Icons.check_circle : Icons.tune,
                        color: isSel ? WartegTheme.primary : WartegTheme.outline,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),

            // Adjust Radius Action
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Radius geofence untuk ${selected?['name']} disesuaikan.'),
                      backgroundColor: WartegTheme.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.tune),
                label: const Text('Kalibrasi & Sesuaikan Radius GPS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
