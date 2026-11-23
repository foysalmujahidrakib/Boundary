import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui.dart';
import '../../domain/constants.dart';
import '../../domain/models/team.dart';
import '../../domain/models/tournament.dart';
import '../../shared/widgets/date_time_fields.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/option_dropdown.dart';

/// Create / edit a tournament. Pops with the edited [Tournament] (no id).
class TournamentFormSheet extends StatefulWidget {
  const TournamentFormSheet({
    super.key,
    required this.clubId,
    required this.teams,
    this.initial,
  });

  final String clubId;
  final List<Team> teams;
  final Tournament? initial;

  @override
  State<TournamentFormSheet> createState() => _TournamentFormSheetState();
}

class _TournamentFormSheetState extends State<TournamentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _season = TextEditingController(
    text: widget.initial?.season ?? '',
  );
  late final _venue = TextEditingController(text: widget.initial?.venue ?? '');

  late String _format = _orDefault(widget.initial?.format, 'T20');
  late String _status = _orDefault(
    widget.initial?.status,
    TournamentStatus.planned,
  );
  late String _start = widget.initial?.startDate ?? '';
  late String _end = widget.initial?.endDate ?? '';
  late final Set<String> _teamIds = {...?widget.initial?.teamIds};
  String? _error;

  // Logo: the saved URL, plus a newly picked image that is uploaded on save.
  late String _logoUrl = widget.initial?.logoUrl ?? '';
  Uint8List? _newLogo;
  bool _saving = false;

  ImageProvider? get _logoImage => _newLogo != null
      ? MemoryImage(_newLogo!)
      : (_logoUrl.isNotEmpty ? NetworkImage(_logoUrl) : null);

  static String _orDefault(String? v, String fallback) =>
      (v == null || v.isEmpty) ? fallback : v;

  @override
  void dispose() {
    _name.dispose();
    _season.dispose();
    _venue.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _newLogo = bytes);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final start = parseIsoDate(_start);
    final end = parseIsoDate(_end);
    if (start != null && end != null && end.isBefore(start)) {
      setState(
        () => _error =
            'Enter valid dates. The end date cannot be before the start date.',
      );
      return;
    }
    if (_teamIds.length < 2) {
      setState(() => _error = 'Select at least two participating teams.');
      return;
    }
    if (_teamIds.length > 32) {
      setState(() => _error = 'A tournament can have at most 32 teams.');
      return;
    }

    setState(() => _saving = true);

    // Upload the new logo (if any) and get its public URL.
    var logoUrl = _logoUrl;
    try {
      if (_newLogo != null) {
        final ref = FirebaseStorage.instance.ref(
          'tournament-logos/${widget.clubId}/'
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putData(
          _newLogo!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        logoUrl = await ref.getDownloadURL();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Logo upload failed. Please try again.';
      });
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pop(
      Tournament(
        id: widget.initial?.id ?? '',
        clubId: widget.clubId,
        name: _name.text.trim(),
        season: _season.text.trim(),
        format: _format,
        startDate: _start,
        endDate: _end,
        venue: _venue.text.trim(),
        status: _status,
        logoUrl: logoUrl,
        // Keep the club's team order so public tables are stable.
        teamIds: [
          for (final t in widget.teams)
            if (_teamIds.contains(t.id)) t.id,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return FormSheetFrame(
      title: editing ? 'Edit tournament' : 'Create a tournament',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.fill,
                    backgroundImage: _logoImage,
                    child: _logoImage == null
                        ? const Icon(Icons.emoji_events_outlined)
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _logoImage == null ? 'Add logo (optional)' : 'Change logo',
                    ),
                  ),
                  if (_logoImage != null)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _newLogo = null;
                              _logoUrl = '';
                            }),
                      child: const Text('Remove logo'),
                    ),
                ],
              ),
            ),
            const FieldGap(),
            TextFormField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Tournament name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a tournament name.' : null,
            ),
            const FieldGap(),
            TextFormField(
              controller: _season,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Season'),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Format',
              value: _format,
              options: TournamentFormat.options,
              onChanged: (v) => setState(() => _format = v ?? _format),
            ),
            const FieldGap(),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'Start date',
                    value: _start,
                    onChanged: (v) => setState(() => _start = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(
                    label: 'End date',
                    value: _end,
                    onChanged: (v) => setState(() => _end = v),
                  ),
                ),
              ],
            ),
            const FieldGap(),
            TextFormField(
              controller: _venue,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Venue'),
            ),
            const FieldGap(),
            OptionDropdown(
              label: 'Status',
              value: _status,
              options: TournamentStatus.options,
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 18),
            Text('Participating teams', style: AppText.heading(size: 15)),
            Text(
              'Select at least two teams. ${_teamIds.length} selected.',
              style: AppText.muted(size: 12),
            ),
            const SizedBox(height: 8),
            if (widget.teams.isEmpty)
              const EmptyState('Create teams in the club first.')
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (final team in widget.teams)
                      CheckboxListTile(
                        dense: true,
                        value: _teamIds.contains(team.id),
                        title: Text(team.displayName),
                        subtitle: Text(
                          team.subtitle,
                          style: AppText.muted(size: 11),
                        ),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _teamIds.add(team.id);
                          } else {
                            _teamIds.remove(team.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              NoticeBanner(_error!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Saving…'
                    : (editing ? 'Save changes →' : 'Create tournament →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}