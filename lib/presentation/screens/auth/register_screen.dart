import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/phone_otp_auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/background_pattern.dart';
import '../../widgets/app_toast.dart';
import 'role_explanation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _companyCtl = TextEditingController();
  String _selectedRole = 'admin';
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtl.dispose();
    _nameCtl.dispose();
    _companyCtl.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('251')) return '+$digits';
    if (digits.startsWith('0')) return '+251${digits.substring(1)}';
    return '+251$digits';
  }

  InputDecoration _inputDecoration(String label, {String? hint, Widget? prefix, required bool isDark}) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.15);
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5);
    final hintColor = isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefix: prefix,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: labelColor),
      hintStyle: TextStyle(color: hintColor),
    );
  }

  Future<void> _submit() async {
    final phone = _formatPhone(_phoneCtl.text);
    final name = _nameCtl.text.trim();
    final company = _companyCtl.text.trim();
    if (phone.length < 10) {
      AppToast.show('Enter a valid phone number');
      return;
    }
    if (name.isEmpty || company.isEmpty) {
      AppToast.show('Fill all fields');
      return;
    }
    setState(() { _loading = true; });
    try {
      final otp = context.read<PhoneOtpAuthProvider>();
      await otp.register(
        phone: phone,
        displayName: name,
        companyName: company,
        requestedRole: _selectedRole,
      );
      if (!mounted) return;
      if (otp.state == OtpAuthState.error) {
        AppToast.show(otp.authErrorMessage(AppLocalizations.of(context)));
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.registrationSubmitted),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) AppToast.show(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleExplanationScreen())),
              icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Image.asset('assets/icon-bgless.png', width: 72, height: 72, fit: BoxFit.contain),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 20),
                      Text(
                        'Register a new company',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        'Your account will be reviewed before activation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try to login in few hours',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameCtl,
                        decoration: _inputDecoration('Full Name', isDark: isDark),
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _companyCtl,
                        decoration: _inputDecoration('Company Name', isDark: isDark),
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phoneCtl,
                        decoration: _inputDecoration(
                          'Phone Number',
                          isDark: isDark,
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 4),
                            child: Text('+251 ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Account Type',
                            style: TextStyle(
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleExplanationScreen())),
                            child: const Text(
                              'Understand the app',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleOption(
                              title: AppLocalizations.of(context)!.admin,
                              subtitle: AppLocalizations.of(context)!.fullAccess,
                              icon: Icons.admin_panel_settings_outlined,
                              selected: _selectedRole == 'admin',
                              isDark: isDark,
                              onTap: () => setState(() => _selectedRole = 'admin'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleOption(
                              title: AppLocalizations.of(context)!.investor,
                              subtitle: AppLocalizations.of(context)!.readOnly,
                              icon: Icons.visibility_outlined,
                              selected: _selectedRole == 'viewer',
                              isDark: isDark,
                              onTap: () => setState(() => _selectedRole = 'viewer'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(AppLocalizations.of(context)!.submitRegistration, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.12)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.primary : (isDark ? Colors.white54 : Colors.black38)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
