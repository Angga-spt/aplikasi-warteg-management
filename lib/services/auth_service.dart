import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'warteg_data_service.dart';

class AuthResult {
  final bool isSuccess;
  final String? token;
  final Map<String, dynamic>? user;
  final String? errorMessage;
  final int? statusCode;

  AuthResult({
    required this.isSuccess,
    this.token,
    this.user,
    this.errorMessage,
    this.statusCode,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String _backendUrl = 'http://192.168.1.13:8000';
  bool _isEnvLoaded = false;

  String get backendUrl => _backendUrl;

  Future<void> init() async {
    if (_isEnvLoaded) return;
    try {
      final envString = await rootBundle.loadString('.env');
      for (final line in envString.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final splitIdx = trimmed.indexOf('=');
        if (splitIdx != -1) {
          final key = trimmed.substring(0, splitIdx).trim();
          final value = trimmed.substring(splitIdx + 1).trim();
          if (key == 'BACKEND_URL' || key == 'API_URL') {
            _backendUrl = value.replaceAll(RegExp(r'''['"]'''), '').trim();
          }
        }
      }
      _isEnvLoaded = true;
    } catch (_) {
      // Default to 127.0.0.1:8000 if .env is missing or fails to load
      _backendUrl = 'http://192.168.1.13:8000';
      _isEnvLoaded = true;
    }
  }

  /// Melakukan login ke backend FastAPI di POST /api/auth/login
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    await init();

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;
    final uri = Uri.parse('$cleanBaseUrl/api/auth/login');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': '*/*',
            },
            body: jsonEncode({
              'username_or_email': usernameOrEmail.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body is Map<String, dynamic>) {
        final token = body['access_token'] as String?;
        final user = body['user'] as Map<String, dynamic>?;

        return AuthResult(
          isSuccess: true,
          token: token,
          user: user,
          statusCode: 200,
        );
      } else {
        String message = 'Login gagal';
        if (body is Map<String, dynamic>) {
          if (body['detail'] is String) {
            message = body['detail'] as String;
          } else if (body['detail'] is List) {
            message = (body['detail'] as List).map((e) => e['msg'] ?? e.toString()).join(', ');
          } else if (body['message'] is String) {
            message = body['message'] as String;
          }
        }
        return AuthResult(
          isSuccess: false,
          errorMessage: message,
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (_) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Tidak dapat terhubung ke server ($cleanBaseUrl). Pastikan server backend sedang aktif.',
      );
    } on http.ClientException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi terputus: ${e.message}',
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Melakukan registrasi user/karyawan baru ke backend di POST /api/auth/register
  Future<AuthResult> registerUser({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String? phoneNumber,
    String role = 'user',
    int? kantorId,
  }) async {
    await init();

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;
    final uri = Uri.parse('$cleanBaseUrl/api/auth/register');

    try {
      final payload = <String, dynamic>{
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
      };

      if (fullName != null && fullName.trim().isNotEmpty) {
        payload['full_name'] = fullName.trim();
      }
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        payload['phone_number'] = phoneNumber.trim();
      }
      if (kantorId != null) {
        payload['kantor_id'] = kantorId;
      }

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': '*/*',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final user = body is Map<String, dynamic> ? body : null;
        return AuthResult(
          isSuccess: true,
          user: user,
          statusCode: response.statusCode,
        );
      } else {
        String message = 'Gagal mendaftarkan karyawan';
        if (body is Map<String, dynamic>) {
          if (body['detail'] is String) {
            message = body['detail'] as String;
          } else if (body['detail'] is List) {
            message = (body['detail'] as List)
                .map((e) => e['msg'] ?? e.toString())
                .join(', ');
          } else if (body['message'] is String) {
            message = body['message'] as String;
          }
        }
        return AuthResult(
          isSuccess: false,
          errorMessage: message,
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (_) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Tidak dapat terhubung ke server backend ($cleanBaseUrl).',
      );
    } on http.ClientException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi terputus: ${e.message}',
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Mengambil profil user yang sedang login dari GET /api/auth/me
  Future<AuthResult> getCurrentUser({String? token}) async {
    await init();

    final activeToken = token ?? WartegDataService().authToken;
    if (activeToken == null || activeToken.isEmpty) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Token autentikasi tidak ditemukan. Silakan login kembali.',
      );
    }

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;
    final uri = Uri.parse('$cleanBaseUrl/api/auth/me');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': '*/*',
              'Authorization': 'Bearer $activeToken',
            },
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body is Map<String, dynamic>) {
        return AuthResult(
          isSuccess: true,
          token: activeToken,
          user: body,
          statusCode: 200,
        );
      } else {
        String message = 'Gagal memuat profil pengguna';
        if (body is Map<String, dynamic> && body['detail'] != null) {
          message = body['detail'].toString();
        }
        return AuthResult(
          isSuccess: false,
          errorMessage: message,
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (_) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Tidak dapat terhubung ke server ($cleanBaseUrl).',
      );
    } on http.ClientException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi terputus: ${e.message}',
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Mengirim absensi ke POST /api/attendances
  Future<AuthResult> submitAttendance({
    required int scheduleId,
    required String attendanceType,
    required String photoBase64,
    double latitude = -6.2088,
    double longitude = 106.8456,
    String? notes,
    String? token,
  }) async {
    await init();

    final activeToken = token ?? WartegDataService().authToken;
    if (activeToken == null || activeToken.isEmpty) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Token autentikasi tidak ditemukan. Silakan login kembali.',
      );
    }

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;
    final uri = Uri.parse('$cleanBaseUrl/api/attendances');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': '*/*',
              'Authorization': 'Bearer $activeToken',
            },
            body: jsonEncode({
              'schedule_id': scheduleId,
              'attendance_type': attendanceType.toLowerCase(),
              'latitude': latitude,
              'longitude': longitude,
              'photo_base64': photoBase64,
              'notes': ?notes,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body is Map<String, dynamic>) {
        return AuthResult(
          isSuccess: true,
          token: activeToken,
          user: body,
          statusCode: response.statusCode,
        );
      } else {
        String message = 'Presensi gagal';
        if (body is Map<String, dynamic>) {
          if (body['detail'] is String) {
            message = body['detail'] as String;
          } else if (body['detail'] is List) {
            message = (body['detail'] as List)
                .map((e) => e['msg'] ?? e.toString())
                .join(', ');
          } else if (body['message'] is String) {
            message = body['message'] as String;
          }
        }
        return AuthResult(
          isSuccess: false,
          errorMessage: message,
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (_) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Tidak dapat terhubung ke server ($cleanBaseUrl).',
      );
    } on http.ClientException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi terputus: ${e.message}',
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Mengambil daftar riwayat presensi user dari GET /api/attendances/me
  Future<List<Map<String, dynamic>>> getMyAttendances({
    String? startDate,
    String? endDate,
    String? token,
  }) async {
    await init();

    final activeToken = token ?? WartegDataService().authToken;
    if (activeToken == null || activeToken.isEmpty) {
      return [];
    }

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final queryParams = <String, String>{
      'limit': '200',
    };
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }

    final uri = Uri.parse('$cleanBaseUrl/api/attendances/me')
        .replace(queryParameters: queryParams);

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': '*/*',
              'Authorization': 'Bearer $activeToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return body.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mengambil data absensi hari ini milik user dari GET /api/attendances/today
  Future<List<Map<String, dynamic>>> getTodayAttendance({String? token}) async {
    await init();

    final activeToken = token ?? WartegDataService().authToken;
    if (activeToken == null || activeToken.isEmpty) {
      return [];
    }

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/attendances/today');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': '*/*',
              'Authorization': 'Bearer $activeToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return body.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mengambil daftar seluruh kantor / cabang dari GET /api/kantor?skip=0&limit=50
  Future<List<Map<String, dynamic>>> getKantorList({
    int skip = 0,
    int limit = 50,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/kantor?skip=$skip&limit=$limit');

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return body.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mengambil detail satu kantor / cabang dari GET /api/kantor/{kantor_id}
  Future<Map<String, dynamic>?> getKantorDetail({
    required int kantorId,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/kantor/$kantorId');

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map) {
          return Map<String, dynamic>.from(body);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil daftar seluruh user dari GET /api/auth/users?skip=0&limit=50
  /// Secara default memfilter user dengan role admin agar tidak tampil di daftar staf
  Future<List<Map<String, dynamic>>> getUsersList({
    int skip = 0,
    int limit = 50,
    bool excludeAdmin = true,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;
    if (activeToken == null || activeToken.isEmpty) {
      return [];
    }

    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/auth/users?skip=$skip&limit=$limit');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $activeToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return body
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((user) {
                if (excludeAdmin) {
                  final role = (user['role'] as String? ?? '').toLowerCase().trim();
                  if (role == 'admin') return false;
                }
                return true;
              })
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mengambil daftar seluruh presensi dari GET /api/attendances?skip=...&limit=...
  Future<List<Map<String, dynamic>>> getAttendancesList({
    int? userId,
    String? date,
    String? startDate,
    String? endDate,
    String? attendanceType,
    int skip = 0,
    int limit = 100,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;
    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (date != null && date.trim().isNotEmpty) queryParams['date'] = date.trim();
    if (startDate != null && startDate.trim().isNotEmpty) {
      queryParams['start_date'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      queryParams['end_date'] = endDate.trim();
    }
    if (attendanceType != null &&
        attendanceType.trim().isNotEmpty &&
        attendanceType.toLowerCase() != 'semua') {
      queryParams['attendance_type'] = attendanceType.toLowerCase().trim();
    }

    final uri = Uri.parse('$cleanBaseUrl/api/attendances').replace(
      queryParameters: queryParams,
    );

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return body
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mengambil daftar jadwal dari GET /api/schedules
  Future<List<Map<String, dynamic>>> getSchedulesList({
    int? userId,
    String? day,
    String? date,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 100,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;
    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (day != null && day.trim().isNotEmpty) queryParams['day'] = day.trim();
    if (date != null && date.trim().isNotEmpty) queryParams['date'] = date.trim();
    if (startDate != null && startDate.trim().isNotEmpty) {
      queryParams['start_date'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      queryParams['end_date'] = endDate.trim();
    }

    final uri = Uri.parse('$cleanBaseUrl/api/schedules').replace(
      queryParameters: queryParams,
    );

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return body
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Membuat jadwal kerja baru per user ke POST /api/schedules
  Future<AuthResult> createSchedule({
    required int userId,
    required String day,
    required String clockIn,
    required String clockOut,
    String? shiftName,
    String? date,
    String? notes,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;
    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/schedules');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final payload = <String, dynamic>{
        'user_id': userId,
        'day': day,
        'clock_in': clockIn,
        'clock_out': clockOut,
      };
      if (shiftName != null && shiftName.trim().isNotEmpty) {
        payload['shift_name'] = shiftName.trim();
      }
      if (date != null && date.trim().isNotEmpty) {
        payload['date'] = date.trim();
      }
      if (notes != null && notes.trim().isNotEmpty) {
        payload['notes'] = notes.trim();
      }

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult(
          isSuccess: true,
          statusCode: response.statusCode,
          user: body is Map ? Map<String, dynamic>.from(body) : null,
        );
      } else {
        String msg = 'Gagal menambahkan jadwal (${response.statusCode})';
        if (body is Map && body['detail'] != null) {
          if (body['detail'] is String) {
            msg = body['detail'];
          } else if (body['detail'] is List &&
              (body['detail'] as List).isNotEmpty) {
            final first = (body['detail'] as List).first;
            msg = first['msg'] ?? msg;
          }
        }
        return AuthResult(
          isSuccess: false,
          statusCode: response.statusCode,
          errorMessage: msg,
        );
      }
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi gagal ke backend: $e',
      );
    }
  }

  /// Menghapus jadwal kerja dari DELETE /api/schedules/{schedule_id}
  Future<bool> deleteSchedule({
    required int scheduleId,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;
    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/schedules/$scheduleId');

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mengupdate data jadwal kerja dari PUT /api/schedules/{schedule_id}
  Future<AuthResult> updateSchedule({
    required int scheduleId,
    String? day,
    String? clockIn,
    String? clockOut,
    String? shiftName,
    String? date,
    String? notes,
    String? token,
  }) async {
    await init();
    final activeToken = token ?? WartegDataService().authToken;
    final cleanBaseUrl = _backendUrl.endsWith('/')
        ? _backendUrl.substring(0, _backendUrl.length - 1)
        : _backendUrl;

    final uri = Uri.parse('$cleanBaseUrl/api/schedules/$scheduleId');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (activeToken != null && activeToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $activeToken';
      }

      final payload = <String, dynamic>{};
      if (day != null) payload['day'] = day;
      if (clockIn != null) payload['clock_in'] = clockIn;
      if (clockOut != null) payload['clock_out'] = clockOut;
      if (shiftName != null) payload['shift_name'] = shiftName;
      if (date != null) payload['date'] = date.isEmpty ? null : date;
      if (notes != null) payload['notes'] = notes;

      final response = await http
          .put(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AuthResult(
          isSuccess: true,
          statusCode: response.statusCode,
          user: body is Map ? Map<String, dynamic>.from(body) : null,
        );
      } else {
        String msg = 'Gagal memperbarui jadwal (${response.statusCode})';
        if (body is Map && body['detail'] != null) {
          if (body['detail'] is String) {
            msg = body['detail'];
          } else if (body['detail'] is List &&
              (body['detail'] as List).isNotEmpty) {
            final first = (body['detail'] as List).first;
            msg = first['msg'] ?? msg;
          }
        }
        return AuthResult(
          isSuccess: false,
          statusCode: response.statusCode,
          errorMessage: msg,
        );
      }
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi gagal ke backend: $e',
      );
    }
  }
}


