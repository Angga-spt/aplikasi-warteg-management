import 'package:flutter/material.dart';

import '../../services/warteg_data_service.dart';
import '../../services/auth_service.dart';
import '../../theme/warteg_theme.dart';

class ManajemenKaryawanScreen extends StatefulWidget {
  const ManajemenKaryawanScreen({super.key});

  @override
  State<ManajemenKaryawanScreen> createState() =>
      _ManajemenKaryawanScreenState();
}

class _ManajemenKaryawanScreenState extends State<ManajemenKaryawanScreen> {
  String selectedBranch = 'Semua Cabang';
  int? selectedKantorId;
  Map<String, dynamic>? selectedKantorDetail;
  bool isLoadingKantor = false;
  bool isLoadingDetail = false;
  List<Map<String, dynamic>> kantorList = [];
  List<Map<String, dynamic>> usersList = [];
  bool isLoadingUsers = false;
  String? usersError;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchKantorList();
    _fetchUsersList();
  }

  Future<void> _fetchUsersList() async {
    setState(() {
      isLoadingUsers = true;
      usersError = null;
    });

    try {
      final list = await AuthService().getUsersList(skip: 0, limit: 50);
      if (!mounted) return;
      setState(() {
        usersList = list;
        isLoadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        usersError = e.toString();
        isLoadingUsers = false;
      });
    }
  }

  Future<void> _fetchKantorList() async {
    setState(() {
      isLoadingKantor = true;
    });

    try {
      final list = await AuthService().getKantorList(skip: 0, limit: 50);
      if (!mounted) return;
      setState(() {
        kantorList = list;
        isLoadingKantor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingKantor = false;
      });
    }
  }

  Future<void> _selectBranch(String branchName, {int? id}) async {
    if (selectedBranch == branchName && selectedKantorId == id) return;

    setState(() {
      selectedBranch = branchName;
      selectedKantorId = id;
      selectedKantorDetail = null;
    });

    if (id != null) {
      setState(() {
        isLoadingDetail = true;
      });

      try {
        final detail = await AuthService().getKantorDetail(kantorId: id);
        if (!mounted) return;
        setState(() {
          selectedKantorDetail = detail;
          isLoadingDetail = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          isLoadingDetail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final allEmployees = usersList.isNotEmpty ? usersList : service.employees;

    final filtered = allEmployees.where((emp) {
      final name = (emp['full_name'] ?? emp['name'] ?? emp['username'] ?? '')
          .toString()
          .toLowerCase();
      final role = (emp['role'] ?? '').toString().toLowerCase();
      final kantorMap = emp['kantor'] as Map<String, dynamic>?;
      final branch = (kantorMap?['nama_cabang'] ?? emp['branch_name'] ?? '')
          .toString()
          .toLowerCase();
      final kantorId = emp['kantor_id'] ?? kantorMap?['id'];

      final matchesQuery =
          searchQuery.isEmpty ||
          name.contains(searchQuery.toLowerCase()) ||
          role.contains(searchQuery.toLowerCase()) ||
          (emp['phone_number'] ?? emp['phone'] ?? '').toString().contains(
            searchQuery,
          );

      if (!matchesQuery) return false;

      if (selectedBranch == 'Semua Cabang') return true;

      if (selectedKantorId != null &&
          kantorId != null &&
          kantorId == selectedKantorId) {
        return true;
      }

      return branch.contains(selectedBranch.toLowerCase()) ||
          selectedBranch.toLowerCase().contains(branch);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manajemen Karyawan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: () {
              _fetchKantorList();
              _fetchUsersList();
              if (selectedKantorId != null) {
                _selectBranch(selectedBranch, id: selectedKantorId);
              }
            },
          ),
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
                prefixIcon: const Icon(
                  Icons.search,
                  color: WartegTheme.outline,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Branch Filter Chips (from API /api/kantor?skip=0&limit=50)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildFilterChip(
                  branch: 'Semua Cabang',
                  count: '${allEmployees.length}',
                  isSelected: selectedBranch == 'Semua Cabang',
                  onTap: () => _selectBranch('Semua Cabang'),
                ),
                if (isLoadingKantor)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WartegTheme.primary,
                      ),
                    ),
                  )
                else if (kantorList.isNotEmpty)
                  ...kantorList.map((kantor) {
                    final id = (kantor['id'] as num?)?.toInt();
                    final branchName = (kantor['nama_cabang'] ?? '').toString();
                    final count = allEmployees.where((emp) {
                      final kantorMap = emp['kantor'] as Map<String, dynamic>?;
                      final kantorId = emp['kantor_id'] ?? kantorMap?['id'];
                      if (id != null && kantorId != null && kantorId == id) {
                        return true;
                      }
                      final b =
                          (kantorMap?['nama_cabang'] ??
                                  emp['branch_name'] ??
                                  '')
                              .toString()
                              .toLowerCase();
                      return b.contains(branchName.toLowerCase()) ||
                          branchName.toLowerCase().contains(b);
                    }).length;

                    return _buildFilterChip(
                      branch: branchName,
                      count: '$count',
                      isSelected:
                          selectedBranch == branchName &&
                          selectedKantorId == id,
                      onTap: () => _selectBranch(branchName, id: id),
                    );
                  })
                else ...[
                  _buildFilterChip(
                    branch: 'Kemang',
                    count: '7',
                    isSelected: selectedBranch == 'Kemang',
                    onTap: () => _selectBranch('Kemang'),
                  ),
                  _buildFilterChip(
                    branch: 'Tebet',
                    count: '6',
                    isSelected: selectedBranch == 'Tebet',
                    onTap: () => _selectBranch('Tebet'),
                  ),
                  _buildFilterChip(
                    branch: 'Cipete',
                    count: '6',
                    isSelected: selectedBranch == 'Cipete',
                    onTap: () => _selectBranch('Cipete'),
                  ),
                  _buildFilterChip(
                    branch: 'Senopati',
                    count: '5',
                    isSelected: selectedBranch == 'Senopati',
                    onTap: () => _selectBranch('Senopati'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Detail Cabang Info Banner (from API /api/kantor/{id})
          if (selectedKantorDetail != null || isLoadingDetail)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: WartegTheme.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isLoadingDetail
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WartegTheme.primary,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Memuat detail cabang dari API /api/kantor/{id}...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: WartegTheme.outline,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: WartegTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storefront,
                              color: WartegTheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      selectedKantorDetail!['nama_cabang'] ??
                                          selectedBranch,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: WartegTheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: WartegTheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'ID: ${selectedKantorDetail!['id']}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: WartegTheme.outline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (selectedKantorDetail!['alamat_lengkap'] !=
                                    null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedKantorDetail!['alamat_lengkap']
                                        .toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: WartegTheme.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selectedKantorDetail!['radius'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: WartegTheme.successContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Radius ${selectedKantorDetail!['radius']}m',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),

          // Count Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menampilkan ${filtered.length} Staf Terdaftar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WartegTheme.outline,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: WartegTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    usersList.isNotEmpty ? 'Database Karyawan' : 'Data Kosong',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: WartegTheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Employee List
          Expanded(
            child: isLoadingUsers
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: WartegTheme.primary),
                        SizedBox(height: 12),
                        Text(
                          'Memuat data staf dari /api/auth/users...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WartegTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 54,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedBranch == 'Semua Cabang'
                                ? 'Belum ada data staf terdaftar di server.'
                                : 'Tidak ada staf yang terdaftar di cabang $selectedBranch.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WartegTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (selectedBranch != 'Semua Cabang')
                            TextButton.icon(
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Tampilkan Semua Cabang'),
                              onPressed: () => _selectBranch('Semua Cabang'),
                            ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchKantorList();
                      await _fetchUsersList();
                      if (selectedKantorId != null) {
                        await _selectBranch(
                          selectedBranch,
                          id: selectedKantorId,
                        );
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final emp = filtered[i];
                        final fullName = (emp['full_name'] as String?)?.trim();
                        final name = (fullName != null && fullName.isNotEmpty)
                            ? fullName
                            : (emp['name'] as String? ??
                                  emp['username'] as String? ??
                                  'Karyawan');

                        final rawRole = (emp['role'] as String? ?? 'Staf')
                            .toLowerCase();
                        String displayRole = emp['role'] as String? ?? 'Staf';
                        if (rawRole == 'admin') {
                          displayRole = 'Admin / Pengelola';
                        } else if (rawRole == 'owner') {
                          displayRole = 'Owner / GM';
                        } else if (rawRole == 'user') {
                          displayRole = 'Kru Warteg';
                        }

                        final kantorMap =
                            emp['kantor'] as Map<String, dynamic>?;
                        final branchName =
                            kantorMap?['nama_cabang'] ??
                            emp['branch_name'] ??
                            'Cabang Tidak Ditugaskan';

                        final isActive = emp['is_active'] != false;
                        final status =
                            emp['status'] as String? ??
                            (isActive ? 'Aktif' : 'Non-Aktif');
                        final isWarning =
                            status == 'Registrasi Wajah' || !isActive;

                        String shiftDisplay = 'Shift belum di atur';
                        final schedules = emp['schedules'] as List<dynamic>?;
                        if (schedules != null && schedules.isNotEmpty) {
                          final firstSched =
                              schedules.first as Map<String, dynamic>;
                          final sName = firstSched['shift_name'] ?? 'Shift';
                          final inTime = (firstSched['clock_in'] ?? '')
                              .toString();
                          final inFormatted = inTime.length >= 5
                              ? inTime.substring(0, 5)
                              : inTime;
                          shiftDisplay = inFormatted.isNotEmpty
                              ? '$sName ($inFormatted)'
                              : '$sName';
                        } else if (emp['shift'] != null) {
                          shiftDisplay = emp['shift'] as String;
                        }

                        final phone =
                            emp['phone_number'] as String? ??
                            emp['phone'] as String? ??
                            '-';
                        final avatarUrl = emp['avatar_url'] as String?;

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
                                backgroundColor: WartegTheme.primaryContainer,
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: WartegTheme.primary,
                                        ),
                                      )
                                    : null,
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
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
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
                                            color: isWarning
                                                ? WartegTheme.warningContainer
                                                : WartegTheme.successContainer,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: isWarning
                                                  ? const Color(0xFF92400E)
                                                  : const Color(0xFF065F46),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$displayRole • $branchName',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: WartegTheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          shiftDisplay,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chat,
                                  color: Color(0xFF25D366),
                                  size: 22,
                                ),
                                tooltip: 'Hubungi WhatsApp Kru',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Menghubungkan WhatsApp ke $name ($phone)',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: WartegTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Kru',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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
      builder: (ctx) => ModalTambahKaryawan(kantorList: kantorList),
    ).then((_) => setState(() {}));
  }

  Widget _buildFilterChip({
    required String branch,
    required String count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? WartegTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? WartegTheme.primary : const Color(0xFFCBD5E1),
          ),
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
                color: isSelected
                    ? Colors.white24
                    : WartegTheme.surfaceContainerLow,
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
  final List<Map<String, dynamic>>? kantorList;
  const ModalTambahKaryawan({super.key, this.kantorList});

  @override
  State<ModalTambahKaryawan> createState() => _ModalTambahKaryawanState();
}

class _ModalTambahKaryawanState extends State<ModalTambahKaryawan> {
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  int? selectedKantorId;
  String selectedRole = 'user';
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.kantorList != null && widget.kantorList!.isNotEmpty) {
      selectedKantorId = (widget.kantorList!.first['id'] as num?)?.toInt();
    }
  }

  @override
  void dispose() {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKaryawan() async {
    final username = usernameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;
    final fullName = fullNameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    if (username.isEmpty || username.length < 3) {
      setState(() => errorMessage = 'Username wajib diisi minimal 3 karakter');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() => errorMessage = 'Format email tidak valid');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      setState(() => errorMessage = 'Password wajib diisi minimal 6 karakter');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.registerUser(
      username: username,
      email: email,
      password: password,
      fullName: fullName.isNotEmpty ? fullName : null,
      phoneNumber: phone.isNotEmpty ? phone : null,
      role: selectedRole,
      kantorId: selectedKantorId,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result.isSuccess) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Karyawan baru $username berhasil didaftarkan!'),
              ),
            ],
          ),
          backgroundColor: WartegTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      setState(() {
        errorMessage = result.errorMessage ?? 'Gagal mendaftarkan user baru';
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambah Karyawan Baru',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Pendaftaran Akun Kru / Staf Warteg',
                      style: TextStyle(
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

            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: WartegTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: WartegTheme.error.withValues(alpha: 0.3),
                  ),
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
                        errorMessage!,
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
              const SizedBox(height: 14),
            ],

            const Text(
              'Nama Lengkap',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: fullNameCtrl,
              decoration: const InputDecoration(
                hintText: 'Misal: Joko Santoso',
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Username *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                hintText: 'Misal: jokosantoso (min. 3 karakter)',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Email *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Misal: joko@warteg.id',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Password Akun *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                hintText: 'Minimal 6 karakter',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20,
                  ),
                  onPressed:
                      () => setState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Nomor WhatsApp / HP',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Misal: 081234567890',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Cabang Penempatan (Kantor)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: selectedKantorId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.storefront_outlined, size: 20),
              ),
              items:
                  (widget.kantorList != null && widget.kantorList!.isNotEmpty)
                      ? widget.kantorList!.map((k) {
                        final id = (k['id'] as num?)?.toInt();
                        final name = k['nama_cabang'] ?? 'Cabang $id';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name.toString()),
                        );
                      }).toList()
                      : const [
                        DropdownMenuItem<int>(
                          value: 1,
                          child: Text('Warteg Bahari (Utama)'),
                        ),
                      ],
              onChanged: (val) => setState(() => selectedKantorId = val),
            ),
            const SizedBox(height: 14),

            const Text(
              'Posisi / Hak Akses',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.shield_outlined, size: 20),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'user',
                  child: Text('Kru Warteg (user)'),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text('Admin / Pengelola (admin)'),
                ),
              ],
              onChanged: (val) => setState(() => selectedRole = val ?? 'user'),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveKaryawan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WartegTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Daftarkan Karyawan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
