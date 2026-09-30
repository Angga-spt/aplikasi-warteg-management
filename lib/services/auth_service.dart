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
}

