import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthApi {
  static const _tokenKey = 'chamcong_access_token';

  // Đọc và kiểm tra phản hồi của API.
  Map<String, dynamic> _readResponse(http.Response response) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      data = decoded;
    } catch (_) {
      throw ApiException(
        'API trả dữ liệu không hợp lệ '
            '(${response.statusCode}). Kiểm tra API và Conveyor.',
        response.statusCode,
      );
    }

    final isSuccessful =
        response.statusCode >= 200 && response.statusCode < 300;

    if (!isSuccessful || data['success'] != true) {
      var message = data['message']?.toString() ??
          data['title']?.toString() ??
          'Yêu cầu thất bại (${response.statusCode}).';

      final errors = data['errors'];

      if (errors is List && errors.isNotEmpty) {
        message = '$message\n${errors.join('\n')}';
      } else if (errors is Map) {
        final details = errors.values.map((value) {
          return value is List ? value.join('\n') : value.toString();
        }).join('\n');

        message = '$message\n$details';
      }

      throw ApiException(message, response.statusCode);
    }

    return data;
  }

  Future<Map<String, dynamic>> _post(
      String path,
      Map<String, dynamic> body,
      ) async {
    final response = await http
        .post(
      ApiConfig.endpoint(path),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 45));

    return _readResponse(response);
  }

  // Đăng ký tài khoản nhân viên.
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    return _post(
      'Auth/register',
      {
        'fullName': fullName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }

  // Bước 1: kiểm tra mật khẩu và yêu cầu gửi OTP.
  Future<Map<String, dynamic>> beginLogin({
    required String username,
    required String password,
  }) async {
    final data = await _post(
      'Auth/login',
      {
        'username': username.trim(),
        'password': password,
      },
    );

    final challengeId = data['challengeId'];

    if (data['requiresOtp'] != true ||
        challengeId is! String ||
        challengeId.isEmpty) {
      throw Exception('API chưa trả về phiên xác thực OTP hợp lệ.');
    }

    // Chưa lưu token ở bước này.
    return data;
  }

  // Bước 2: gửi OTP lên server và lưu JWT khi thành công.
  Future<Map<String, dynamic>> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    final data = await _post(
      'Auth/verify-otp',
      {
        'challengeId': challengeId,
        'code': code.trim(),
      },
    );

    final token = data['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('API chưa trả về token đăng nhập.');
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_tokenKey, token);

    if (!saved) {
      throw Exception('Không lưu được phiên đăng nhập trên thiết bị.');
    }

    return data;
  }

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Lấy thông tin người dùng từ API được bảo vệ.
  Future<Map<String, dynamic>> getCurrentAccount() async {
    final token = await getSavedToken();

    if (token == null || token.isEmpty) {
      throw ApiException('Bạn chưa đăng nhập.', 401);
    }

    final response = await http
        .get(
      ApiConfig.endpoint('Account/me'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await logout();

      throw ApiException(
        'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
        401,
      );
    }

    final data = _readResponse(response);
    final account = data['data'];

    if (account is! Map<String, dynamic>) {
      throw Exception('Không đọc được thông tin tài khoản.');
    }

    return account;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}