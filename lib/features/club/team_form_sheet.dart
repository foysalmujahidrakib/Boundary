import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/team.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/option_dropdown.dart';

/// Add / edit a team. Pops with the edited [Team] (no id) when saved.
class TeamFormSheet extends StatefulWidget {
  const TeamFormSheet({super.key, required this.clubId, this.initial});

  final String clubId;
  final Team? initial;

  @override
  State<TeamFormSheet> createState() => _TeamFormSheetState();
}

class _TeamFormSheetState extends State<TeamFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late String _category = widget.initial?.category.isNotEmpty ?? false
      ? widget.initial!.category
      : TeamCategory.values.first;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Team(
        id: widget.initial?.id ?? '',
        clubId: widget.clubId,
        name: _name.text.trim(),
        category: _category,
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return FormSheetFrame(
      title: editing ? 'Edit team' : 'Add a team',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Team name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a team name.' : null,
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Category',
              value: _category,
              options: [for (final c in TeamCategory.values) (c, c)],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const FieldGap(),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save changes →' : 'Save team →'),
            ),
          ],
        ),
      ),
    );
  }
}
