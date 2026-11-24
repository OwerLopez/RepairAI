import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'glass.dart';
import 'journal.dart';
import 'procedures.dart';
import 'ui.dart';
import 'vision.dart';

class RepairPage extends StatefulWidget {
  const RepairPage({
    super.key,
    required this.id,
    required this.journal,
    required this.choose,
  });
  final int id;
  final Journal journal;
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.t('Tomar fotografía', 'Take a photo')),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                context.t('Elegir de la galería', 'Choose from gallery'),
              ),
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
      if (await photo.length() > 28 * 1024 * 1024) {
        throw const FormatException('Image size');
      }
      final bytes = await Vision.preparePhoto(await photo.readAsBytes());
      await widget.journal.evidence(widget.id, bytes);
    });
  }

  Future<void> _delete() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('¿Eliminar reparación?', 'Delete this repair?')),
        content: Text(
          context.t(
            'Se eliminarán también sus fotos y notas.',
            'Its photos and notes will also be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t('Eliminar', 'Delete')),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await _save(() => widget.journal.delete(widget.id), remove: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t('Reparación guiada', 'Guided repair')),
    ),
    body: FutureBuilder(
      future: session,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PageBody(
            children: [
              OutlinedButton(
                onPressed: () =>
                    setState(() => session = widget.journal.read(widget.id)),
                child: Text(context.t('Reintentar', 'Try again')),
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

  Widget _details(BuildContext context, Map<String, Object?> row) {
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
                value: count / steps.length,
                semanticsLabel: context.t('Avance de pasos', 'Step progress'),
              ),
              const SizedBox(height: 8),
              Text(
                '$count / ${steps.length} ${context.t('pasos completados', 'steps complete')}',
                style: const TextStyle(color: softText),
              ),
            ],
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            context.t(
              'Materiales, precauciones y fuente',
              'Tools, precautions and source',
            ),
          ),
          children: [
            ListTile(title: Text(plan.tools(context.language))),
            ListTile(
              title: Text(
                context.t(
                  'Retira alfileres al terminar y revisa que no hayas cosido otra capa.',
                  'Remove pins when finished and check that no other garment layer was stitched.',
                ),
              ),
            ),
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
            label: Text(
              context.t(
                'Completar paso ${count + 1}',
                'Complete step ${count + 1}',
              ),
            ),
            icon: const Icon(Icons.check),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(context.t('Diagnóstico y fotos', 'Diagnosis and photos')),
          subtitle: Text(
            '${scanLabel(context, diagnostic['status'] as String)} · ${diagnostic['model']}',
          ),
          children: [
            if (after == null)
              PhotoPanel(
                photo: row['before_photo'] as Uint8List,
                label: context.t('Antes', 'Before'),
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
                  ? context.t('Añadir foto del resultado', 'Add outcome photo')
                  : context.t(
                      'Cambiar foto del resultado',
                      'Replace outcome photo',
                    ),
            ),
          ),
          Text(
            context.t('Registra el resultado', 'Record the outcome'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          DropdownButtonFormField<String>(
            initialValue: outcome,
            decoration: InputDecoration(
              labelText: context.t('Resultado observado', 'Observed outcome'),
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
            decoration: InputDecoration(
              labelText: context.t('Notas opcionales', 'Optional notes'),
            ),
          ),
          FilledButton(
            onPressed: busy || (outcome == 'repaired' && count < steps.length)
                ? null
                : () => _save(
                    () => widget.journal.finish(widget.id, outcome, notes.text),
                  ),
            child: Text(context.t('Guardar resultado', 'Save outcome')),
          ),
        ] else if ((row['notes'] as String).isNotEmpty)
          Text(row['notes'] as String),
        TextButton.icon(
          onPressed: busy ? null : _delete,
          icon: const Icon(Icons.delete_outline),
          label: Text(context.t('Eliminar reparación', 'Delete repair')),
        ),
      ],
    );
  }
}
