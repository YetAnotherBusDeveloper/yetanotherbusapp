import 'package:flutter/material.dart';

const _dropdownRadius = 18.0;

class AppDropdownFormField<T> extends StatelessWidget {
  const AppDropdownFormField({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.isExpanded = true,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      isExpanded: isExpanded,
      borderRadius: BorderRadius.circular(_dropdownRadius),
      dropdownColor: colors.surfaceContainerHigh,
      elevation: 8,
      menuMaxHeight: 360,
      icon: const _DropdownIcon(),
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoration.copyWith(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
        border: _border(colors.outlineVariant),
        enabledBorder: _border(colors.outlineVariant),
        focusedBorder: _border(colors.primary, width: 1.6),
      ),
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = true,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_dropdownRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 10, 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: isExpanded,
            borderRadius: BorderRadius.circular(_dropdownRadius),
            dropdownColor: colors.surfaceContainerHigh,
            elevation: 8,
            menuMaxHeight: 360,
            icon: const _DropdownIcon(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

OutlineInputBorder _border(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(_dropdownRadius),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _DropdownIcon extends StatelessWidget {
  const _DropdownIcon();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Icon(
      Icons.keyboard_arrow_down_rounded,
      size: 24,
      color: colors.primary,
    );
  }
}
