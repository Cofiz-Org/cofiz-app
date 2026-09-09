import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/update_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class ForceUpdateGate extends StatelessWidget {
  const ForceUpdateGate({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final updater = context.watch<UpdateProvider>();
    final release = updater.release!;
    final theme = Theme.of(context);
    final notes = release.notes.trim();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update_outlined,
                        size: 56, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      l10n.updateRequired,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.version(updater.currentVersion)} → ${l10n.latestVersion(release.version)}',
                      style: const TextStyle(
                          color: AppColors.textMutedDark, fontSize: 12),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(notes, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    if (updater.status == UpdateStatus.downloading) ...[
                      LinearProgressIndicator(
                        value:
                            updater.progress > 0 ? updater.progress : null,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.downloadingUpdate} ${(updater.progress * 100).round()}%',
                        style: const TextStyle(
                            color: AppColors.textMutedDark, fontSize: 12),
                      ),
                    ] else if (updater.status == UpdateStatus.ready) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('forceInstall'),
                          onPressed: updater.retryReadyInstall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(l10n.installNow),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('forceStart'),
                          onPressed: updater.downloadAndInstall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(l10n.updateAction),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
