import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_api.dart';

class AttendanceApi {
  final _authApi = AuthApi();

  Future<Map<String, dynamic>> _request(
      String method,
      String path,
      ) async {
    final token = await _authApi.getSavedToken();

    if (token == null || token.isEmpty) {
      throw ApiException('Bạn chưa đăng nhập.', 401);
    }

    final request = http.Request(
      method,
      ApiConfig.endpoint(path),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    final streamed = await request.send().timeout(
      const Duration(seconds: 30),
    );

    final response = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw ApiException(
        'Phiên đăng nhập không còn hợp lệ. '
            'Hãy quay về trang chính, đăng xuất rồi đăng nhập lại.',
        401,
      );
    }

    if (response.statusCode == 403) {
      throw ApiException(
        'Tài khoản không có quyền thực hiện thao tác này.',
        403,
      );
    }

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
        'API trả dữ liệu không hợp lệ (${response.statusCode}).',
        response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw ApiException(
        data['message']?.toString() ?? 'Yêu cầu thất bại.',
        response.statusCode,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> load({
    required bool isAdmin,
  }) {
    return _request(
      'GET',
      isAdmin ? 'Attendance/all' : 'Attendance/me',
    );
  }

  Future<void> checkIn() async {
    await _request('POST', 'Attendance/check-in');
  }

  Future<void> checkOut() async {
    await _request('POST', 'Attendance/check-out');
  }
}