import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final value = dotenv.env['API_BASE_URL']?.trim();

    if (value == null || value.isEmpty) {
      throw Exception('Chưa cấu hình API_BASE_URL trong .env.');
    }

    return value.endsWith('/') ? value : '$value/';
  }

  static Uri endpoint(String path) {
    return Uri.parse('$baseUrl$path');
  }
}