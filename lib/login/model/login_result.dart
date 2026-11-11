import 'package:bbarna/resources/constant.dart';

/// What a successful sign-in learns about the person signing in; kept as a
/// plain value so the sign-in path can be tested without Firebase.
class LoginResult {
  /// The teacher document's id. This is what becomes the session.
  final String adminId;

  /// Which modules this user may see. Empty means none (unless they are an
  /// admin) — see `Helper.allowedModuleIndices`.
  final List<String> moduleAccess;

  /// [roleAdmin] or [roleSubadmin]. An admin sees every module whatever
  /// [moduleAccess] says — see `Helper.allowedModuleIndices`.
  final String role;

  /// Creates a result from the matched teacher document.
  const LoginResult({
    required this.adminId,
    required this.moduleAccess,
    this.role = roleSubadmin,
  });
}
