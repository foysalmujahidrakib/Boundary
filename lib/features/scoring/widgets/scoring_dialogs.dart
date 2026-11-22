import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui.dart';
import '../../../domain/constants.dart';
import '../../../domain/models/innings.dart';
import '../../../domain/models/team.dart';
import '../../../domain/scoring/formatters.dart';
import '../../../domain/scoring/scoring_engine.dart';
import '../../../shared/widgets/option_dropdown.dart';

// ---------------------------------------------------------------- wicket

/// What the scorer entered in the wicket dialog.
class WicketChoice {
  const WicketChoice({
    required this.dismissedBatterId,
    required this.dismissalType,
    required this.incomingBatterId,
  });

  final String dismissedBatterId;
  final String dismissalType;

  /// `null` only for the last wicket (nobody left to come in).
  final String? incomingBatterId;
}

/// The "OUT" dialog (`#wicketModal`).
Future<WicketChoice?> showWicketDialog(
  BuildContext context, {
  required Innings innings,
  required List<Player> players,
}) {
  return showDialog<WicketChoice>(
    context: context,
    builder: (_) => _WicketDialog(innings: innings, players: players),
  );
}

class _WicketDialog extends StatefulWidget {
  const _WicketDialog({required this.innings, required this.players});

  final Innings innings;
  final List<Player> players;

  @override
  State<_WicketDialog> createState() => _WicketDialogState();
}

class _WicketDialogState extends State<_WicketDialog> {
  late String _dismissed = widget.innings.strikerId ?? '';
  String _type = DismissalType.bowled;
  String? _incoming;
  String? _error;

  late final _crease = ScoringEngine.battersAtCrease(
    widget.innings,
    widget.players,
  );
  late final _incomingOptions = ScoringEngine.incomingBatters(
    widget.innings,
    widget.players,
  );

  bool get _lastWicket => widget.innings.wickets >= 9;

  /// Only a run out (or a batter retiring) can end the non-striker's innings.
  bool get _nonStrikerAllowed =>
      _type == DismissalType.runOut || _type == DismissalType.retiredHurt;

  void _setType(String? value) {
    setState(() {
      _type = value ?? _type;
      if (!_nonStrikerAllowed) {
        _dismissed = widget.innings.strikerId ?? _dismissed;
      }
    });
  }

  void _confirm() {
    if (_dismissed.isEmpty) {
      setState(() => _error = 'Choose a batter currently at the crease.');
      return;
    }
    if (!_lastWicket && (_incoming == null || _incoming!.isEmpty)) {
      setState(() => _error = 'Choose the incoming batter.');
      return;
    }
    Navigator.of(context).pop(
      WicketChoice(
        dismissedBatterId: _dismissed,
        dismissalType: _type,
        incomingBatterId: _lastWicket ? null : _incoming,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inn = widget.innings;
    return AlertDialog(
      title: const Text('Wicket'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OptionDropdown(
              label: 'How out',
              value: _type,
              options: DismissalType.options,
              onChanged: _setType,
            ),
            const SizedBox(height: 14),
            Text('Batter out', style: AppText.heading(size: 13)),
            for (final p in _crease)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                enabled: p.id == inn.strikerId || _nonStrikerAllowed,
                leading: Icon(
                  _dismissed == p.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _dismissed == p.id ? AppColors.mint : AppColors.muted,
                ),
                title: Text(
                  p.id == inn.strikerId
                      ? '${p.fullName} (striker)'
                      : '${p.fullName} (non-striker)',
                ),
                onTap: () => setState(() => _dismissed = p.id),
              ),
            const SizedBox(height: 8),
            if (_lastWicket)
              Text(
                'This is the last wicket: the innings will end.',
                style: AppText.muted(size: 12),
              )
            else
              OptionDropdown(
                label: 'Incoming batter',
                value: _incoming,
                hint: _incomingOptions.isEmpty
                    ? 'No batters left'
                    : 'Select a batter…',
                options: [for (final p in _incomingOptions) (p.id, p.fullName)],
                onChanged: (v) => setState(() => _incoming = v),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppText.body(size: 12, color: AppColors.orange),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: AppColors.white,
          ),
          onPressed: _confirm,
          child: const Text('Record wicket'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- extras

/// The numbers a scorer is asked for per extra type.
class _ExtraPrompt {
  const _ExtraPrompt(this.title, this.hint, this.initial, this.min);

  final String title;
  final String hint;
  final int initial;
  final int min;
}

const _prompts = <String, _ExtraPrompt>{
  DeliveryKind.wide: _ExtraPrompt(
    'Wide',
    'Extra runs run, in addition to the 1 run for the wide.',
    0,
    0,
  ),
  DeliveryKind.noBall: _ExtraPrompt(
    'No ball',
    'Runs scored off the bat (the no-ball adds 1 more).',
    0,
    1,
  ),
  DeliveryKind.bye: _ExtraPrompt('Byes', 'Byes run.', 1, 1),
  DeliveryKind.legBye: _ExtraPrompt('Leg byes', 'Leg byes run.', 1, 1),
  DeliveryKind.penalty: _ExtraPrompt(
    'Penalty runs',
    'Penalty runs awarded.',
    5,
    1,
  ),
};

/// Asks for the runs of an extra (`#extrasModal`). Resolves to the number
/// entered, or `null` when cancelled.
Future<int?> showExtrasDialog(BuildContext context, String kind) {
  final prompt = _prompts[kind];
  if (prompt == null) return Future.value(0);
  return showDialog<int>(
    context: context,
    builder: (_) => _ExtrasDialog(prompt: prompt),
  );
}

class _ExtrasDialog extends StatefulWidget {
  const _ExtrasDialog({required this.prompt});

  final _ExtraPrompt prompt;

  @override
  State<_ExtrasDialog> createState() => _ExtrasDialogState();
}

class _ExtrasDialogState extends State<_ExtrasDialog> {
  late final _controller = TextEditingController(
    text: widget.prompt.initial.toString(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < widget.prompt.min || value > 100) {
      setState(
        () => _error = 'Enter a whole number from ${widget.prompt.min} to 100.',
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prompt;
    return AlertDialog(
      title: Text(p.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.hint),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Runs', errorText: _error),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final n in [0, 1, 2, 3, 4, 5, 6])
                if (n >= p.min)
                  ActionChip(
                    label: Text('$n'),
                    onPressed: () => setState(() => _controller.text = '$n'),
                  ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Add')),
      ],
    );
  }
}

// ----------------------------------------------------------- next bowler

/// "Over complete": choose who bowls next (replaces the web `prompt()`).
/// Resolves to a player id, or `null` to cancel the delivery.
Future<String?> showNextBowlerDialog(
  BuildContext context, {
  required Innings innings,
  required List<Player> eligible,
  required int maxOversPerBowler,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SimpleDialog(
      title: const Text('Over complete: next bowler'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Each bowler may bowl up to $maxOversPerBowler overs.',
            style: AppText.muted(size: 12),
          ),
        ),
        for (final p in eligible)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(p.id),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.fullName,
                    style: AppText.body(size: 15, weight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${Fmt.overs(innings.bowlers[p.id]?.legalBalls ?? 0)} ov',
                  style: AppText.muted(size: 12),
                ),
              ],
            ),
          ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel (do not record this ball)',
            style: AppText.body(size: 13, color: AppColors.orange),
          ),
        ),
      ],
    ),
  );
}
