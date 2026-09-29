import 'package:flutter/material.dart';
import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';

class ManajemenKaryawanScreen extends StatefulWidget {
  const ManajemenKaryawanScreen({super.key});

  @override
  State<ManajemenKaryawanScreen> createState() => _ManajemenKaryawanScreenState();
}

class _ManajemenKaryawanScreenState extends State<ManajemenKaryawanScreen> {
  String selectedBranch = 'Semua Cabang';
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final allEmployees = service.employees;

    final filtered = allEmployees.where((emp) {
      final name = (emp['name'] as String? ?? '').toLowerCase();
      final role = (emp['role'] as String? ?? '').toLowerCase();
      final branch = (emp['branch_name'] as String? ?? '').toLowerCase();
      final matchesQuery = searchQuery.isEmpty || name.contains(searchQuery.toLowerCase()) || role.contains(searchQuery.toLowerCase());

      if (selectedBranch == 'Semua Cabang') return matchesQuery;
      return matchesQuery && branch.contains(selectedBranch.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Karyawan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _openAddModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama kru, NIK, atau peran...',
                prefixIcon: const Icon(Icons.search, color: WartegTheme.outline),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Branch Filter Chips (from Stitch)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildFilterChip('Semua Cabang', '24'),
                _buildFilterChip('Kemang', '7'),
                _buildFilterChip('Tebet', '6'),
                _buildFilterChip('Cipete', '6'),
                _buildFilterChip('Senopati', '5'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Count Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menampilkan ${filtered.length} Staf Terdaftar',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WartegTheme.outline),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: WartegTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Database Warteg',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: WartegTheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Employee List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final emp = filtered[i];
                final status = emp['status'] as String? ?? 'Aktif';
                final isFaceReg = status == 'Registrasi Wajah';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage(emp['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120'),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    emp['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isFaceReg ? WartegTheme.warningContainer : WartegTheme.successContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isFaceReg ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${emp['role']} • ${emp['branch_name']}',
                              style: const TextStyle(fontSize: 11, color: WartegTheme.outline),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  emp['shift'] ?? 'Shift Pagi',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
                        tooltip: 'Hubungi WhatsApp Kru',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Menghubungkan WhatsApp ke ${emp['name']} (${emp['phone']})')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: WartegTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kru', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _openAddModal(context),
      ),
    );
  }

  void _openAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const ModalTambahKaryawan(),
    ).then((_) => setState(() {}));
  }

  Widget _buildFilterChip(String branch, String count) {
    final isSelected = selectedBranch == branch;
    return GestureDetector(
      onTap: () => setState(() => selectedBranch = branch),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? WartegTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? WartegTheme.primary : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Text(
              branch,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : WartegTheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : WartegTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : WartegTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModalTambahKaryawan extends StatefulWidget {
  const ModalTambahKaryawan({super.key});

  @override
  State<ModalTambahKaryawan> createState() => _ModalTambahKaryawanState();
}

class _ModalTambahKaryawanState extends State<ModalTambahKaryawan> {
  final nameCtrl = TextEditingController();
  final nikCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String selectedBranch = 'Kemang (04)';
  String selectedRole = 'Koki Utama';
  String selectedShift = 'Shift Pagi (07:00 - 15:00)';

  @override
  void dispose() {
    nameCtrl.dispose();
    nikCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  void _saveKaryawan() {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan nama lengkap kru')),
      );
      return;
    }

    final newEmp = {
      'id': 'emp-${DateTime.now().millisecondsSinceEpoch}',
      'nik': nikCtrl.text.trim().isNotEmpty ? nikCtrl.text.trim() : 'WB-2024-099',
      'name': nameCtrl.text.trim(),
      'role': selectedRole,
      'branch_name': selectedBranch,
      'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : '0812-0000-1111',
      'shift': selectedShift,
      'status': 'Registrasi Wajah',
      'attendance_today': 'Belum Hadir',
      'clock_in': '-',
      'avatar_url': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120'
    };

    WartegDataService().addEmployee(newEmp);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Karyawan baru ${nameCtrl.text} berhasil ditambahkan! Silakan lakukan perekaman biometrik.'),
        backgroundColor: WartegTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tambah Karyawan Baru', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('Pendaftaran Kru Warteg Bahari', style: TextStyle(fontSize: 12, color: WartegTheme.outline)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Photo upload placeholder (from Stitch)
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: WartegTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: WartegTheme.primary, style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: WartegTheme.primary, size: 28),
                    SizedBox(height: 4),
                    Text('Foto Kru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WartegTheme.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Text('Nama Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Misal: Joko Santoso')),
            const SizedBox(height: 14),

            const Text('NIK Karyawan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(controller: nikCtrl, decoration: const InputDecoration(hintText: 'Misal: WB-2024-099')),
            const SizedBox(height: 14),

            const Text('Nomor WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: 'Misal: 0812-3456-7890')),
            const SizedBox(height: 14),

            const Text('Cabang Penempatan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedBranch,
              items: ['Kemang (04)', 'Tebet (01)', 'Cipete (02)', 'Senopati (03)'].map((b) {
                return DropdownMenuItem(value: b, child: Text(b));
              }).toList(),
              onChanged: (val) => setState(() => selectedBranch = val!),
            ),
            const SizedBox(height: 14),

            const Text('Posisi / Peran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              items: ['Koki Utama', 'Koki Lauk', 'Kasir & Kas Harian', 'Pelayan Depan', 'Helper Dapur'].map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (val) => setState(() => selectedRole = val!),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveKaryawan,
                child: const Text('Simpan Data Karyawan', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
