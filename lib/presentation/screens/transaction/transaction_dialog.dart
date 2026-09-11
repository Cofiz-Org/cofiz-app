import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/worker_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/constants/coffee_types.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/daily_price_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../core/providers/income_provider.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/models/debt_model.dart';
import '../../../core/providers/debt_provider.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/styled_dropdown.dart';

class TransactionDialog extends StatefulWidget {  final Worker worker;
  final String type; 
  final MoneyTransaction? existing;

  
  final String? overrideReason;

  const TransactionDialog({
    super.key,
    required this.worker,
    required this.type,
    this.existing,
    this.overrideReason,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  CoffeeType? _selectedCoffeeType = CoffeeType.wet;

  bool _isLoading = false;
  File? _receiptImage;
  bool _recordAsDebt = false;
  final _debtAmountController = TextEditingController();

  double _availableCash(TransactionProvider tp, IncomeProvider ip, ExpenseProvider ep) {
    final totalReturned = tp.allTransactions
        .where((t) => t.type.toLowerCase() == 'return')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalDistributed = tp.allTransactions
        .where((t) => t.type.toLowerCase() == 'distribution')
        .fold(0.0, (sum, t) => sum + t.amount);
    final net = totalReturned + ip.totalInvestments + ip.totalSales - totalDistributed - ep.totalExpenses;
    return net;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = existing.amount.toStringAsFixed(2);
      _notesController.text = existing.notes ?? '';
      _selectedCoffeeType = existing.coffeeType == null
          ? CoffeeType.wet
          : CoffeeType.values
              .where((t) => t.name == existing.coffeeType)
              .firstOrNull ??
              CoffeeType.wet;
      if (existing.coffeeWeight != null) {
        _weightController.text = existing.coffeeWeight.toString();
      }
      if (existing.pricePerKg != null) {
        _priceController.text = existing.pricePerKg.toString();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _debtAmountController.dispose();
    super.dispose();
  }

  Widget _debtCard({
    required bool isDark,
    required String title,
    required String? subtitle,
    required double over,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title,
                style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle,
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
            value: _recordAsDebt,
            activeThumbColor: AppColors.primary,
            onChanged: (v) {
              setState(() {
                _recordAsDebt = v;
                if (v) {
                  _debtAmountController.text =
                      over > 0.01 ? over.toStringAsFixed(0) : '';
                }
              });
            },
          ),
          if (_recordAsDebt)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: TextFormField(
                controller: _debtAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: l10n.debtAmount,
                  prefixText: '${AppLocalizations.of(context)!.currency} ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor:
                      isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get title {
    if (widget.existing != null) {
      return AppLocalizations.of(context)!.editTransaction;
    }
    switch (widget.type) {
      case 'distribution':
        return AppLocalizations.of(context)!.distributeMoney;
      case 'return':
        return AppLocalizations.of(context)!.returnMoneyTitle;
      case 'purchase':
        return AppLocalizations.of(context)!.recordPurchase;
      default:
        return AppLocalizations.of(context)!.transaction;
    }
  }

  IconData get icon {
    switch (widget.type) {
      case 'distribution':
        return Icons.add_circle;
      case 'return':
        return Icons.remove_circle;
      case 'purchase':
        return Icons.shopping_cart;
      default:
        return Icons.receipt;
    }
  }

  Color get color {
    const warmOrange = AppColors.primary;
    switch (widget.type) {
      case 'distribution':
        return warmOrange;
      case 'return':
        return warmOrange;
      case 'purchase':
        return warmOrange;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
            AppLocalizations.of(context)!.errorPickingImage(e.toString()));
      }
    }
  }

  void _updateTotalCost() {
    if (widget.type != 'purchase') return;

    final weight = double.tryParse(_weightController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    if (weight > 0 && price > 0) {
      final total = weight * price;
      _amountController.text = total.toStringAsFixed(2);
    } else {
      _amountController.text = '';
    }
    setState(() {}); 
  }

  Widget _buildDailyPriceHint() {
    if (widget.type != 'purchase') return const SizedBox.shrink();
    final type = _selectedCoffeeType;
    if (type == null) return const SizedBox.shrink();
    final dayPrice = context.watch<DailyPriceProvider>().priceFor(type);
    if (dayPrice == null) return const SizedBox.shrink();
    final entered = double.tryParse(_priceController.text.trim());
    final l10n = AppLocalizations.of(context)!;
    final String typeLabel;
    switch (type) {
      case CoffeeType.jenfel:
        typeLabel = l10n.jenfel;
        break;
      case CoffeeType.wet:
        typeLabel = l10n.wet;
        break;
      case CoffeeType.special:
        typeLabel = l10n.special;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today: ${dayPrice.toStringAsFixed(0)}/kg',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (entered != null && entered > dayPrice)
            Text(
              l10n.aboveDailyPriceWarning(
                  dayPrice.toStringAsFixed(0), typeLabel),
              style: const TextStyle(fontSize: 12, color: Colors.amber),
            ),
        ],
      ),
    );
  }

  String _calculateCommission() {
    final weight = double.tryParse(_weightController.text.trim()) ?? 0;
    if (weight <= 0) return '0.00 ETB';

    final commission = weight * widget.worker.commissionRate;
    return '${commission.formattedDecimal} ETB';
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final notes = _notesController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dailyPrices =
        Provider.of<DailyPriceProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final tp = context.read<TransactionProvider>();
    final ip = context.read<IncomeProvider>();
    final ep = context.read<ExpenseProvider>();
    final debtProvider = context.read<DebtProvider>();

    
    
    
    final bool offline = !ConnectivityService().isOnline;
    String? receiptUrl;
    String? localReceiptPath;
    if (_receiptImage != null) {
      if (offline) {
        localReceiptPath = _receiptImage!.path;
      } else {
        receiptUrl =
            await transactionProvider.uploadReceipt(_receiptImage!.path);
        if (receiptUrl == null) {
          
          if (mounted) {
            setState(() => _isLoading = false);
            AppToast.show(transactionProvider.errorMessage ??
                AppLocalizations.of(context)!.failedToUploadReceipt);
          }
          return;
        }
      }
    }

    bool success = false;

    if (widget.existing != null) {
      final existing = widget.existing!;
      final weight = double.tryParse(_weightController.text.trim());
      final price = double.tryParse(_priceController.text.trim());
      final commission = widget.type == 'purchase'
          ? (weight ?? 0) * widget.worker.commissionRate
          : null;

      final updated = MoneyTransaction(
        id: existing.id,
        workerId: existing.workerId,
        workerName: existing.workerName,
        type: existing.type,
        amount: amount,
        notes: notes.isEmpty ? null : notes,
        receiptUrl: receiptUrl ?? existing.receiptUrl,
        createdAt: existing.createdAt,
        createdBy: existing.createdBy,
        approved: existing.approved,
        coffeeType: widget.type == 'purchase'
            ? _selectedCoffeeType?.name
            : existing.coffeeType,
        coffeeWeight:
            widget.type == 'purchase' ? weight : existing.coffeeWeight,
        pricePerKg: widget.type == 'purchase' ? price : existing.pricePerKg,
        commissionAmount:
            widget.type == 'purchase' ? commission : existing.commissionAmount,
      );
      success = await transactionProvider.updateTransaction(updated,
          overrideReason: widget.overrideReason,
          localReceiptPath: localReceiptPath);
    } else {
      switch (widget.type) {
        case 'distribution':
          final avail = _availableCash(tp, ip, ep);
          double? forgiven;
          String? debtNotes = notes.isEmpty ? null : notes;
          if (_recordAsDebt) {
            final debtAmt =
                double.tryParse(_debtAmountController.text.trim());
            if (debtAmt == null || debtAmt <= 0) {
              if (mounted) {
                setState(() => _isLoading = false);
                AppToast.show(AppLocalizations.of(context)!.invalidAmount);
              }
              return;
            }
            if (debtAmt > amount + 0.01) {
              if (mounted) {
                setState(() => _isLoading = false);
                AppToast.show(
                    AppLocalizations.of(context)!.debtExceedsTotal);
              }
              return;
            }
            forgiven = debtAmt;
            debtNotes = notes.isEmpty ? '[Debt: ETB ${forgiven.toStringAsFixed(0)}]' : '$notes [Debt: ETB ${forgiven.toStringAsFixed(0)}]';
          } else if (amount > avail + 0.01) {
            if (mounted) {
              setState(() => _isLoading = false);
              AppToast.show(AppLocalizations.of(context)!.insufficientCompanyCash(avail.toStringAsFixed(0)));
            }
            return;
          }
          final adminName = authProvider.appUser?.displayName ??
              authProvider.user?.displayName ??
              'Admin';
          final distTxId = await transactionProvider.distributeMoneyToWorker(
            workerId: widget.worker.id,
            workerName: widget.worker.name,
            amount: amount,
            createdBy: authProvider.user?.uid ?? 'unknown',
            notes: debtNotes,
            receiptUrl: receiptUrl,
            localReceiptPath: localReceiptPath,
          );
          success = distTxId != null;
          if (success && forgiven != null && forgiven > 0) {
            try {
              final linkNote = 'For ${widget.worker.name}';
              await debtProvider.recordDebtFromPurchase(
                collectorId: Debt.companyCollectorId,
                collectorName: Debt.companyCollectorName,
                purchaseId: distTxId,
                totalAmount: amount,
                coveredAmount: amount - forgiven,
                forgivenAmount: forgiven,
                createdBy: authProvider.user?.uid ?? 'unknown',
                notes: debtNotes == null
                    ? linkNote
                    : '$linkNote • $debtNotes',
                source: 'distribution',
                linkedName: widget.worker.name,
                creditorName: adminName,
              );
            } catch (_) {}
          }
          break;
        case 'return':
          success = await transactionProvider.returnMoneyFromWorker(
            workerId: widget.worker.id,
            workerName: widget.worker.name,
            amount: amount,
            createdBy: authProvider.user?.uid ?? 'unknown',
            notes: notes.isEmpty ? null : notes,
            receiptUrl: receiptUrl,
            localReceiptPath: localReceiptPath,
          );
          break;
        case 'purchase':
          final weight = double.tryParse(_weightController.text.trim());
          final price = double.tryParse(_priceController.text.trim());
          final commission = (weight ?? 0) * widget.worker.commissionRate;
          final dayPrice = _selectedCoffeeType == null
              ? null
              : dailyPrices.priceFor(_selectedCoffeeType!);
          final aboveDayPrice = dayPrice != null &&
              price != null &&
              price > dayPrice;

          final purchaseTxId = await transactionProvider.recordCoffeePurchase(
            workerId: widget.worker.id,
            workerName: widget.worker.name,
            amount: amount,
            createdBy: authProvider.user?.uid ?? 'unknown',
            notes: notes.isEmpty ? null : notes,
            receiptUrl: receiptUrl,
            localReceiptPath: localReceiptPath,
            coffeeType: _selectedCoffeeType?.name,
            weight: weight,
            pricePerKg: price,
            commission: commission,
            dailyPriceAtSale: dayPrice,
            aboveDailyPrice: aboveDayPrice,
          );
          success = purchaseTxId != null;
          break;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context, true);
        AppToast.show(
          widget.existing != null
              ? AppLocalizations.of(context)!.transactionUpdated
              : AppLocalizations.of(context)!.transactionCompleted,
          success: true,
        );
      } else {
        AppToast.show(transactionProvider.errorMessage ??
            AppLocalizations.of(context)!.failedToComplete);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                Icon(icon, color: AppColors.primary, size: 40),

                const SizedBox(height: 16),

                
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineMedium?.color,
                  ),
                ),

                const SizedBox(height: 8),

                
                Text(
                  widget.worker.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ),

                const SizedBox(height: 24),

                if (widget.type != 'purchase') ...[
                  
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!
                          .amountWithCurrency(
                              AppLocalizations.of(context)?.currency ?? 'ETB'),
                      prefixIcon: const Icon(Icons.attach_money,
                          color: AppColors.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.amountIsRequired;
                      }
                      final val = double.tryParse(value);
                      if (val == null || val <= 0) {
                        return AppLocalizations.of(context)!.invalidAmount;
                      }
                      if (widget.type == 'return' &&
                          val > widget.worker.currentBalance) {
                        return AppLocalizations.of(context)!
                            .insufficientBalance;
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  
                  StyledDropdown<CoffeeType>(
                    values: CoffeeType.values,
                    value: _selectedCoffeeType,
                    label: (type) {
                      final l = AppLocalizations.of(context);
                      switch (type) {
                        case CoffeeType.jenfel:
                          return l?.jenfel ?? 'Dried';
                        case CoffeeType.wet:
                          return l?.wet ?? 'Wet';
                        case CoffeeType.special:
                          return l?.special ?? 'Special';
                      }
                    },
                    leading: Icons.category,
                    hint: AppLocalizations.of(context)!.coffeeType,
                    bordered: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedCoffeeType = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return AppLocalizations.of(context)!.selectCoffeeType;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.weightKg,
                            suffixText: 'Kg',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade50,
                          ),
                          onChanged: (val) => _updateTotalCost(),
                          validator: (val) => (val == null || val.isEmpty)
                              ? AppLocalizations.of(context)!.required
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.pricePerKg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade50,
                          ),
                          onChanged: (val) => _updateTotalCost(),
                          validator: (val) => (val == null || val.isEmpty)
                              ? AppLocalizations.of(context)!.required
                              : null,
                        ),
                      ),
                    ],
                  ),
                  _buildDailyPriceHint(),
                  const SizedBox(height: 16),

                  
                  TextFormField(
                    controller: _amountController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.totalCostCalculated,
                      prefixIcon:
                          const Icon(Icons.calculate, color: AppColors.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.grey.shade200,
                    ),
                  ),

                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.workerCommission,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _calculateCommission(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],

                if (widget.existing == null && widget.type == 'distribution') ...[
                  Builder(builder: (context) {
                    final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                    final tp = context.watch<TransactionProvider>();
                    final ip = context.watch<IncomeProvider>();
                    final ep = context.watch<ExpenseProvider>();
                    final avail = _availableCash(tp, ip, ep);
                    final over = amt - avail;
                    return _debtCard(
                      isDark: isDark,
                      title: AppLocalizations.of(context)!.recordExcessAsDebt,
                      subtitle: over > 0.01
                          ? AppLocalizations.of(context)!.recordExcessSubtitle(
                              avail.toStringAsFixed(0), over.toStringAsFixed(0))
                          : null,
                      over: over,
                    );
                  }),
                ],

                const SizedBox(height: 16),

                
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.notesOptional,
                    hintText: AppLocalizations.of(context)!.addNotesHere,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  ),
                ),

                const SizedBox(height: 16),

                
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.camera_alt, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _receiptImage != null
                                ? AppLocalizations.of(context)!.receiptSelected
                                : AppLocalizations.of(context)!.addReceiptPhoto,
                            style: TextStyle(
                              color: _receiptImage != null
                                  ? Colors.green
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                              fontWeight: _receiptImage != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_receiptImage != null)
                          const Icon(Icons.check_circle,
                              color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                if (_receiptImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _receiptImage!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _receiptImage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(AppLocalizations.of(context)!.confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
