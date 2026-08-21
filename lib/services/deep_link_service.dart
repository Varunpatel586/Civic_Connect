import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';

/// Handles OAuth callbacks arriving as deep links.
///
/// A deep link is attacker-controllable: anything can open the app with a URL,
/// so a token in a query string is a claim, not a credential. Nothing here is
/// trusted until the server has accepted it — see [_handleDeepLink].
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  /// The only callback this app answers to. Must match the intent filter in
  /// `android/app/src/main/AndroidManifest.xml`.
  static const String expectedScheme = 'civicconnect';
  static const String expectedHost = 'login-callback';

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final AppLinks _appLinks = AppLinks();

  /// Fires after a deep link successfully establishes a session, so the app can
  /// refresh whatever depends on the signed-in user.
  VoidCallback? onSessionEstablished;

  Future<void> handleInitialUri() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: could not read initial link: $e');
    }
  }

  void listenToDeepLinks() {
    _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) => debugPrint('DeepLinkService: link stream error: $e'),
    );
  }

  /// Accepts a token only if it came in on our own callback *and* the server
  /// recognises it.
  ///
  /// The old implementation wrote any `?token=` value straight to storage,
  /// which let a crafted link silently swap the signed-in account. Now the
  /// candidate is probed against `/auth/profile` and the previous session is
  /// restored if the server refuses it.
  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != expectedScheme || uri.host != expectedHost) {
      debugPrint('DeepLinkService: ignoring link for ${uri.scheme}://${uri.host}');
      return;
    }

    final candidate = uri.queryParameters['token'];
    if (candidate == null || candidate.isEmpty) {
      debugPrint('DeepLinkService: callback carried no token');
      return;
    }

    final previous = await _apiClient.token;

    try {
      await _apiClient.setToken(candidate);
      final profile = await _authService.getCurrentUserProfile();

      if (profile == null) {
        // The server did not accept it. Put back whatever was there before,
        // so a bad link cannot even sign the user out.
        await _apiClient.setToken(previous);
        debugPrint('DeepLinkService: server rejected the token, session unchanged');
        return;
      }

      debugPrint('DeepLinkService: session established for ${profile.username}');
      onSessionEstablished?.call();
    } catch (e) {
      await _apiClient.setToken(previous);
      debugPrint('DeepLinkService: could not verify token, session unchanged: $e');
    }
  }
}
