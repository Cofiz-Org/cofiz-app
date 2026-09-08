import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/relay_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/phone_otp_auth_provider.dart';
import '../../../core/services/auth_backend.dart';
import '../../../core/services/telegram_native_auth.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/background_pattern.dart';
import '../../widgets/app_toast.dart';
import 'otp_verify_screen.dart';
import 'register_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtl = TextEditingController();
  bool _showWhatsappField = false;
  bool _sending = false;
  String? _lastTelegramToken;
  StreamSubscription? _telegramSub;

  @override
  void initState() {
    super.initState();
    TelegramNativeAuth.ensureListener();
    _telegramSub = TelegramNativeAuth.coldStartLogin.listen(
      (data) => _completeTelegramLogin(data['idToken']!),
      onError: (e) {
        if (mounted) AppToast.show('Telegram login error: $e');
      },
    );
  }

  Future<void> _completeTelegramLogin(String idToken) async {
    if (!mounted) return;
    if (idToken == _lastTelegramToken) return;
    _lastTelegramToken = idToken;
    setState(() => _sending = true);
    try {
      final p = context.read<PhoneOtpAuthProvider>();
      await p.completeTelegramNative(idToken: idToken);
      if (!mounted) return;
      if (p.state != OtpAuthState.authenticated) {
        AppToast.show(p.authErrorMessage(AppLocalizations.of(context),
            fallback: 'Telegram login failed'));
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show('Telegram login error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _telegramSub?.cancel();
    _phoneCtl.dispose();
    super.dispose();
  }

  Future<void> _continueWithTelegram() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      if (await TelegramNativeAuth.isAvailable()) {
        await _continueWithTelegramNative();
        return;
      }
      await _continueWithTelegramWeb();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _continueWithTelegramNative() async {
    try {
      final native = await TelegramNativeAuth.login();
      if (!mounted) return;
      final idToken = native['idToken']!;
      if (idToken == _lastTelegramToken) return;
      _lastTelegramToken = idToken;
      final p = context.read<PhoneOtpAuthProvider>();
      await p.completeTelegramNative(idToken: idToken);
      if (!mounted) return;
      if (p.state != OtpAuthState.authenticated) {
        AppToast.show(p.authErrorMessage(AppLocalizations.of(context),
            fallback: 'Telegram login failed'));
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'START_FAILED') {
        await _continueWithTelegramWeb();
        return;
      }
      AppToast.show('Telegram login error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      AppToast.show('Telegram login error: $e');
    }
  }

  Future<void> _continueWithTelegramWeb() async {
    final botId = RelayConfig.telegramBotId;
    if (botId.isEmpty) {
      AppToast.show('Telegram login is not configured');
      return;
    }
    final authority = RelayConfig.relayUrl.isNotEmpty
        ? Uri.parse(RelayConfig.relayUrl).authority
        : 'cofiz.natanim.dev';
    final origin = 'https://$authority';
    final url = Uri.parse(
      'https://oauth.telegram.org/auth'
      '?bot_id=$botId'
      '&origin=${Uri.encodeComponent(origin)}'
      '&embed=1'
      '&request_access=write'
      '&return_to=${Uri.encodeComponent('$origin/auth/telegram/login')}',
    );
    try {
      final ok = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      if (!ok && mounted) AppToast.show('Could not open Telegram');
    } catch (e) {
      if (mounted) AppToast.show('Telegram login error: $e');
    }
  }

  Future<void> _submitWhatsapp() async {
    final raw = _phoneCtl.text.trim();
    final phone = normalizeE164(raw);
    if (!isValidE164(phone)) {
      AppToast.show('Enter a valid phone number (e.g. 0911234567)');
      return;
    }
    setState(() => _sending = true);
    final p = context.read<PhoneOtpAuthProvider>();
    await p.requestOtp(phone: phone, provider: OtpProvider.whatsapp);
    if (!mounted) return;
    setState(() => _sending = false);
    if (p.state == OtpAuthState.awaitingCode) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OtpVerifyScreen()));
    } else {
      AppToast.show(p.authErrorMessage(AppLocalizations.of(context),
          fallback: 'Could not send code'));
    }
  }

  Widget _brandTile({
    required String asset,
    required VoidCallback? onPressed,
    required Key key,
  }) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: ElevatedButton(
          key: key,
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            overlayColor: Colors.transparent,
          ),
          child: Center(
            child: SvgPicture.asset(
              asset,
              width: 90,
              height: 90,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          const BackgroundPattern(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
              icon: const Icon(Icons.business_center_outlined, color: AppColors.primary, size: 22),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Center(
                      child: Image.asset('assets/icon-bgless.png', width: 96, height: 96, fit: BoxFit.contain),
                    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.92, 0.92)),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Cofiz',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 42),
                    Text(
                      'Sign in with',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _brandTile(
                          key: const Key('continueWithWhatsappButton'),
                          asset: 'assets/whatsapp.svg',
                          onPressed: () => setState(() => _showWhatsappField = !_showWhatsappField),
                        ),
                        SizedBox(
                          height: 90,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  width: 1,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'or',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 1,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _brandTile(
                          key: const Key('continueWithTelegramButton'),
                          asset: 'assets/telegram.svg',
                          onPressed: _continueWithTelegram,
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _showWhatsappField
                          ? Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      key: const Key('whatsappPhoneField'),
                                      controller: _phoneCtl,
                                      keyboardType: TextInputType.phone,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black87),
                                      cursorColor: AppColors.primary,
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.phoneNumber,
                                        prefixText: '+251 ',
                                        prefixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                        filled: true,
                                        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      key: const Key('sendCodeButton'),
                                      onPressed: _sending ? null : _submitWhatsapp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _sending
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text(AppLocalizations.of(context)!.send, style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 42),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
