import 'package:flutter/material.dart';
import 'glass.dart';
import 'journal.dart';
import 'l10n/strings.dart';
import 'procedures.dart';
import 'ui.dart';
import 'vision.dart';

/// Screen presenting vision diagnosis, candidate bounding boxes, and compatible repairs.
class DiagnosisPage extends StatefulWidget {
  /// Creates the [DiagnosisPage].
  const DiagnosisPage({
    super.key,
    required this.scan,
    required this.journal,
    required this.knowledge,
    required this.refine,
  });

  /// The vision inference scan result.
  final Scan scan;

  /// The database journal instance.
  final Journal journal;

  /// The loaded repair procedure catalog.
  final Knowledge knowledge;

  /// Callback to re-run neural inference around a user-specified focus point.
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

  /// Opens a full-screen view allowing the user to tap and narrow down the defect region.
  Future<void> findAroundPoint() async {
    final lang = context.language;
    final point = await Navigator.of(context).push<Offset>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(Strings.markArea(lang))),
          body: PageBody(
            children: [
              GlassCard(child: Text(Strings.markAreaInstruction(lang))),
              PhotoPanel(
                photo: scan.photo,
                focus: scan.focus,
                label: Strings.photoForMarkingDamage(lang),
                height: 435,
                onChoose: (point) => Navigator.of(context).pop(point),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(Strings.cancel(lang)),
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

  /// Initiates a repair session for [procedure] and persists it into the journal.
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
    final lang = context.language;
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
      appBar: AppBar(title: Text(Strings.diagnosisTitle(lang))),
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
                      ? Strings.candidateHint(lang)
                      : usable
                      ? Strings.uncertainHint(lang)
                      : Strings.rejectedHint(lang),
                  style: const TextStyle(color: softText),
                ),
                if (scan.score != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(Strings.analysisDetails(lang)),
                    children: [
                      ListTile(
                        title: Text(
                          Strings.uncalibratedScore(
                            lang,
                            scan.score!.toStringAsFixed(2),
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
              label: Text(Strings.markArea(lang)),
            ),
          if (scan.focus != null)
            TextButton(
              onPressed: saving || refining
                  ? null
                  : () => setState(() => scan = widget.scan),
              child: Text(Strings.returnToFullAnalysis(lang)),
            ),
          if (refining)
            LinearProgressIndicator(
              semanticsLabel: Strings.searchingMarkedArea(lang),
            ),
          if (!usable)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(Strings.returnToScanner(lang)),
            )
          else ...[
            const Divider(),
            Text(
              Strings.confirmDamageAndFabric(lang),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('damage'),
              decoration: InputDecoration(
                labelText: Strings.observedDamage(lang),
              ),
              items: [
                DropdownMenuItem(
                  value: 'hole',
                  child: Text(Strings.damageHole(lang)),
                ),
                DropdownMenuItem(
                  value: 'tear',
                  child: Text(Strings.damageTear(lang)),
                ),
                DropdownMenuItem(
                  value: 'seam',
                  child: Text(Strings.damageSeam(lang)),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(Strings.damageOther(lang)),
                ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => damage = value),
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('material'),
              decoration: InputDecoration(
                labelText: Strings.confirmedFabric(lang),
              ),
              items: [
                DropdownMenuItem(
                  value: 'denim',
                  child: Text(Strings.fabricDenim(lang)),
                ),
                DropdownMenuItem(
                  value: 'woven',
                  child: Text(Strings.fabricWoven(lang)),
                ),
                DropdownMenuItem(
                  value: 'unknown',
                  child: Text(Strings.fabricUnknown(lang)),
                ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => material = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(Strings.haveSewingMachine(lang)),
              value: machine,
              onChanged: saving
                  ? null
                  : (value) => setState(() => machine = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(Strings.everydayGarment(lang)),
              subtitle: Text(Strings.everydayGarmentDesc(lang)),
              value: ordinary,
              onChanged: saving
                  ? null
                  : (value) => setState(() => ordinary = value ?? false),
            ),
            if (ordinary && damage != null && material != null && plans.isEmpty)
              Text(Strings.noCompatibleProcedures(lang)),
            if (plans.isNotEmpty)
              Text(
                Strings.compatibleProcedures(lang),
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
                      child: Text(Strings.startRepair(lang)),
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
