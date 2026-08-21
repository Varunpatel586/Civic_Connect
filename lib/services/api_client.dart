import 'dart:convert';

import 'package:cross_file/cross_file.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Where the API lives.
  ///
  /// `10.0.2.2` is the Android emulator's alias for the host machine and
  /// resolves to nothing anywhere else, so it is rewritten for web and desktop
  /// builds. The value comes from the shared root `.env` file.
  String get baseUrl {
    final configured = dotenv.env['API_BASE_URL'];
    if (configured == null || configured.isEmpty) {
      return 'http://localhost:5000/api';
    }
    if (kIsWeb && configured.contains('10.0.2.2')) {
      return configured.replaceAll('10.0.2.2', 'localhost');
    }
    return configured;
  }

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

  /// Pulls the human-readable message out of a failed response.
  ///
  /// The API answers every error with `{ "message": ... }`, but a proxy, a
  /// rate-limiter or a crash can still put HTML or plain text on the wire.
  /// Callers used to `jsonDecode` error bodies directly, which turned those
  /// cases into a FormatException that masked the real failure.
  String errorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (e) {
      debugPrint('ApiClient: non-JSON error body (${response.statusCode})');
    }

    if (response.statusCode == 429) {
      return 'Too many requests. Wait a few minutes and try again.';
    }
    return fallback;
  }

  /// Uploads files using a multipart request.
  ///
  /// Takes [XFile] rather than `dart:io` `File` so the same path works on web,
  /// where `dart:io` does not exist at all.
  Future<http.Response> uploadMultipart(
    String path, {
    required Map<String, String> fields,
    required List<XFile> files,
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

      // Add files. Reading bytes rather than streaming keeps this identical on
      // web, where there is no file handle to stream from.
      for (final file in files) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            await file.readAsBytes(),
            filename: file.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      debugPrint('ApiClient uploadMultipart error: $e');
      rethrow;
    }
  }
}
