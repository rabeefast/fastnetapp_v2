import 'package:flutter/material.dart';

/// Form-field dropdown that avoids DropdownButtonFormField's deprecated
/// `value` constructor argument and works on older supported Flutter SDKs.
class InitialDropdownFormField<T> extends FormField<T> {
  InitialDropdownFormField({
    super.key,
    required T? initialValue,
    required List<DropdownMenuItem<T>> items,
    required InputDecoration decoration,
    ValueChanged<T?>? onChanged,
  }) : super(
          initialValue: initialValue,
          builder: (field) => InputDecorator(
            decoration: decoration.copyWith(errorText: field.errorText),
            isEmpty: field.value == null,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: field.value,
                isExpanded: true,
                items: items,
                onChanged: (value) {
                  field.didChange(value);
                  onChanged?.call(value);
                },
              ),
            ),
          ),
        );
}
