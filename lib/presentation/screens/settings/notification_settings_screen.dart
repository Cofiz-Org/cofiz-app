import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/email_verification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/verification_dialog.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notifications,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          // Optional lookup: keeps the screen testable without Firebase
          // (AuthProvider touches FirebaseAuth at construction).
          AuthProvider? auth;
          try {
            auth = Provider.of<AuthProvider>(context);
          } catch (_) {
            auth = null;
          }
          final emailVerified = auth?.appUser?.emailVerified ?? false;
          final email = auth?.appUser?.email ?? '';
          final hasEmail = email.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Column(
                children: [
                  _buildSwitchTile(
                    context,
                    title: AppLocalizations.of(context)!.emailNotifications,
                    subtitle: hasEmail
                        ? (emailVerified
                            ? AppLocalizations.of(context)!.receiveUpdatesViaEmail
                            : 'Verify your email to enable notifications')
                        : 'Add an email to your profile first',
                    value: settings.emailNotifications && emailVerified,
                    onChanged: (val) {
                      if (!hasEmail) {
                        AppToast.show('Add an email to your profile first');
                        return;
                      }
                      if (!emailVerified) {
                        AppToast.show('Verify your email first');
                        return;
                      }
                      settings.toggleEmailNotifications(
                        val,
                        uid: auth?.appUser?.uid,
                      );
                    },
                  ),
                  if (hasEmail && !emailVerified)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: const Icon(Icons.verified_outlined, color: AppColors.primary),
                          title: Text(AppLocalizations.of(context)!.verifyEmail,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(AppLocalizations.of(context)!.requiredToReceive,
                              style: TextStyle(fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                          trailing: ElevatedButton(
                            onPressed: () => _startVerification(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(AppLocalizations.of(context)!.verify, style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              _buildSwitchTile(
                context,
                title: AppLocalizations.of(context)!.pushNotifications,
                subtitle: AppLocalizations.of(context)!.receiveInstantAlerts,
                value: settings.pushNotifications,
                onChanged: (val) => settings.togglePushNotifications(
                  val,
                  uid: Provider.of<AuthProvider>(context, listen: false)
                      .appUser
                      ?.uid,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _startVerification(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    // Prefer the Firebase Auth account email; fall back to Firestore copy.
    final email =
        currentAccountEmail(fallback: auth.appUser?.email) ?? '';
    if (email.isEmpty) {
      AppToast.show('No email on this account');
      return false;
    }
    try {
      await EmailVerificationService().requestCode(email);
      if (!context.mounted) return false;
      AppToast.show(AppLocalizations.of(context)!.codeSentToEmail);
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => VerificationDialog(
          email: email,
          onVerified: () => auth.markEmailVerified(),
        ),
      );
      return ok ?? false;
    } on EmailVerificationException catch (e) {
      if (!context.mounted) return false;
      AppToast.show(e.message);
      return false;
    } catch (_) {
      if (!context.mounted) return false;
      AppToast.show(AppLocalizations.of(context)!.codeSendFailed);
      return false;
    }
  }
}
