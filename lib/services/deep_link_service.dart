import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  final ApiClient _apiClient = ApiClient();

  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();

  Future<void> handleInitialUri() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error handling initial URI: $e');
    }
  }

  void listenToDeepLinks() {
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (e) {
      debugPrint('Error in deep link stream: $e');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Received Deep Link: $uri');
    final token = uri.queryParameters['token'];
    if (token != null) {
      await _apiClient.setToken(token);
      debugPrint('Token parsed and saved from deep link callback: $token');
    }
  }
}
