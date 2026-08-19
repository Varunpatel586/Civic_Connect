import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api';

  String normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (url.contains('localhost')) {
      try {
        final uri = Uri.parse(baseUrl);
        return url.replaceAll('localhost', uri.host);
      } catch (e) {
        debugPrint('Error parsing baseUrl for normalization: $e');
      }
    }
    return url;
  }

  String? _token;

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    return _token;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('jwt_token');
    } else {
      await prefs.setString('jwt_token', token);
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final authToken = await token;
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<http.Response> get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http.get(uri, headers: headers);
    } catch (e) {
      debugPrint('ApiClient GET error: $e');
      rethrow;
    }
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http.post(uri, headers: headers, body: jsonEncode(body));
    } catch (e) {
      debugPrint('ApiClient POST error: $e');
      rethrow;
    }
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http.put(uri, headers: headers, body: jsonEncode(body));
    } catch (e) {
      debugPrint('ApiClient PUT error: $e');
      rethrow;
    }
  }

  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http.patch(uri, headers: headers, body: jsonEncode(body));
    } catch (e) {
      debugPrint('ApiClient PATCH error: $e');
      rethrow;
    }
  }

  Future<http.Response> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http.delete(uri, headers: headers);
    } catch (e) {
      debugPrint('ApiClient DELETE error: $e');
      rethrow;
    }
  }

  /// Uploads files using multipart request
  Future<http.Response> uploadMultipart(
    String path, {
    required Map<String, String> fields,
    required List<File> files,
    required String fileFieldName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final authToken = await token;
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      // Add fields
      request.fields.addAll(fields);

      // Add files
      for (final file in files) {
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final multipartFile = http.MultipartFile(
          fileFieldName,
          stream,
          length,
          filename: file.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      debugPrint('ApiClient uploadMultipart error: $e');
      rethrow;
    }
  }
}
