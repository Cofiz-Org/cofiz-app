import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/lock_state_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../auth/create_pin_screen.dart';
import '../../widgets/app_toast.dart';

class PinLockSettingsScreen extends StatefulWidget {
  const PinLockSettingsScreen({super.key});
  @override
  State<PinLockSettingsScreen> createState() => _PinLockSettingsScreenState();
}

class _PinLockSettingsScreenState extends State<PinLockSettingsScreen> {
  bool? _hasPin;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHasPin();
  }

  Future<void> _loadHasPin() async {
    final lsp = context.read<LockStateProvider>();
    final has = await lsp.pinService
        .hasPin(uid: context.read<AuthProvider>().user?.uid);
    if (mounted) setState(() { _hasPin = has; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final lsp = context.read<LockStateProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.pinLock, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary))),
              if (!_loading) ...[
                _Tile(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.setPin,
                  subtitle: _hasPin == true ? 'PIN is set' : l10n.pinLockSubtitle,
                  enabled: _hasPin != true,
                  onTap: _hasPin != true
                      ? () async {
                          final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreatePinScreen()));
                          if (ok == true && context.mounted) _loadHasPin();
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                _Tile(
                  icon: Icons.edit_outlined,
                  title: l10n.changePin,
                  subtitle: AppLocalizations.of(context)!.requiresCurrentPin,
                  enabled: _hasPin == true,
                  onTap: _hasPin == true
                      ? () async {
                          final oldOk = await _promptCurrentPin(context);
                          if (oldOk == null) return;
                          if (context.mounted) {
                            final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreatePinScreen()));
                            if (ok == true && context.mounted) _loadHasPin();
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                _Tile(
                  icon: Icons.lock_clock_rounded,
                  title: l10n.lockNow,
                  subtitle: l10n.lockAfter2Min,
                  onTap: () {
                    lsp.lock();
                    AppToast.show('Locked', success: true);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.lockAfter2Min, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary))),
                    ],
                  ),
                ),
              ],
            ],
          ),
    );
  }

  Future<String?> _promptCurrentPin(BuildContext context) async {
    final ctrl = List.generate(6, (_) => TextEditingController());
    final focus = List.generate(6, (_) => FocusNode());
    String? error;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    for (int i = 0; i < 6; i++) {
      focus[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
          if (ctrl[i].text.isEmpty && i > 0) {
            ctrl[i - 1].clear();
            focus[i - 1].requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          Future<void> submit() async {
            final pin = ctrl.map((c) => c.text).join();
            if (pin.length != 6) return;
            final ok = await context
                .read<LockStateProvider>()
                .pinService
                .verifyPin(pin,
                    uid: context.read<AuthProvider>().user?.uid);
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.pop(ctx, pin);
            } else {
              setSt(() => error = AppLocalizations.of(context)!.pinIncorrect);
            }
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(AppLocalizations.of(context)!.enterCurrentPin),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                      child: SizedBox(
                        width: 40,
                        height: 56,
                      child: TextField(
                        controller: ctrl[i],
                        focusNode: focus[i],
                        maxLength: 1,
                        obscureText: true,
                        obscuringCharacter: '*',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                          contentPadding: const EdgeInsets.only(left: 2),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty && i < 5) focus[i + 1].requestFocus();
                          if (i == 5 && ctrl.every((c) => c.text.isNotEmpty)) submit();
                        },
                      ),
                      ),
                    );
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: submit,
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          );
        });
      },
    );
    for (final c in ctrl) { c.dispose(); }
    for (final f in focus) { f.dispose(); }
    return result;
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, this.enabled = true, this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
