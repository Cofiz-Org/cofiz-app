import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/debt_model.dart';
import '../../../core/providers/debt_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/custom_header.dart';
import '../../widgets/eth_date_picker_dialog.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/sync_outbox_banner.dart';

class AllDebtsScreen extends StatefulWidget {
  const AllDebtsScreen({super.key, this.highlightDebtId});
  final String? highlightDebtId;
  @override
  State<AllDebtsScreen> createState() => _AllDebtsScreenState();
}

class _AllDebtsScreenState extends State<AllDebtsScreen> {
  DateTime? _selectedDate;
  final Map<String, GlobalKey> _tileKeys = {};
  bool _didReveal = false;

  void _revealHighlight() {
    final id = widget.highlightDebtId;
    if (id == null || _didReveal) return;
    final ctx = _tileKeys[id]?.currentContext;
    if (ctx == null) return;
    _didReveal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        alignment: 0.2,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DebtProvider>().initialize();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final provider = Provider.of<DebtProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final DateTime? picked;
    if (settings.calendarType == CalendarType.ethiopian) {
      picked = await showEthDatePicker(
        context: context,
        initialDate: _selectedDate ?? now,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
      );
    } else {
      picked = await showThemedDatePicker(
        context: context,
        initialDate: _selectedDate ?? now,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
      );
    }
    if (picked != null) {
      setState(() => _selectedDate = picked);
      provider.loadDebtsForDay(picked);
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    Provider.of<DebtProvider>(context, listen: false).clearDayFilter();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          CustomHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    Text(
                      l10n.debts,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.totalOpenDebt,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const OfflineIndicator(),
          Expanded(
            child: Consumer<DebtProvider>(
              builder: (context, provider, _) {
                _revealHighlight();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.totalOpenDebt,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.currency} ${provider.openTotal.formatted}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.debtRecords,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        const SyncOutboxBanner(),
                        if (_selectedDate != null)
                          TextButton.icon(
                            onPressed: _clearDate,
                            icon: const Icon(Icons.close, size: 16),
                            label: Text(
                              DateFormatter.formatDate(_selectedDate!),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          )
                        else
                          IconButton(
                            tooltip: l10n.filterByDate,
                            onPressed: _pickDate,
                            icon: const Icon(Icons.filter_alt),
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (provider.records.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.money_off_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noOpenDebts,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...provider.records.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDebtTile(context, d),
                          )),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtTile(BuildContext context, Debt debt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final creditor = debt.creditorDisplay(
        debt.source == 'purchase' ? debt.collectorName : l10n.admin);
    final highlighted = debt.id == widget.highlightDebtId;
    final isPaid = debt.status == DebtStatus.paid;

    return Container(
      key: _tileKeys.putIfAbsent(debt.id, () => GlobalKey()),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: highlighted
            ? Border.all(color: AppColors.primary, width: 1.6)
            : null,
      ),
      child: Row(
        children: [
          Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.money_off_outlined,
              color: AppColors.primary,
              size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(text: debt.collectorName),
                      const TextSpan(text: ' • '),
                      TextSpan(
                        text: l10n.youOwe(creditor),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Debt.cleanNotes(debt.notes).isNotEmpty
                      ? '${DateFormatter.formatDateTimeNoYear(debt.createdAt)} • ${Debt.cleanNotes(debt.notes)}'
                      : DateFormatter.formatDateTimeNoYear(debt.createdAt),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${l10n.currency} ${debt.forgivenAmount.formatted}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              if (isPaid)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    debt.status.name.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                )
              else
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(l10n.markAsPaid),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(AppLocalizations.of(context)!.cancel)),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.confirm)),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      try {
                        await context.read<DebtProvider>().markPaid(debt.id);
                      } catch (_) {
                        AppToast.show(l10n.failedToMarkPaid);
                      }
                    }
                  },
                  child: Text(l10n.paid,
                      style:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
