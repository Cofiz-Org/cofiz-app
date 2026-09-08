import 'package:flutter/material.dart';
import '../../core/models/debt_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/app_localizations.dart';

String debtSourceWord(AppLocalizations l10n, String source) {
  switch (source) {
    case 'distribution':
      return l10n.distribute;
    case 'expense':
      return l10n.expenses;
    case 'purchase':
    default:
      return l10n.coffeePurchase;
  }
}

class DebtTiedStrip extends StatelessWidget {
  const DebtTiedStrip({super.key, required this.debt, this.onTap});
  final Debt debt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final shortId = debt.purchaseId.length > 6
        ? debt.purchaseId.substring(0, 6)
        : debt.purchaseId;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l10n.tiedTo(debtSourceWord(l10n, debt.source))} • ${l10n.currency} ${debt.totalAmount.formatted}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (shortId.isNotEmpty)
                      Text(
                        '#$shortId',
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
              const Icon(Icons.expand_more,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
