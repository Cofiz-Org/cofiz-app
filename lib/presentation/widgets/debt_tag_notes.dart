import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/debt_model.dart';
import '../../core/providers/debt_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../screens/transaction/all_debts_screen.dart';
import '../screens/transaction/collector_debts_screen.dart';

class DebtTagChip extends StatelessWidget {
  const DebtTagChip({
    super.key,
    this.transactionId,
    this.fontSize = 11,
  });
  final String? transactionId;
  final double fontSize;

  void _openDebt(BuildContext context) {
    final txId = transactionId;
    Debt? found;
    if (txId != null && txId.isNotEmpty) {
      try {
        final debts = context.read<DebtProvider>().debts;
        for (final d in debts) {
          if (d.purchaseId == txId) {
            found = d;
            break;
          }
        }
      } catch (_) {}
    }
    if (!context.mounted) return;
    final debt = found;
    if (debt == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AllDebtsScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => debt.collectorId == Debt.companyCollectorId
            ? AllDebtsScreen(highlightDebtId: debt.id)
            : CollectorDebtsScreen(
                collectorId: debt.collectorId,
                collectorName: debt.collectorName,
                highlightDebtId: debt.id,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => _openDebt(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.money_off_outlined,
              size: 12,
              color: AppColors.primary,
            ),
            const SizedBox(width: 2),
            Text(
              l10n.debtLabel,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
