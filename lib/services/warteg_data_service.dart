import 'dart:convert';

import 'package:flutter/services.dart';

class WartegDataService {
  static final WartegDataService _instance = WartegDataService._internal();
  factory WartegDataService() => _instance;
  WartegDataService._internal();

  Map<String, dynamic>? _data;
  bool _isLoading = false;

  bool get isLoaded => _data != null;

  Future<void> init() async {
    if (_data != null || _isLoading) return;
    _isLoading = true;
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/warteg_dump_data.json',
      );
      _data = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // Fallback data if file loading issues occur
      _data = _getFallbackData();
    } finally {
      _isLoading = false;
    }
  }

  Map<String, dynamic> get appInfo => _data?['app_info'] ?? {};
  Map<String, dynamic> get currentUser => _data?['current_user'] ?? {};
  Map<String, dynamic> get adminProfile => _data?['admin_profile'] ?? {};
  List<dynamic> get branches => _data?['branches'] ?? [];
  List<dynamic> get employees => _data?['employees'] ?? [];
  List<dynamic> get kitchenNotes => _data?['kitchen_notes'] ?? [];
  Map<String, dynamic> get attendanceHistory =>
      _data?['attendance_history'] ?? {};
  Map<String, dynamic> get userPayslip => _data?['user_payslip'] ?? {};
  Map<String, dynamic> get payrollManagement =>
      _data?['payroll_management'] ?? {};
  List<dynamic> get liveAttendanceFeed => _data?['live_attendance_feed'] ?? [];

  String? _authToken;
  String? get authToken => _authToken;

  /// Menghapus sesi login, token JWT / Bearer, dan me-reset data cache pengguna
  Future<void> clearAuth() async {
    _authToken = null;
    _data = null;
    await init();
  }

  void setLoggedInUser(Map<String, dynamic> userData, String token) {
    _authToken = token;
    if (_data == null) return;

    final role = (userData['role'] ?? 'user').toString().toLowerCase();
    if (role == 'owner' || role == 'admin') {
      final admin = _data!['admin_profile'] as Map<String, dynamic>?;
      if (admin != null) {
        admin['name'] =
            userData['full_name'] ?? userData['username'] ?? admin['name'];
        admin['email'] = userData['email'] ?? admin['email'];
        admin['username'] = userData['username'] ?? admin['username'];
        admin['role'] = 'Owner & General Manager';
        admin['schedules'] = userData['schedules'] ?? admin['schedules'] ?? [];
        if (userData['kantor'] != null) {
          admin['kantor'] = userData['kantor'];
          if (userData['kantor'] is Map &&
              userData['kantor']['nama_cabang'] != null) {
            admin['branch_name'] = userData['kantor']['nama_cabang'];
          }
        }
      }
    } else {
      final curUser = _data!['current_user'] as Map<String, dynamic>?;
      if (curUser != null) {
        curUser['name'] =
            userData['full_name'] ?? userData['username'] ?? curUser['name'];
        curUser['full_name'] = userData['full_name'] ?? curUser['full_name'];
        curUser['email'] = userData['email'] ?? curUser['email'];
        curUser['username'] = userData['username'] ?? curUser['username'];
        curUser['phone_number'] =
            userData['phone_number'] ?? curUser['phone_number'];
        curUser['role'] = userData['role'] ?? curUser['role'];
        curUser['id'] = userData['id'] ?? curUser['id'];
        if (userData['id'] != null) {
          curUser['nik'] = '${userData['id']}';
        }
        curUser['schedules'] = userData['schedules'] ?? curUser['schedules'] ?? [];
        if (userData['kantor'] != null) {
          curUser['kantor'] = userData['kantor'];
          if (userData['kantor'] is Map &&
              userData['kantor']['nama_cabang'] != null) {
            curUser['branch_name'] = userData['kantor']['nama_cabang'];
          }
        }
      }
    }
  }

  void recordAttendance({required bool isClockIn, required String time}) {
    if (_data == null) return;
    final user = _data!['current_user'] as Map<String, dynamic>?;
    if (user != null) {
      final shift = user['shift_today'] as Map<String, dynamic>?;
      if (shift != null) {
        shift['attendance_status'] = isClockIn
            ? 'Sudah Absen Masuk'
            : 'Sudah Absen Pulang';
        shift['current_time_display'] = '$time WIB';
      }
    }

    final feed = _data!['live_attendance_feed'] as List<dynamic>?;
    if (feed != null) {
      feed.insert(0, {
        'id': 'feed-${DateTime.now().millisecondsSinceEpoch}',
        'employee_name': currentUser['name'] ?? 'Budi Santoso',
        'role': currentUser['role'] ?? 'Koki Utama',
        'branch_name': currentUser['branch_name'] ?? 'Warteg Bahari Kemang',
        'timestamp': '$time WIB',
        'status': isClockIn ? 'Masuk Tepat Waktu' : 'Pulang Selesai Shift',
        'status_type': 'success',
        'face_score': '98.8%',
        'distance': '35m',
        'avatar_url': currentUser['avatar_url'],
      });
    }
  }

  void addEmployee(Map<String, dynamic> newEmp) {
    if (_data == null) return;
    final empList = _data!['employees'] as List<dynamic>?;
    if (empList != null) {
      empList.insert(0, newEmp);
    }
  }

  Map<String, dynamic> _getFallbackData() {
    return {
      "app_info": {"app_name": "Warteg Mobile Management", "version": "1.0.0"},
      "current_user": {
        "name": "Budi Santoso",
        "nickname": "Mas Budi",
        "role": "Koki Utama",
        "branch_name": "Warteg Bahari Kemang (Cabang 04)",
        "shift_today": {
          "name": "Shift Pagi",
          "period": "08:00 - 16:00 WIB",
          "gate_status": "Gerbang absen dibuka",
          "clock_in_target": "08:00 WIB",
          "clock_out_target": "16:00 WIB",
          "daily_wage_estimate": 120000,
          "attendance_status": "Belum Absen Masuk",
          "current_time_display": "07:42:15 WIB",
        },
        "geofence": {
          "current_distance_meters": 35,
          "radius_limit_meters": 50,
          "is_in_range": true,
          "status_label": "In-Range",
          "status_detail": "35m dari outlet Kemang (Radius Terverifikasi Aman)",
        },
      },
      "admin_profile": {
        "name": "Pak Haji Mansur",
        "role": "Owner & General Manager",
        "stats_overview": {
          "total_active_staff": 24,
          "new_staff_count": 2,
          "today_present": 21,
          "today_late": 2,
          "today_on_leave": 1,
          "morning_shift_rate_percent": 88,
        },
      },
      "branches": [],
      "employees": [],
      "kitchen_notes": [],
      "attendance_history": {"records": []},
      "user_payslip": {"earnings": [], "deductions": []},
      "payroll_management": {"payout_crew_list": [], "fine_rules": []},
      "live_attendance_feed": [],
    };
  }
}
