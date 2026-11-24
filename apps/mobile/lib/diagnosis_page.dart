import 'package:flutter/material.dart';
import 'glass.dart';
import 'journal.dart';
import 'procedures.dart';
import 'ui.dart';
import 'vision.dart';

class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({
    super.key,
    required this.scan,
    required this.journal,
    required this.knowledge,
    required this.refine,
  });

  final Scan scan;
  final Journal journal;
  final Knowledge knowledge;
  final Future<Scan> Function(Offset) refine;

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  late Scan scan = widget.scan;
  String? damage;
  String? material;
  bool machine = false;
  bool ordinary = false;
  bool saving = false;
  bool refining = false;

  Future<void> findAroundPoint() async {
    final point = await Navigator.of(context).push<Offset>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(context.t('Señalar zona', 'Mark an area')),
          ),
          body: PageBody(
            children: [
              GlassCard(
                child: Text(
                  context.t(
                    'Toca la tela cerca del daño. El modelo buscará alrededor de ese punto.',
                    'Tap the fabric near the damage. The model will search around that point.',
                  ),
                ),
              ),
              PhotoPanel(
                photo: scan.photo,
                focus: scan.focus,
                label: context.t(
                  'Foto para señalar el daño',
                  'Photo for marking damage',
                ),
                height: 435,
                onChoose: (point) => Navigator.of(context).pop(point),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t('Cancelar', 'Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || point == null) return;
    setState(() => refining = true);
    try {
      final updated = await widget.refine(point);
      if (mounted) setState(() => scan = updated);
    } catch (_) {
      if (mounted) context.error();
    } finally {
      if (mounted) setState(() => refining = false);
    }
  }

  Future<void> start(Procedure procedure) async {
    if (saving || refining) return;
    setState(() => saving = true);
    try {
      final id = await widget.journal.start(
        diagnosis: scan.toJson(),
        damage: damage!,
        material: material!,
        knowledge: widget.knowledge.version,
        plan: procedure.data,
        photo: scan.photo,
      );
      if (mounted) Navigator.of(context).pop(id);
    } catch (_) {
      if (mounted) context.error();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usable = scan.status == 'candidate' || scan.status == 'uncertain';
    final hasContext =
        ordinary && damage != null && material != null && damage != 'other';
    final plans = hasContext
        ? widget.knowledge.retrieve(
            damage: damage!,
            material: material!,
            machineAvailable: machine,
          )
        : <Procedure>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Diagnóstico', 'Diagnosis'))),
      body: PageBody(
        children: [
          PhotoPanel(
            photo: scan.photo,
            box: scan.box,
            focus: scan.focus,
            label: scanLabel(context, scan.status),
          ),
          GlassCard(
            accent: scan.status == 'candidate',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Glyph(Icons.filter_center_focus_rounded, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        scanLabel(context, scan.status),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  scan.status == 'candidate'
                      ? context.t(
                          'Revisa la zona marcada. Confirma el daño mirando la prenda y el tejido en la etiqueta.',
                          'Inspect the marked area. Confirm the damage on the garment and check the fabric label.',
                        )
                      : usable
                      ? context.t(
                          'Puedes señalar una zona para acotar la búsqueda o identificar el daño manualmente.',
                          'Mark an area to narrow the search or identify the damage manually.',
                        )
                      : context.t(
                          'Vuelve a tomar una foto nítida con iluminación uniforme.',
                          'Retake a sharp photo with even lighting.',
                        ),
                  style: const TextStyle(color: softText),
                ),
                if (scan.score != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      context.t('Detalles del análisis', 'Analysis details'),
                    ),
                    children: [
                      ListTile(
                        title: Text(
                          context.t(
                            'Puntaje sin calibrar ${scan.score!.toStringAsFixed(2)}',
                            'Uncalibrated score ${scan.score!.toStringAsFixed(2)}',
                          ),
                        ),
                        subtitle: Text(scan.model),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (usable)
            OutlinedButton.icon(
              onPressed: saving || refining ? null : findAroundPoint,
              icon: const Icon(Icons.touch_app_outlined),
              label: Text(context.t('Señalar zona', 'Mark an area')),
            ),
          if (scan.focus != null)
            TextButton(
              onPressed: saving || refining
                  ? null
                  : () => setState(() => scan = widget.scan),
              child: Text(
                context.t(
                  'Volver al análisis completo',
                  'Return to full-image analysis',
                ),
              ),
            ),
          if (refining)
            LinearProgressIndicator(
              semanticsLabel: context.t(
                'Buscando en la zona señalada',
                'Searching the marked area',
              ),
            ),
          if (!usable)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t('Volver al escáner', 'Return to scanner')),
            )
          else ...[
            const Divider(),
            Text(
              context.t(
                'Confirma el daño y la tela',
                'Confirm the damage and fabric',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('damage'),
              decoration: InputDecoration(
                labelText: context.t('Daño observado', 'Observed damage'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'hole',
                  child: Text(context.t('Agujero', 'Hole')),
                ),
                DropdownMenuItem(
                  value: 'tear',
                  child: Text(context.t('Desgarro', 'Tear')),
                ),
                DropdownMenuItem(
                  value: 'seam',
                  child: Text(
                    context.t('Costura recta abierta', 'Open straight seam'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(
                    context.t('Otro o sin confirmar', 'Other or unconfirmed'),
                  ),
                ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => damage = value),
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('material'),
              decoration: InputDecoration(
                labelText: context.t('Tela confirmada', 'Confirmed fabric'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'denim',
                  child: Text(context.t('Denim', 'Denim')),
                ),
                DropdownMenuItem(
                  value: 'woven',
                  child: Text(
                    context.t(
                      'Tejido plano no elástico',
                      'Non-stretch woven fabric',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unknown',
                  child: Text(
                    context.t('Otra o desconocida', 'Other or unknown'),
                  ),
                ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => material = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.t('Tengo máquina de coser', 'I have a sewing machine'),
              ),
              value: machine,
              onChanged: saving
                  ? null
                  : (value) => setState(() => machine = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.t(
                  'Es una prenda de uso cotidiano',
                  'This is an everyday garment',
                ),
              ),
              subtitle: Text(
                context.t(
                  'Excluye prendas de protección y equipo técnico.',
                  'Exclude protective garments and technical equipment.',
                ),
              ),
              value: ordinary,
              onChanged: saving
                  ? null
                  : (value) => setState(() => ordinary = value ?? false),
            ),
            if (ordinary && damage != null && material != null && plans.isEmpty)
              Text(
                context.t(
                  'No hay un procedimiento compatible con estos datos.',
                  'There is no compatible procedure for this information.',
                ),
              ),
            if (plans.isNotEmpty)
              Text(
                context.t(
                  'Procedimientos compatibles',
                  'Compatible procedures',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            for (final plan in plans)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title(context.language),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(plan.tools(context.language)),
                    SourceLink(plan: plan),
                    FilledButton(
                      onPressed: saving || refining ? null : () => start(plan),
                      child: Text(
                        context.t('Iniciar reparación', 'Start repair'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
