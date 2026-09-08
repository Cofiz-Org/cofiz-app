import 'package:flutter/material.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.isDark = false,
  });
  final TextEditingController controller;
  final bool isDark;

  @override
  State<PhoneField> createState() => PhoneFieldState();
}

class PhoneFieldState extends State<PhoneField> {
  String? get e164 {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) return null;
    final normalized = normalizeE164(raw);
    return isValidE164(normalized) ? normalized : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        keyboardType: TextInputType.phone,
        style: TextStyle(
          fontSize: 15,
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.phoneExample,
          labelStyle: TextStyle(
            color: widget.isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
          prefixIcon: const Icon(Icons.phone, size: 20, color: AppColors.primary),
          prefixText: '+251 ',
          prefixStyle: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: widget.isDark ? theme.cardColor : Colors.white,
          contentPadding: const EdgeInsets.all(16),
          errorStyle: const TextStyle(fontSize: 12),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'Phone is required';
          }
          return e164 == null ? 'Enter a valid Ethiopian phone (e.g. 0911234567)' : null;
        },
      ),
    );
  }
}
