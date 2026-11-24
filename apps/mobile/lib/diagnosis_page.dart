import 'package:flutter/material.dart';
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
  });

  final Scan scan;
  final Journal journal;
  final Knowledge knowledge;

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  String? damage;
  String? material;
  bool machine = false;
  bool ordinary = false;
  bool saving = false;

  Future<void> start(Procedure procedure) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final id = await widget.journal.start(
        diagnosis: widget.scan.toJson(),
        damage: damage!,
        material: material!,
        knowledge: widget.knowledge.version,
        plan: procedure.data,
        photo: widget.scan.photo,
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
    final scan = widget.scan;
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
            label: scanLabel(context, scan.status),
          ),
          Text(
            scanLabel(context, scan.status),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (scan.score != null)
            Text(
              context.t(
                'Puntaje del modelo ${scan.score!.toStringAsFixed(2)} · sin calibrar',
                'Model score ${scan.score!.toStringAsFixed(2)} · uncalibrated',
              ),
            ),
          Text(
            scan.status == 'candidate'
                ? context.t(
                    'La caja marca una zona candidata. Confirma visualmente el daño y consulta la etiqueta de la prenda.',
                    'The box marks a candidate region. Confirm the damage visually and check the garment label.',
                  )
                : usable
                ? context.t(
                    'La foto no aporta evidencia suficiente para localizar un agujero. Puedes identificar el daño manualmente.',
                    'The photo gives insufficient evidence to locate a hole. You can identify the damage manually.',
                  )
                : context.t(
                    'Vuelve a tomar una foto nítida con iluminación uniforme.',
                    'Retake a sharp photo with even lighting.',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                        onPressed: saving ? null : () => start(plan),
                        child: Text(
                          context.t('Iniciar reparación', 'Start repair'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
