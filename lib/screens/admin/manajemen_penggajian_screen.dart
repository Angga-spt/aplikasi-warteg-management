import 'package:flutter/material.dart';
import '../../services/warteg_data_service.dart';
import '../../theme/warteg_theme.dart';

class ManajemenPenggajianScreen extends StatelessWidget {
  const ManajemenPenggajianScreen({super.key});

  String _formatRupiah(num amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = WartegDataService();
    final payroll = service.payrollManagement;
    final crewList = (payroll['payout_crew_list'] as List<dynamic>?) ?? [];
    final fineRules = (payroll['fine_rules'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Penggajian', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Aturan denda & kompensasi telah disinkronkan.')),
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
            // Period Card (from Stitch)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: WartegTheme.primaryContainer, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Payroll ${payroll['period'] ?? 'Oktober 2024'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: WartegTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Siap Transfer',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: WartegTheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Total Bersih Siap Disbursed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(payroll['total_net_disbursement'] ?? 26280000),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Gaji Kotor', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            _formatRupiah(payroll['total_gross_expense'] ?? 28450000),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Denda Telat', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            _formatRupiah(payroll['total_late_fines'] ?? 320000),
                            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Kasbon Terpotong', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            _formatRupiah(payroll['total_kasbon_collected'] ?? 1850000),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Payout Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WartegTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memproses Batch Disbursement via BCA API... 5 Kru Berhasil Ditransfer!'),
                      backgroundColor: WartegTheme.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.payments, size: 20),
                label: const Text('Proses Disbursement Payroll', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 24),

            // Daftar Payout Kru (from Stitch)
            const Text(
              'Daftar Payout Kru Warteg',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...crewList.map((crew) {
              final isPaid = crew['is_paid'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPaid ? WartegTheme.successContainer : WartegTheme.warningContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? Icons.check : Icons.access_time,
                        color: isPaid ? WartegTheme.success : WartegTheme.warning,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(crew['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text(crew['role'] ?? '', style: const TextStyle(fontSize: 11, color: WartegTheme.outline)),
                          Text(
                            'Gaji Kotor: ${_formatRupiah(crew['gross'] ?? 0)}',
                            style: const TextStyle(fontSize: 10, color: WartegTheme.outline),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatRupiah(crew['net'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: WartegTheme.primary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid ? WartegTheme.successContainer : WartegTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            crew['status'] ?? '',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isPaid ? const Color(0xFF065F46) : WartegTheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Parameter Aturan Denda Otomatis (from Stitch)
            const Text(
              'Parameter Aturan Denda Otomatis',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...fineRules.map((rule) {
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: WartegTheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rule['range'] ?? '',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: WartegTheme.error),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rule['description'] ?? '',
                        style: const TextStyle(fontSize: 11, color: WartegTheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      '- ${_formatRupiah(rule['penalty_amount'] ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: WartegTheme.error),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
