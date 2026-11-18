import 'package:flutter/services.dart';

import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/team.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/option_dropdown.dart';

/// Add / edit a player. Pops with the edited [Player] (no id) when saved.
class PlayerFormSheet extends StatefulWidget {
  const PlayerFormSheet({
    super.key,
    required this.clubId,
    required this.teams,
    this.initial,
    this.preselectedTeamId,
  });

  final String clubId;
  final List<Team> teams;
  final Player? initial;
  final String? preselectedTeamId;

  @override
  State<PlayerFormSheet> createState() => _PlayerFormSheetState();
}

class _PlayerFormSheetState extends State<PlayerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.fullName ?? '',
  );
  late final _jersey = TextEditingController(
    text: widget.initial?.jerseyNumber?.toString() ?? '',
  );

  late String? _teamId = widget.initial?.teamId ?? widget.preselectedTeamId;
  late String _role = _orDefault(widget.initial?.role, PlayerRole.values.first);
  late String _batting = _orDefault(
    widget.initial?.battingStyle,
    BattingStyle.values.first,
  );
  late String _bowling = widget.initial?.bowlingStyle ?? BowlingStyle.none;

  static String _orDefault(String? value, String fallback) =>
      (value == null || value.isEmpty) ? fallback : value;

  @override
  void dispose() {
    _name.dispose();
    _jersey.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final jersey = _jersey.text.trim();
    Navigator.of(context).pop(
      Player(
        id: widget.initial?.id ?? '',
        clubId: widget.clubId,
        fullName: _name.text.trim(),
        teamId: _teamId,
        jerseyNumber: jersey.isEmpty ? null : int.parse(jersey),
        role: _role,
        battingStyle: _batting,
        bowlingStyle: _bowling,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return FormSheetFrame(
      title: editing ? 'Edit player' : 'Register a player',
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
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the player’s name.' : null,
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Team',
              value: _teamId,
              hint: widget.teams.isEmpty
                  ? 'Create a team first'
                  : 'Select a team…',
              options: [for (final t in widget.teams) (t.id, t.displayName)],
              onChanged: (v) => setState(() => _teamId = v),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Choose a team for this player.'
                  : null,
            ),
            const FieldGap(),
            TextFormField(
              controller: _jersey,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(labelText: 'Jersey number'),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Role',
              value: _role,
              options: [for (final r in PlayerRole.values) (r, r)],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Batting style',
              value: _batting,
              options: [for (final s in BattingStyle.values) (s, s)],
              onChanged: (v) => setState(() => _batting = v ?? _batting),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Bowling style',
              value: _bowling,
              options: BowlingStyle.options,
              onChanged: (v) => setState(() => _bowling = v ?? _bowling),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save changes →' : 'Save player →'),
            ),
          ],
        ),
      ),
    );
  }
}
