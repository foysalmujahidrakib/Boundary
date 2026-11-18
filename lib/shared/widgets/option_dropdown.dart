import '../../core/ui.dart';

/// A labelled dropdown over `(value, label)` options.
///
/// If [value] is not one of [options] (e.g. legacy data such as an old
/// bowling style) it is appended, so the field never crashes or silently
/// blanks an existing value.
class OptionDropdown extends StatelessWidget {
  const OptionDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
    this.hint,
  });

  final String label;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.$1 == value);
    final all = [
      ...options,
      if (!known && value != null && value!.isNotEmpty) (value!, value!),
    ];
    return DropdownButtonFormField<String>(
      // Rebuild when the value is changed from outside (e.g. editing a row).
      key: ValueKey('$label|$value|${all.length}'),
      initialValue: all.any((o) => o.$1 == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, hintText: hint),
      items: [
        for (final (v, text) in all)
          DropdownMenuItem<String>(
            value: v,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}
