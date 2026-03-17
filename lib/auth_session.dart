/// Holds the authenticated user's session data in memory.
/// Set this after a successful login, then read it anywhere in the app.
class AuthSession {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  String userId = '';
  String accessToken = '';

  bool get isLoggedIn => accessToken.isNotEmpty;

  /// Authorization header value — pass to every API request.
  String get bearerToken => 'Bearer $accessToken';

  void clear() {
    userId = '';
    accessToken = '';
  }
}