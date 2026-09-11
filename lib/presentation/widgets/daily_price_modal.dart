import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/coffee_types.dart';
import '../../core/providers/daily_price_provider.dart';
import '../../l10n/app_localizations.dart';

Future<double?> showDailyPriceModal(BuildContext context) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DailyPriceSheet(),
  );
}

class _DailyPriceSheet extends StatefulWidget {
  const _DailyPriceSheet();

  @override
  State<_DailyPriceSheet> createState() => _DailyPriceSheetState();
}

class _DailyPriceSheetState extends State<_DailyPriceSheet> {
  late CoffeeType _type;
  final _ctl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = context.read<DailyPriceProvider>();
    _type = p.selectedType;
    final existing = p.priceFor(_type) ?? p.yesterdayPriceFor(_type);
    if (existing != null) _ctl.text = existing.toStringAsFixed(0);
  }

  void _pick(CoffeeType t) {
    final p = context.read<DailyPriceProvider>();
    setState(() {
      _type = t;
      final existing = p.priceFor(t) ?? p.yesterdayPriceFor(t);
      _ctl.text = existing != null ? existing.toStringAsFixed(0) : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<CoffeeType>(
            segments: CoffeeType.values
                .map((t) =>
                    ButtonSegment(value: t, label: Text(_label(l10n, t))))
                .toList(),
            selected: {_type},
            onSelectionChanged: (s) => _pick(s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: const InputDecoration(
              labelText: 'ETB / kg',
              suffixText: 'ETB/kg',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(_ctl.text.trim());
              if (v == null || v <= 0) return;
              await context
                  .read<DailyPriceProvider>()
                  .savePrice(type: _type, price: v);
              if (context.mounted) Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, CoffeeType t) {
    switch (t) {
      case CoffeeType.jenfel:
        return l10n.jenfel;
      case CoffeeType.wet:
        return l10n.wet;
      case CoffeeType.special:
        return l10n.special;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }
}
