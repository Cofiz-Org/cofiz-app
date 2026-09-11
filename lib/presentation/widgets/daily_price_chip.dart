import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/coffee_types.dart';
import '../../core/providers/daily_price_provider.dart';
import '../../l10n/app_localizations.dart';

class DailyPriceChip extends StatelessWidget {
  const DailyPriceChip(
      {super.key, required this.isAdmin, this.onEditRequested});

  final bool isAdmin;
  final VoidCallback? onEditRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prices = context.watch<DailyPriceProvider>();
    final type = prices.selectedType;
    final price = prices.priceFor(type);
    final typeLabel = _typeLabel(l10n, type);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => prices.setSelectedType(_next(type)),
          child: Text(typeLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        const SizedBox(width: 6),
        if (price != null)
          GestureDetector(
            onTap: isAdmin ? onEditRequested : null,
            child: Text('${price.toStringAsFixed(0)}/kg',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          )
        else if (isAdmin)
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            tooltip: l10n?.setDailyPrice ?? 'Set daily price',
            onPressed: onEditRequested,
          )
        else
          Text(l10n?.priceNotSetYet ?? "Today's price not set yet",
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  CoffeeType _next(CoffeeType t) => CoffeeType
      .values[(CoffeeType.values.indexOf(t) + 1) % CoffeeType.values.length];

  String _typeLabel(AppLocalizations? l10n, CoffeeType t) {
    switch (t) {
      case CoffeeType.jenfel:
        return l10n?.jenfel ?? 'Dried';
      case CoffeeType.wet:
        return l10n?.wet ?? 'Wet';
      case CoffeeType.special:
        return l10n?.special ?? 'Special';
    }
  }
}
