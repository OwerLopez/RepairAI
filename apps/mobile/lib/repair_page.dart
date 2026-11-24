import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'glass.dart';
import 'journal.dart';
import 'l10n/strings.dart';
import 'procedures.dart';
import 'services/image_service.dart';
import 'ui.dart';
import 'vision.dart';

/// Screen presenting step-by-step repair guidance, evidence logging, and final outcome recording.
class RepairPage extends StatefulWidget {
  /// Creates the [RepairPage].
  const RepairPage({
    super.key,
    required this.id,
    required this.journal,
    required this.choose,
  });

  /// The unique identifier of this repair session in the database.
  final int id;

  /// The database journal instance.
  final Journal journal;

  /// Callback to capture or select an image file from [ImageSource].
  final Future<XFile?> Function(ImageSource) choose;

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  late Future<Map<String, Object?>> session = widget.journal.read(widget.id);
  final notes = TextEditingController();
  bool busy = false;
  String outcome = 'repaired';

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _save(
    Future<void> Function() operation, {
    bool remove = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      if (!mounted) return;
      if (remove) {
        Navigator.of(context).pop();
      } else {
        setState(() => session = widget.journal.read(widget.id));
      }
    } catch (_) {
      if (mounted) context.error();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _after() async {
    final lang = context.language;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(Strings.takePhoto(lang)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(Strings.chooseFromGallery(lang)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _save(() async {
      await widget.journal.setPreference(
        'pendingCapture',
        widget.id.toString(),
      );
      final photo = await widget.choose(source);
      await widget.journal.setPreference('pendingCapture', null);
      if (photo == null) return;
      await ImageService.validateFile(photo);
      final bytes = await Vision.preparePhoto(await photo.readAsBytes());
      await widget.journal.evidence(widget.id, bytes);
    });
  }

  Future<void> _delete() async {
    final lang = context.language;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Strings.deleteRepairDialogTitle(lang)),
        content: Text(Strings.deleteRepairDialogContent(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(Strings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(Strings.delete(lang)),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await _save(() => widget.journal.delete(widget.id), remove: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.language;
    return Scaffold(
      appBar: AppBar(title: Text(Strings.guidedRepairTitle(lang))),
      body: FutureBuilder(
        future: session,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return PageBody(
              children: [
                OutlinedButton(
                  onPressed: () =>
                      setState(() => session = widget.journal.read(widget.id)),
                  child: Text(Strings.tryAgain(lang)),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _details(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _details(BuildContext context, Map<String, Object?> row) {
    final lang = context.language;
    final plan = Procedure(
      jsonDecode(row['plan'] as String) as Map<String, dynamic>,
    );
    final steps = plan.steps(context.language);
    final count = row['completed_steps'] as int;
    final finished = row['outcome'] as String?;
    final after = row['after_photo'] as Uint8List?;
    final diagnostic =
        jsonDecode(row['diagnosis'] as String) as Map<String, dynamic>;
    return PageBody(
      children: [
        GlassCard(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Glyph(Icons.handyman_outlined),
              const SizedBox(height: 12),
              Text(
                plan.title(context.language),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                outcomeLabel(context, finished),
                style: const TextStyle(color: ice),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: steps.isEmpty ? 0 : count / steps.length,
                semanticsLabel: Strings.stepProgress(lang),
              ),
              const SizedBox(height: 8),
              Text(
                Strings.stepsComplete(lang, count, steps.length),
                style: const TextStyle(color: softText),
              ),
            ],
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(Strings.toolsPrecautionsSource(lang)),
          children: [
            ListTile(title: Text(plan.tools(context.language))),
            ListTile(title: Text(Strings.safetyPrecaution(lang))),
            SourceLink(plan: plan),
          ],
        ),
        for (var index = 0; index < steps.length; index++)
          GlassCard(
            accent: index == count && finished == null,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                index < count
                    ? Icons.check_circle
                    : (index == count
                          ? Icons.play_circle_outline
                          : Icons.radio_button_unchecked),
                color: index <= count ? ice : softText,
              ),
              title: Text('${index + 1}. ${steps[index]}'),
            ),
          ),
        if (finished == null && count < steps.length)
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => _save(() => widget.journal.advance(widget.id, count)),
            label: Text(Strings.completeStep(lang, count + 1)),
            icon: const Icon(Icons.check),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(Strings.diagnosisAndPhotos(lang)),
          subtitle: Text(
            '${scanLabel(context, diagnostic['status'] as String)} · ${diagnostic['model']}',
          ),
          children: [
            if (after == null)
              PhotoPanel(
                photo: row['before_photo'] as Uint8List,
                label: Strings.beforePhotoLabel(lang),
              )
            else
              GlassCard(
                child: PhotoComparison(
                  before: row['before_photo'] as Uint8List,
                  after: after,
                ),
              ),
          ],
        ),
        if (finished == null) ...[
          OutlinedButton.icon(
            onPressed: busy ? null : _after,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              after == null
                  ? Strings.addOutcomePhoto(lang)
                  : Strings.replaceOutcomePhoto(lang),
            ),
          ),
          Text(
            Strings.recordOutcome(lang),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          DropdownButtonFormField<String>(
            initialValue: outcome,
            decoration: InputDecoration(
              labelText: Strings.observedOutcome(lang),
            ),
            items: [
              for (final value in ['repaired', 'partial', 'stopped'])
                DropdownMenuItem(
                  value: value,
                  child: Text(outcomeLabel(context, value)),
                ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => outcome = value!),
          ),
          TextField(
            controller: notes,
            enabled: !busy,
            maxLength: 500,
            decoration: InputDecoration(labelText: Strings.optionalNotes(lang)),
          ),
          FilledButton(
            onPressed: busy || (outcome == 'repaired' && count < steps.length)
                ? null
                : () => _save(
                    () => widget.journal.finish(widget.id, outcome, notes.text),
                  ),
            child: Text(Strings.saveOutcome(lang)),
          ),
        ] else if ((row['notes'] as String).isNotEmpty)
          Text(row['notes'] as String),
        TextButton.icon(
          onPressed: busy ? null : _delete,
          icon: const Icon(Icons.delete_outline),
          label: Text(Strings.deleteRepair(lang)),
        ),
      ],
    );
  }
}
