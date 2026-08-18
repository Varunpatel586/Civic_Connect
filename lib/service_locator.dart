import 'package:civic_connect/services/auth_service.dart';
import 'package:civic_connect/services/comment_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  
  // Services
  final AuthService authService = AuthService();
  final CommentService commentService = CommentService();

  factory ServiceLocator() {
    return _instance;
  }

  ServiceLocator._internal();
}

// Global instance
final serviceLocator = ServiceLocator();
