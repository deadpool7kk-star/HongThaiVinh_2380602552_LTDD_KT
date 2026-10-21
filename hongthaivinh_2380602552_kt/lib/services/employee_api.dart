import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_api.dart';

class EmployeeApi {
  final _authApi = AuthApi();

  Future<Map<String, dynamic>> _request(
      String method,
      String path, {
        Map<String, dynamic>? body,
      }) async {
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

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final streamed = await request.send().timeout(
      const Duration(seconds: 30),
    );

    final response = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw ApiException(
        'Phiên đăng nhập đã hết hạn. '
            'Hãy quay về trang chính, đăng xuất rồi đăng nhập lại.',
        401,
      );
    }

    if (response.statusCode == 403) {
      throw ApiException(
        'Tài khoản không có quyền quản lý nhân viên.',
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
      var message = data['message']?.toString() ??
          data['title']?.toString() ??
          'Không thực hiện được yêu cầu.';

      final errors = data['errors'];

      if (errors is List) {
        message = '$message\n${errors.join('\n')}';
      } else if (errors is Map) {
        final details = errors.values.map((value) {
          return value is List
              ? value.join('\n')
              : value.toString();
        }).join('\n');

        message = '$message\n$details';
      }

      throw ApiException(message, response.statusCode);
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final response = await _request('GET', 'Employees');
    final items = response['data'];

    if (items is! List) {
      throw Exception('Không đọc được danh sách nhân viên.');
    }

    return items.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  Future<void> update({
    required String id,
    required String fullName,
    required int? departmentId,
  }) async {
    await _request(
      'PUT',
      'Employees/${Uri.encodeComponent(id)}',
      body: {
        'fullName': fullName.trim(),
        'departmentId': departmentId,
      },
    );
  }
}