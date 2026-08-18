import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  final supabase = Supabase.instance.client;

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
    if (uri.toString().contains('access_token') || 
        uri.toString().contains('error=')) {
      await supabase.auth.getSessionFromUrl(uri);
    }
  }
}
