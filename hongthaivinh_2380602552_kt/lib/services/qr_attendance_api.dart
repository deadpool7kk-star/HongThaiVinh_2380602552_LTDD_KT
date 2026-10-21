import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_api.dart';

class QrAttendanceApi {
  final _authApi = AuthApi();

  Future<Map<String, dynamic>> _post(
      String path, {
        Map<String, dynamic>? body,
      }) async {
    final token = await _authApi.getSavedToken();

    if (token == null || token.isEmpty) {
      throw ApiException('Bạn chưa đăng nhập.', 401);
    }

    final response = await http.post(
      ApiConfig.endpoint(path),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body == null ? null : jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw ApiException(
        'Phiên đăng nhập không còn hợp lệ. '
            'Hãy đăng xuất rồi đăng nhập lại.',
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
        data['message']?.toString() ??
            data['title']?.toString() ??
            'Yêu cầu thất bại.',
        response.statusCode,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> generate() async {
    final response = await _post('QrAttendance/generate');

    return Map<String, dynamic>.from(
      response['data'] as Map,
    );
  }

  Future<String> scan({
    required String qrCode,
    required bool checkOut,
  }) async {
    final response = await _post(
      'QrAttendance/scan',
      body: {
        'qrCode': qrCode,
        'checkOut': checkOut,
      },
    );

    return response['message'].toString();
  }
}