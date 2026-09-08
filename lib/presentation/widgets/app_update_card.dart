import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/update_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Pinned update card for the top of the Settings list. Reads
/// [UpdateProvider] only — all network/cache/install logic lives there.
class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({super.key});

  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  bool _notesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Consumer<UpdateProvider>(
      builder: (context, updater, _) {
        switch (updater.status) {
          case UpdateStatus.checking:
          case UpdateStatus.unknown:
            return _shell(
              isDark: isDark,
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.checkingForUpdates,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          case UpdateStatus.upToDate:
            return _shell(
              isDark: isDark,
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.appUpdate,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          updater.currentVersion.isNotEmpty
                              ? '${l10n.version(updater.currentVersion)} · ${l10n.upToDateShort}'
                              : l10n.upToDateShort,
                          style: const TextStyle(
                              color: AppColors.textMutedDark, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('updateCheckAgain'),
                    onPressed: () => updater.checkForUpdates(
                        force: true, userInitiated: true),
                    child: Text(l10n.checkAgain),
                  ),
                ],
              ),
            );
          case UpdateStatus.available:
          case UpdateStatus.downloading:
          case UpdateStatus.ready:
            return _updateAvailable(context, updater, l10n, theme, isDark);
          case UpdateStatus.error:
            return _shell(
              isDark: isDark,
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      color: AppColors.error, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.appUpdate,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          updater.errorMessage ?? l10n.updateCheckFailed,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('updateRetry'),
                    onPressed: () => updater.checkForUpdates(
                        force: true, userInitiated: true),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
        }
      },
    );
  }

  Widget _updateAvailable(
    BuildContext context,
    UpdateProvider updater,
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    final release = updater.release!;
    final downloading = updater.status == UpdateStatus.downloading;
    final ready = updater.status == UpdateStatus.ready;
    final notes = release.notes.trim();

    return _shell(
      isDark: isDark,
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.updateAvailable,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      updater.currentVersion.isNotEmpty
                          ? '${l10n.version(updater.currentVersion)} → ${l10n.latestVersion(release.version)}'
                          : l10n.latestVersion(release.version),
                      style: const TextStyle(
                          color: AppColors.textMutedDark, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.whatsNew,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              _notesExpanded || notes.length <= 180
                  ? notes
                  : '${notes.substring(0, 180)}…',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight),
              maxLines: _notesExpanded ? null : 3,
              overflow: _notesExpanded ? null : TextOverflow.ellipsis,
            ),
            if (notes.length > 180)
              GestureDetector(
                onTap: () =>
                    setState(() => _notesExpanded = !_notesExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _notesExpanded ? l10n.showLess : l10n.showMore,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          if (downloading) ...[
            LinearProgressIndicator(
              value: updater.progress > 0 ? updater.progress : null,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              color: AppColors.primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.downloadingUpdate} ${(updater.progress * 100).round()}%',
                    style: const TextStyle(
                        color: AppColors.textMutedDark, fontSize: 12),
                  ),
                ),
                TextButton(
                  key: const Key('updateCancel'),
                  onPressed: updater.cancelDownload,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ] else if (ready) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('updateInstall'),
                onPressed: updater.retryReadyInstall,
                icon: const Icon(Icons.install_mobile_outlined, size: 18),
                label: Text(l10n.installNow),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Center(
              child: Text(l10n.readyToInstall,
                  style: const TextStyle(
                      color: AppColors.textMutedDark, fontSize: 12)),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const Key('updateStart'),
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
                TextButton(
                  key: const Key('updateDismiss'),
                  onPressed: updater.dismiss,
                  child: Text(l10n.notNow),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shell({
    required bool isDark,
    required Widget child,
    bool highlight = false,
  }) {
    return Container(
      key: const Key('appUpdateCard'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200),
        ),
      ),
      child: child,
    );
  }
}
