import '../../../core/ui.dart';
import '../../../domain/models/cricket_match.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/option_dropdown.dart';
import '../match_session_controller.dart';

/// Pick the batting side, the opening pair and the opening bowler
/// (`#inningsForm` in the web scorer).
class InningsSetupCard extends StatefulWidget {
  const InningsSetupCard({
    super.key,
    required this.controller,
    required this.inningsNumber,
    required this.forcedBattingTeamId,
    required this.busy,
    required this.onStart,
  });

  final MatchSessionController controller;
  final int inningsNumber;

  /// In the second innings the side that bowled first must bat.
  final String? forcedBattingTeamId;
  final bool busy;
  final Future<void> Function({
    required String battingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  })
  onStart;

  @override
  State<InningsSetupCard> createState() => _InningsSetupCardState();
}

class _InningsSetupCardState extends State<InningsSetupCard> {
  final _formKey = GlobalKey<FormState>();
  late String? _batting = widget.forcedBattingTeamId ?? _tossBattingSide();
  String? _striker;
  String? _nonStriker;
  String? _bowler;

  /// Suggest who bats first from the toss, if it was recorded.
  String? _tossBattingSide() {
    final CricketMatch? m = widget.controller.match;
    if (m == null || m.tossWinnerId == null || m.tossDecision == null) {
      return null;
    }
    final other = m.tossWinnerId == m.teamAId ? m.teamBId : m.teamAId;
    return m.tossDecision == 'bat' ? m.tossWinnerId : other;
  }

  String? get _bowling {
    final m = widget.controller.match!;
    final b = _batting;
    if (b == null) return null;
    return b == m.teamAId ? m.teamBId : m.teamAId;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final match = c.match!;
    final batters = c.playersOf(_batting);
    final bowlers = c.playersOf(_bowling);

    return SectionCard(
      eyebrow: 'Innings setup',
      title: 'Start ${widget.inningsNumber == 1 ? 'first' : 'second'} innings',
      subtitle:
          'Choose the batting team, then select the opening batters and bowler.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OptionDropdown(
              label: 'Batting team',
              value: _batting,
              hint: 'Select a team…',
              options: [
                for (final id in [match.teamAId, match.teamBId])
                  if (widget.forcedBattingTeamId == null ||
                      widget.forcedBattingTeamId == id)
                    (id, c.teamName(id)),
              ],
              onChanged: (v) => setState(() {
                _batting = v;
                _striker = _nonStriker = _bowler = null;
              }),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Choose the batting team.' : null,
            ),
            if (_bowling != null) ...[
              const SizedBox(height: 6),
              Text(
                'Bowling: ${c.teamName(_bowling)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OptionDropdown(
              label: 'Opening striker',
              value: _striker,
              hint: batters.isEmpty
                  ? 'No players in this team'
                  : 'Select a batter…',
              options: [for (final p in batters) (p.id, p.fullName)],
              onChanged: (v) => setState(() => _striker = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Choose the striker.' : null,
            ),
            const SizedBox(height: 12),
            OptionDropdown(
              label: 'Opening non-striker',
              value: _nonStriker,
              hint: 'Select a batter…',
              options: [for (final p in batters) (p.id, p.fullName)],
              onChanged: (v) => setState(() => _nonStriker = v),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Choose the non-striker.';
                if (v == _striker) return 'Must differ from the striker.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            OptionDropdown(
              label: 'Opening bowler',
              value: _bowler,
              hint: bowlers.isEmpty
                  ? 'No players in this team'
                  : 'Select a bowler…',
              options: [for (final p in bowlers) (p.id, p.fullName)],
              onChanged: (v) => setState(() => _bowler = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Choose the bowler.' : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: widget.busy
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      await widget.onStart(
                        battingTeamId: _batting!,
                        strikerId: _striker!,
                        nonStrikerId: _nonStriker!,
                        bowlerId: _bowler!,
                      );
                    },
              child: Text(widget.busy ? 'Starting…' : 'Start innings →'),
            ),
          ],
        ),
      ),
    );
  }
}
