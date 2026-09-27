import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/login/viewModel/login_view_model.dart';
import 'package:bbarna/resources/app_colors.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The sign-in screen: a scrollable form (with the brand panel beside it on
/// wide windows). Enter submits; errors show on the form.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// The fields that can carry an inline error.
enum _Field { username, password }

class _LoginScreenState extends State<LoginScreen> {
  /// Text of the username field.
  final TextEditingController userNameController = TextEditingController();

  /// Text of the password field.
  final TextEditingController passwordController = TextEditingController();

  /// Focus of the username field (Enter moves to the password).
  final FocusNode userNameFocus = FocusNode();

  /// Focus of the password field.
  final FocusNode passwordFocus = FocusNode();

  /// Whether the password is hidden (it starts hidden).
  bool _obscure = true;

  /// Inline error per field.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    userNameFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  /// Both fields must be filled in.
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (userNameController.text.trim().isEmpty) {
      errors[_Field.username] = "Enter your username";
    }
    if (passwordController.text.isEmpty) {
      errors[_Field.password] = "Enter your password";
    }
    return errors;
  }

  /// Validates, signs in, and on success replaces the login screen with the
  /// app shell.
  Future<void> _submit(LoginViewModel loginViewModel) async {
    final Map<_Field, String> errors = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty) {
      loginViewModel.clearError();
      return;
    }

    final bool signedIn = await loginViewModel.signIn(
      // Trimmed, so a stray space pasted with the username still matches.
      username: userNameController.text.trim(),
      password: passwordController.text,
    );
    if (!signedIn || !mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Sidebar(sidebarIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read from MediaQuery so the layout follows
    // window resizes.
    final double width = MediaQuery.sizeOf(context).width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return Scaffold(
      backgroundColor: AppTokens.canvas,
      body: Consumer<LoginViewModel>(
        builder: (context, loginViewModel, child) {
          final Widget form = _form(loginViewModel, isCompact);
          if (isCompact) return form;

          return Row(
            children: [
              const Expanded(flex: 4, child: _BrandPanel()),
              Expanded(flex: 5, child: form),
            ],
          );
        },
      ),
    );
  }

  /// The scrollable sign-in form: brand, heading, fields, error and button.
  Widget _form(LoginViewModel loginViewModel, bool isCompact) {
    // Always scrollable, so the button stays reachable on short windows.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTokens.gapXl),
                    if (isCompact) ...[
                      // Aligned, not bare: the column stretches its
                      // children, which would pull the square mark out to
                      // the full width of the form.
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _BrandMark(size: 44),
                      ),
                      const SizedBox(height: AppTokens.gapLg),
                    ],
                    const Text("Sign in", style: AppTokens.pageTitle),
                    const SizedBox(height: 5),
                    const Text("Use the username and password you were given.",
                        style: AppTokens.pageSubtitle),
                    const SizedBox(height: AppTokens.gapXl),
                    _usernameField(loginViewModel),
                    const SizedBox(height: AppTokens.gapMd),
                    _passwordField(loginViewModel),
                    if (loginViewModel.errorMessage != null) ...[
                      const SizedBox(height: AppTokens.gapMd),
                      _errorBanner(loginViewModel.errorMessage!),
                    ],
                    const SizedBox(height: AppTokens.gapLg),
                    _submitButton(loginViewModel),
                    const SizedBox(height: AppTokens.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Fields ---------------------------------------------------------

  /// Label above each field.
  static const TextStyle _labelStyle = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));

  /// Username box (Enter moves to the password).
  Widget _usernameField(LoginViewModel loginViewModel) {
    return _field(
      key: const Key('login_username'),
      label: "Username",
      hint: "Your username",
      controller: userNameController,
      focusNode: userNameFocus,
      error: _errors[_Field.username],
      enabled: !loginViewModel.isSubmitting,
      autofillHints: const [AutofillHints.username],
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => passwordFocus.requestFocus(),
      onChanged: () => _clearError(_Field.username, loginViewModel),
    );
  }

  /// Password box with a show/hide button (Enter submits).
  Widget _passwordField(LoginViewModel loginViewModel) {
    return _field(
      key: const Key('login_password'),
      label: "Password",
      hint: "Your password",
      controller: passwordController,
      focusNode: passwordFocus,
      error: _errors[_Field.password],
      enabled: !loginViewModel.isSubmitting,
      obscure: _obscure,
      autofillHints: const [AutofillHints.password],
      // Enter submits the form.
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(loginViewModel),
      onChanged: () => _clearError(_Field.password, loginViewModel),
      suffix: IconButton(
        key: const Key('login_password_visibility'),
        // The icon says what tapping it does, rather than restating the
        // state it is already in.
        tooltip: _obscure ? "Show password" : "Hide password",
        icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18),
        color: AppTokens.inkFaint,
        onPressed: loginViewModel.isSubmitting
            ? null
            : () => setState(() => _obscure = !_obscure),
      ),
    );
  }

  /// Clears one field's error and the sign-in error as the user types.
  void _clearError(_Field field, LoginViewModel loginViewModel) {
    loginViewModel.clearError();
    if (!_errors.containsKey(field)) return;
    setState(() => _errors.remove(field));
  }

  /// A labelled text box used by both fields.
  Widget _field({
    required Key key,
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool enabled,
    required VoidCallback onChanged,
    required ValueChanged<String> onSubmitted,
    required TextInputAction textInputAction,
    required List<String> autofillHints,
    String? error,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppTokens.surface : AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: TextField(
            key: key,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscure,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: (_) => onChanged(),
            inputFormatters: [
              // A username or password with a newline in it is a paste
              // accident, not an entry.
              FilteringTextInputFormatter.deny(RegExp(r'\n')),
            ],
            style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              suffixIcon: suffix,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// A failure stays on the form, next to the fields it is about. It used
  /// to be a snackbar pinned to the very top of the window, far from the
  /// thing that went wrong and gone a few seconds later.
  Widget _errorBanner(String message) {
    return Container(
      key: const Key('login_error'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.danger.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.danger.withValues(alpha: .28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppTokens.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.35, color: AppTokens.danger)),
          ),
        ],
      ),
    );
  }

  /// "Sign in" button; shows a spinner while signing in.
  Widget _submitButton(LoginViewModel loginViewModel) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        key: const Key('login_submit'),
        onPressed:
            loginViewModel.isSubmitting ? null : () => _submit(loginViewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.ink,
          disabledBackgroundColor: AppTokens.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
        // The button stays put and shows its progress, rather than being
        // taken out of the tree while the request runs.
        child: loginViewModel.isSubmitting
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : const Text("Sign in",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// The cyan half of the page on a wide window. It carries dark text: the
/// brand cyan is too light for white text to be readable on it.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColorsInApp.colorLightBlue,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(size: 52),
          const SizedBox(height: AppTokens.gapXl),
          const Text(
            "BBARNA",
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTokens.ink),
          ),
          const SizedBox(height: 6),
          Text(
            "Admin portal",
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: AppTokens.ink.withValues(alpha: .65)),
          ),
          const SizedBox(height: AppTokens.gapLg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              "Courses, subjects, units and everything that hangs off them "
              "— in one place.",
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppTokens.ink.withValues(alpha: .7)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The same rounded "B" the app header uses, so the two read as one app.
class _BrandMark extends StatelessWidget {
  /// Width and height of the mark.
  final double size;
  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.ink.withValues(alpha: .08)),
      ),
      child: Text(
        "B",
        style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            color: AppTokens.ink),
      ),
    );
  }
}
