import 'dart:convert';

import 'package:cross_file/cross_file.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const _requestTimeout = Duration(seconds: 15);

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

  /// The scheme and authority the API is reachable at, with the `/api` suffix
  /// and any stale port removed — `https://civic-connect-api-eq0j.onrender.com`.
  String get _apiOrigin {
    final uri = Uri.parse(baseUrl);
    if (!uri.hasScheme || uri.host.isEmpty) return '';
    return uri.hasPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
  }

  /// Points a stored photograph URL at the server this build actually talks to.
  ///
  /// Photographs are stored beside an absolute URL recorded by whichever server
  /// accepted the upload, so the database accumulates links to `localhost:5000`
  /// and to hostnames from earlier deployments — and a phone that is handed
  /// `localhost` resolves it to itself, not to the server. The bytes are served
  /// by the configured API either way, so the origin is replaced and the path
  /// kept. Idempotent: a URL already pointing at the right host is returned
  /// unchanged, and anything outside `/uploads/` — a Google avatar, a stock
  /// photograph — is left alone because this server does not serve it.
  String normalizeUrl(String url) {
    if (url.isEmpty) return url;

    const marker = '/uploads/';
    final markerIndex = url.indexOf(marker);
    if (markerIndex == -1) return url;

    // Drop any query string; `?v=2` on a photograph would otherwise land
    // inside the filename.
    final filename = url.substring(markerIndex + marker.length).split('?').first;
    if (filename.isEmpty) return url;

    final origin = _apiOrigin;
    if (origin.isEmpty) return url;

    return '$origin$marker$filename';
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
      return await http.get(uri, headers: headers).timeout(_requestTimeout);
    } catch (e) {
      debugPrint('ApiClient GET error: $e');
      rethrow;
    }
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('ApiClient POST error: $e');
      rethrow;
    }
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('ApiClient PUT error: $e');
      rethrow;
    }
  }

  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('ApiClient PATCH error: $e');
      rethrow;
    }
  }

  Future<http.Response> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      return await http.delete(uri, headers: headers).timeout(_requestTimeout);
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
        final filename = file.name.contains('.') ? file.name : '${file.name}.jpg';
        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            await file.readAsBytes(),
            filename: filename,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamedResponse = await request.send().timeout(_requestTimeout);
      return await http.Response.fromStream(
        streamedResponse,
      ).timeout(_requestTimeout);
    } catch (e) {
      debugPrint('ApiClient uploadMultipart error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> classifyImage(XFile image) async {
    final response = await uploadMultipart(
      '/issues/classify',
      fields: const {},
      files: [image],
      fileFieldName: 'photo',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Classification failed (${response.statusCode})');
  }

  Future<List<dynamic>> getNearbyCandidates(double lat, double lng, String category) async {
    final uri = Uri.parse('$baseUrl/issues/nearby-candidates?lat=$lat&lng=$lng&category=$category');
    final response = await http.get(uri, headers: {
      if (await token != null) 'Authorization': 'Bearer ${await token}'
    }).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<void> attachEvidence(String issueId, List<String> imageUrls) async {
    final uri = Uri.parse('$baseUrl/issues/$issueId/attach-evidence');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (await token != null) 'Authorization': 'Bearer ${await token}'
      },
      body: jsonEncode({'imageUrls': imageUrls}),
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Attach evidence failed (${response.statusCode})');
    }
  }

}
