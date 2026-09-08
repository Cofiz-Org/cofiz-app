import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/debt_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/providers/debt_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_toast.dart';

class CollectorDebtsScreen extends StatefulWidget {
  const CollectorDebtsScreen(
      {super.key,
      required this.collectorId,
      required this.collectorName,
      this.highlightDebtId});
  final String collectorId;
  final String collectorName;
  final String? highlightDebtId;

  @override
  State<CollectorDebtsScreen> createState() => _CollectorDebtsScreenState();
}

class _CollectorDebtsScreenState extends State<CollectorDebtsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final debts = context
        .watch<DebtProvider>()
        .debtsForCollector(widget.collectorId);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${l10n.collector} • ${widget.collectorName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Builder(
        builder: (context) {
          final open = debts.where((d) => d.status != DebtStatus.paid).toList();
          final paid = debts.where((d) => d.status == DebtStatus.paid).toList();
          final openTotal = open.fold<double>(0, (a, d) => a + d.forgivenAmount);
          _revealHighlight();

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(value: '${l10n.currency} ${openTotal.formatted}', label: l10n.pending, color: AppColors.primary),
                    Container(width: 1, height: 36, color: isDark ? Colors.white12 : Colors.black12),
                    _Stat(value: '${open.length}', label: l10n.pending),
                    _Stat(value: '${paid.length}', label: l10n.done),
                  ],
                ),
              ),
              Expanded(
                child: debts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.money_off_outlined, color: AppColors.primary, size: 32),
                            const SizedBox(height: 16),
                            Text(l10n.noDebtsRecorded, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(l10n.debtsWillAppear,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: debts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final d = debts[i];
                          return _buildDebtTile(context, d);
                        },
                      ),
                ),
              ],
            );
          },
        ),
      );
  }

  Widget _buildDebtTile(BuildContext context, Debt d) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final isOpen = d.status == DebtStatus.open;
    final highlighted = d.id == widget.highlightDebtId;
    final borderColor = highlighted
        ? AppColors.primary
        : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06));
    String linkedNotes = '';
    if (d.purchaseId.isNotEmpty) {
      try {
        final tp = context.watch<TransactionProvider>();
        MoneyTransaction? linked;
        for (final t in tp.allTransactions) {
          if (t.id == d.purchaseId) {
            linked = t;
            break;
          }
        }
        linked ??= () {
          for (final t in tp.workerTransactions) {
            if (t.id == d.purchaseId) return t;
          }
          return null;
        }();
        if (linked != null) linkedNotes = Debt.cleanNotes(linked.notes);
      } catch (_) {}
    }
    return Container(
      key: _tileKeys.putIfAbsent(d.id, () => GlobalKey()),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: borderColor, width: highlighted ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Icon(
            isOpen
                ? Icons.money_off_outlined
                : Icons.check_circle_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.debtLabel}: ${l10n.currency} ${d.forgivenAmount.formatted}',
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.formatDateTimeNoYear(d.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      d.status.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              isOpen ? AppColors.primary : AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ),
                  if (isOpen) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(l10n.markAsPaid),
                              content: Text(l10n.confirmDebtPaid(
                                  widget.collectorName,
                                  d.forgivenAmount.formatted)),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(l10n.cancel)),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(l10n.confirm)),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted) {
                            try {
                              await context
                                  .read<DebtProvider>()
                                  .markPaid(d.id);
                            } catch (_) {
                              AppToast.show(l10n.failedToMarkPaid);
                            }
                          }
                        },
                        child: Text(l10n.paid,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
              if (linkedNotes.isNotEmpty) ...[
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    linkedNotes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color ?? Theme.of(context).textTheme.titleMedium?.color)),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight, fontWeight: FontWeight.w600)),
    ]);
  }
}
