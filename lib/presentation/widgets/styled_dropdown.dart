import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StyledDropdown<T> extends FormField<T> {
  StyledDropdown({
    super.key,
    required List<T> values,
    required String Function(T value) label,
    required ValueChanged<T?> onChanged,
    T? value,
    super.validator,
    IconData leading = Icons.filter_list,
    String? hint,
    Widget? Function(T value)? itemLeading,
    double? width,
    bool bordered = false,
    super.autovalidateMode,
  }) : super(
          initialValue: value,
          builder: (state) {
            final theme = Theme.of(state.context);
            final isDark = theme.brightness == Brightness.dark;
            final field = state as _StyledDropdownState<T>;
            Widget bar = Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: bordered
                    ? Border.all(
                        color: Colors.grey.withValues(alpha: 0.35),
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(leading, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<T>(
                        value: state.value,
                        hint: hint == null
                            ? null
                            : Text(
                                hint,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight,
                                ),
                              ),
                        isDense: true,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down,
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight),
                        dropdownColor: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        items: values.map((v) {
                          final lead = itemLeading?.call(v);
                          return DropdownMenuItem<T>(
                            value: v,
                            child: lead == null
                                ? Text(label(v),
                                    overflow: TextOverflow.ellipsis)
                                : Row(
                                    children: [
                                      lead,
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(label(v),
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          field.didChange(v);
                          onChanged(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (width != null) {
              bar = SizedBox(width: width, child: bar);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar,
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 6),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

  @override
  FormFieldState<T> createState() => _StyledDropdownState<T>();
}

class _StyledDropdownState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(FormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != value) {
      didChange(widget.initialValue);
    }
  }
}
