import 'package:flutter/services.dart';

import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/cricket_match.dart';
import '../../domain/models/team.dart';
import '../../domain/models/tournament.dart';
import '../../shared/widgets/date_time_fields.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/option_dropdown.dart';

/// Schedule / edit a fixture. Pops with the edited [CricketMatch] (no id).
class MatchFormSheet extends StatefulWidget {
  const MatchFormSheet({
    super.key,
    required this.clubId,
    required this.teams,
    required this.tournaments,
    this.initial,
  });

  final String clubId;
  final List<Team> teams;
  final List<Tournament> tournaments;
  final CricketMatch? initial;

  @override
  State<MatchFormSheet> createState() => _MatchFormSheetState();
}

class _MatchFormSheetState extends State<MatchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _venue = TextEditingController(text: widget.initial?.venue ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late final _overs = TextEditingController(
    text: (widget.initial?.overs ?? 20).toString(),
  );

  late String? _tournamentId = widget.initial?.tournamentId;
  late String? _teamA = widget.initial?.teamAId;
  late String? _teamB = widget.initial?.teamBId;
  late String _date = widget.initial?.matchDate ?? '';
  late String _time = widget.initial?.startTime ?? '';
  late String _format = _orDefault(widget.initial?.format, MatchFormat.t20);
  late String _status = _orDefault(
    widget.initial?.status,
    MatchStatus.scheduled,
  );
  late String _tossWinner = widget.initial?.tossWinnerId ?? '';
  late String _tossDecision = widget.initial?.tossDecision ?? '';
  String? _error;

  static String _orDefault(String? v, String fallback) =>
      (v == null || v.isEmpty) ? fallback : v;

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _notes.dispose();
    _overs.dispose();
    super.dispose();
  }

  List<(String, String)> get _teamOptions => [
    for (final t in widget.teams) (t.id, t.displayName),
  ];

  void _save() {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final a = _teamA;
    final b = _teamB;
    if (a == null || b == null || a == b) {
      setState(() => _error = 'Choose two different teams.');
      return;
    }
    final overs = int.tryParse(_overs.text.trim());
    if (_date.isEmpty ||
        _time.isEmpty ||
        _venue.text.trim().isEmpty ||
        overs == null ||
        overs < 1 ||
        overs > 100) {
      setState(
        () => _error =
            'Complete the date, time, venue and a valid overs value (1–100).',
      );
      return;
    }
    if (_tossWinner.isNotEmpty && _tossWinner != a && _tossWinner != b) {
      setState(
        () => _error = 'The toss winner must be one of the two playing teams.',
      );
      return;
    }

    Navigator.of(context).pop(
      CricketMatch(
        id: widget.initial?.id ?? '',
        clubId: widget.clubId,
        title: _title.text.trim(),
        tournamentId: _tournamentId,
        teamAId: a,
        teamBId: b,
        matchDate: _date,
        startTime: _time,
        venue: _venue.text.trim(),
        format: _format,
        overs: overs,
        status: _status,
        tossWinnerId: _tossWinner.isEmpty ? null : _tossWinner,
        tossDecision: _tossDecision.isEmpty ? null : _tossDecision,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final tossOptions = [
      ('', 'Not decided'),
      if (_teamA != null) (_teamA!, _nameOf(_teamA!)),
      if (_teamB != null && _teamB != _teamA) (_teamB!, _nameOf(_teamB!)),
    ];

    return FormSheetFrame(
      title: editing ? 'Edit match' : 'Schedule a match',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Match title (optional)',
                hintText: 'e.g. Semi-final 1',
              ),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Tournament (optional)',
              value: _tournamentId ?? '',
              options: [
                ('', 'Friendly / no tournament'),
                for (final t in widget.tournaments) (t.id, t.name),
              ],
              onChanged: (v) => setState(
                () => _tournamentId = (v == null || v.isEmpty) ? null : v,
              ),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Team A',
              value: _teamA,
              hint: 'Select a team…',
              options: _teamOptions,
              onChanged: (v) => setState(() => _teamA = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Choose team A.' : null,
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Team B',
              value: _teamB,
              hint: 'Select a team…',
              options: _teamOptions,
              onChanged: (v) => setState(() => _teamB = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Choose team B.' : null,
            ),
            const FieldGap(),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'Match date',
                    value: _date,
                    onChanged: (v) => setState(() => _date = v),
                    validator: (v) => v.isEmpty ? 'Pick a date.' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimeField(
                    label: 'Start time',
                    value: _time,
                    onChanged: (v) => setState(() => _time = v),
                    validator: (v) => v.isEmpty ? 'Pick a time.' : null,
                  ),
                ),
              ],
            ),
            const FieldGap(),
            TextFormField(
              controller: _venue,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Venue'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the venue.' : null,
            ),
            const FieldGap(),
            Row(
              children: [
                Expanded(
                  child: OptionDropdown(
                    label: 'Format',
                    value: _format,
                    options: MatchFormat.options,
                    onChanged: (v) => setState(() => _format = v ?? _format),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _overs,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Overs per innings',
                    ),
                  ),
                ),
              ],
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Status',
              value: _status,
              options: MatchStatus.options,
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Toss winner',
              value: tossOptions.any((o) => o.$1 == _tossWinner)
                  ? _tossWinner
                  : '',
              options: tossOptions,
              onChanged: (v) => setState(() => _tossWinner = v ?? ''),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Toss decision',
              value: _tossDecision,
              options: TossDecision.options,
              onChanged: (v) => setState(() => _tossDecision = v ?? ''),
            ),
            const FieldGap(),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              NoticeBanner(_error!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save changes →' : 'Save match →'),
            ),
          ],
        ),
      ),
    );
  }

  String _nameOf(String teamId) {
    for (final t in widget.teams) {
      if (t.id == teamId) return t.displayName;
    }
    return 'Team';
  }
}
