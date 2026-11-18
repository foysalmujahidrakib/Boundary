import '../../core/ui.dart';

/// `yyyy-MM-dd`, the format the web app stores in Firestore.
String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// `HH:mm` 24-hour text, as stored by the web `<input type="time">`.
String formatTime24(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? parseTime24(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// Read-only field that opens a date picker. The value is an ISO date string.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? Function(String)? validator;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey('$label|$value'),
      initialValue: value,
      validator: (v) => validator?.call(v ?? ''),
      builder: (state) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: parseIsoDate(value) ?? now,
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) onChanged(formatIsoDate(picked));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(value.isEmpty ? ' ' : value),
          ),
        );
      },
    );
  }
}

/// Read-only field that opens a time picker. The value is `HH:mm`.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? Function(String)? validator;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey('$label|$value'),
      initialValue: value,
      validator: (v) => validator?.call(v ?? ''),
      builder: (state) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime:
                  parseTime24(value) ?? const TimeOfDay(hour: 14, minute: 0),
            );
            if (picked != null) onChanged(formatTime24(picked));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.schedule, size: 18),
            ),
            child: Text(value.isEmpty ? ' ' : value),
          ),
        );
      },
    );
  }
}
