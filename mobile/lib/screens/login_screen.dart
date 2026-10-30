import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/uway_data_source.dart';
import '../theme/uway_theme.dart';

/// Email and password sign-in. The account decides the role (passenger,
/// driver) and, for passengers, which trips they can see.
///
/// The screen uses the UWAY identity: a light-purple background that lets the
/// gold logo stand out, the logo in the centre, and the sign-in fields in a
/// soft cream card underneath it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authService,
    required this.onSignedIn,
    this.onDevelopmentMode,
    super.key,
  });

  final UwayAuthService authService;
  final void Function(UwaySession session) onSignedIn;

  /// Debug builds only: opens the sample-data / developer entry.
  final VoidCallback? onDevelopmentMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Login-only shades, built from the brand purple and gold.
  static const _purpleTop = Color(0xFF6F52BD);
  static const _purpleMid = Color(0xFF5B409F);
  static const _purpleBottom = Color(0xFF45307F);
  static const _card = Color(0xFFFFFBF2);
  static const _field = Color(0xFFF4EFFC);
  static const _fieldBorder = Color(0xFFD9CDF0);
  static const _goldButton = Color(0xFFEBC565);

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session =
          await widget.authService.signIn(_email.text, _password.text);
      if (!mounted) return;
      widget.onSignedIn(session);
    } on UwayApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Sign-in failed. Please try again.';
      });
    }
  }

  InputDecorationTheme get _fieldTheme => InputDecorationTheme(
        filled: true,
        fillColor: _field,
        labelStyle: const TextStyle(color: UwayColors.textMuted),
        floatingLabelStyle: const TextStyle(
          color: UwayColors.purpleDark,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: UwayColors.purple,
        suffixIconColor: UwayColors.purple,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: UwayColors.purple, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _purpleMid,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_purpleTop, _purpleMid, _purpleBottom],
            ),
          ),
          child: Stack(
            children: [
              // Soft gold circles that echo the logo without crowding the form.
              Positioned(
                top: -70,
                right: -60,
                child: _glow(220, const Color(0x26F3E6A8)),
              ),
              Positioned(
                bottom: -90,
                left: -70,
                child: _glow(260, const Color(0x1FF3E6A8)),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/uway-logo-lockup.png',
                                height: 170,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.directions_bus_filled_outlined,
                                  size: 96,
                                  color: UwayColors.goldLight,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _formCard(textTheme),
                            if (widget.onDevelopmentMode != null) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _busy ? null : widget.onDevelopmentMode,
                                style: TextButton.styleFrom(
                                  foregroundColor: UwayColors.goldLight,
                                ),
                                child:
                                    const Text('Developer mode (sample data)'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );

  Widget _formCard(TextTheme textTheme) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF3E6A8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3322124A),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: _fieldTheme),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome to UWAY',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: UwayColors.purpleDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'University transportation for University City.\nSign in with your university account.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: UwayColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _goldButton,
                foregroundColor: UwayColors.onGold,
                disabledBackgroundColor: const Color(0xFFEFE6C8),
                disabledForegroundColor: const Color(0xFF9A8F6E),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: UwayColors.onGold,
                      ),
                    )
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
