import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/phone_otp_auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_toast.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});
  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _digits.map((c) => c.text).join();
    if (code.length != 6) return;
    final p = context.read<PhoneOtpAuthProvider>();
    await p.verifyOtp(code: code);
    if (!mounted) return;
    if (p.state == OtpAuthState.authenticated) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      AppToast.show(
          p.authErrorMessage(AppLocalizations.of(context)));
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    final p = context.read<PhoneOtpAuthProvider>();
    await p.resendOtp();
    if (!mounted) return;
    if (p.state == OtpAuthState.awaitingCode) {
      AppToast.show('Code resent', success: true);
      for (final c in _digits) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      _startTimer();
    } else {
      AppToast.show(p.authErrorMessage(AppLocalizations.of(context),
          fallback: 'Failed to resend'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<PhoneOtpAuthProvider>();
    final isVerifying = authProvider.state == OtpAuthState.verifying;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.verify, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, size: 36, color: AppColors.primary),
                  ),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 24),
                Text(
                  'Verification code',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to your WhatsApp',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 46,
                      height: 56,
                      child: TextField(
                        key: Key('codeDigit$i'),
                        controller: _digits[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _digits[i].text.isNotEmpty
                                  ? AppColors.primary
                                  : (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1)),
                              width: _digits[i].text.isNotEmpty ? 1.6 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {});
                          if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                          if (i == 5 && _digits.every((c) => c.text.isNotEmpty)) _submit();
                        },
                      ),
                    );
                  }),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isVerifying
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(AppLocalizations.of(context)!.verify, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 24),
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Resend in ${_resendSeconds}s',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resend,
                          child: Text(
                            'Resend code',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 42),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
