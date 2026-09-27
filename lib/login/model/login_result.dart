/// What a successful sign-in learns about the person signing in; kept as a
/// plain value so the sign-in path can be tested without Firebase.
class LoginResult {
  /// The teacher document's id. This is what becomes the session.
  final String adminId;

  /// Which modules this user may see. Empty means unrestricted — see
  /// `Helper.allowedModuleIndices`.
  final List<String> moduleAccess;

  /// Creates a result from the matched teacher document.
  const LoginResult({required this.adminId, required this.moduleAccess});
}
