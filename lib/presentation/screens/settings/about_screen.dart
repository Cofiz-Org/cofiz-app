import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/update_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/background_pattern.dart';
import '../../../l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _termsOfService = """
Cofiz Terms of Service

1. What Cofiz does
Cofiz helps businesses record purchases, distributions, expenses, income, and debts, and manage collectors and roles.

2. Your account
You sign in with your phone number via WhatsApp or Telegram one-time codes, or a 6-digit app PIN you set. Keep your device and PIN private. You are responsible for activity under your account.

3. Your data
Business records you enter belong to your business. An administrator of your workspace can view and manage workspace data, including your activity.

4. Acceptable use
Use Cofiz only for lawful business record-keeping. Do not misuse one-time codes, share PINs, or attempt to access other workspaces.

5. Availability
Cofiz works offline and syncs when a connection is available. Sync and push notifications require internet access and may be delayed.

6. Changes and contact
We may update these terms as the app evolves. Questions: contact support below.
""";

  static const String _privacyPolicy = """
Cofiz Privacy Policy

1. Data we store
Account data (name, phone, role, company), business records (transactions, expenses, income, debts), app preferences, and device push tokens. Receipt photos you attach are stored for your records.

2. How data is used
To run the app: sign-in, record-keeping, reports, reminders, and notifications. One-time login codes are single-use and expire within minutes.

3. Sharing
Workspace admins can see workspace business data. We do not sell personal data. Login codes travel over WhatsApp/Telegram and push notifications over Google FCM, subject to their policies.

4. Security
Sessions use Firebase authentication; mismatched or expired sessions are signed out automatically. Repeated wrong PIN entries trigger cooldowns and, after 5 failures, sign-out.

5. Retention and deletion
Records persist while your workspace exists. Ask your administrator about correction or deletion of your data.

6. Contact
For privacy questions or requests, contact support below.
""";

  void _showContentDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.close ?? 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'kemalnatanim@gmail.com',
      query: 'subject=Cofiz Support',
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (_) {}
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.aboutCofiz ?? 'About Cofiz'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          const BackgroundPattern(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Image.asset(
                  'assets/icon-bgless.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cofiz',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<UpdateProvider>(
                  builder: (context, updater, _) => Text(
                    AppLocalizations.of(context)!.version(
                        updater.currentVersion.isNotEmpty
                            ? updater.currentVersion
                            : '…'),
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildSection(context, AppLocalizations.of(context)!.legal),
                _buildTile(
                  context,
                  AppLocalizations.of(context)?.termsOfService ??
                      'Terms of Service',
                  Icons.description_outlined,
                  () => _showContentDialog(
                      context,
                      AppLocalizations.of(context)?.termsOfService ??
                          'Terms of Service',
                      _termsOfService),
                ),
                _buildTile(
                  context,
                  AppLocalizations.of(context)?.privacyPolicy ??
                      'Privacy Policy',
                  Icons.privacy_tip_outlined,
                  () => _showContentDialog(
                      context,
                      AppLocalizations.of(context)?.privacyPolicy ??
                          'Privacy Policy',
                      _privacyPolicy),
                ),
                const SizedBox(height: 24),
                _buildSection(context, AppLocalizations.of(context)!.support),
                _buildTile(
                  context,
                  'Telegram @phnatanim',
                  Icons.send_outlined,
                  () => _launchUrl('https://t.me/phnatanim'),
                ),
                _buildTile(
                  context,
                  'kemalnatanim@gmail.com',
                  Icons.email_outlined,
                  () => _launchEmail(),
                ),
                _buildTile(
                  context,
                  AppLocalizations.of(context)?.visitWebsite ?? 'Visit Website',
                  Icons.language,
                  () => _launchUrl('https://cofiz.com'),
                ),
                const SizedBox(height: 40),
                Text(
                  AppLocalizations.of(context)?.copyright ??
                      '© 2026 Cofiz app. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMutedDark,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary, size: 24),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
