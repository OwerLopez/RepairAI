import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'journal.dart';
import 'procedures.dart';
import 'vision.dart';

const ink = Color(0xff202519);
const paper = Color(0xfff7f5ed);
const lime = Color(0xffddec9b);
const moss = Color(0xff394824);

extension Copy on BuildContext {
  int get language => Localizations.localeOf(this).languageCode == 'es' ? 0 : 1;
  String t(String es, String en) => language == 0 ? es : en;

  void error() => ScaffoldMessenger.of(this).showSnackBar(
    SnackBar(
      content: Text(
        t(
          'No se pudo completar la acción. Inténtalo de nuevo.',
          'Could not complete the action. Try again.',
        ),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final journal = Journal();
  final assets = await Future.wait([
    rootBundle.loadString('assets/hole_tile.json'),
    rootBundle.loadString('assets/procedures.json'),
    journal.preference('locale'),
  ]);
  runApp(
    ReparaApp(
      journal: journal,
      vision: Vision(jsonDecode(assets[0]!) as Map<String, dynamic>),
      knowledge: Knowledge(jsonDecode(assets[1]!) as Map<String, dynamic>),
      language: assets[2],
    ),
  );
}

class ReparaApp extends StatefulWidget {
  const ReparaApp({
    super.key,
    required this.journal,
    required this.vision,
    required this.knowledge,
    this.language,
  });

  final Journal journal;
  final Vision vision;
  final Knowledge knowledge;
  final String? language;

  @override
  State<ReparaApp> createState() => _ReparaAppState();
}

class _ReparaAppState extends State<ReparaApp> {
  late String? language = widget.language;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: moss).copyWith(
      surface: paper,
      onSurface: ink,
      primary: moss,
      onPrimary: Colors.white,
      primaryContainer: lime,
      onPrimaryContainer: ink,
    );
    return MaterialApp(
      title: 'ReparaAI',
      debugShowCheckedModeBanner: false,
      locale: language == null ? null : Locale(language!),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: Home(
        journal: widget.journal,
        vision: widget.vision,
        knowledge: widget.knowledge,
        changeLocale: (locale) async {
          await widget.journal.setPreference('locale', locale);
          if (mounted) setState(() => language = locale);
        },
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.journal,
    required this.vision,
    required this.knowledge,
    required this.changeLocale,
  });

  final Journal journal;
  final Vision vision;
  final Knowledge knowledge;
  final Future<void> Function(String) changeLocale;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final picker = ImagePicker();
  bool busy = false;
  bool history = false;
  late Future<List<Map<String, Object?>>> sessions = widget.journal.list();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<XFile?> choose(ImageSource source) => picker.pickImage(
    source: source,
    imageQuality: defaultTargetPlatform == TargetPlatform.iOS ? 96 : null,
    requestFullMetadata: false,
  );

  Future<void> _recover() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final target = await widget.journal.preference('pendingCapture');
      final lost = await picker.retrieveLostData();
      if (!mounted) return;
      await widget.journal.setPreference('pendingCapture', null);
      if (lost.files?.isNotEmpty != true || target == null || !mounted) return;
      final file = lost.files!.first;
      final id = int.tryParse(target);
      if (id != null) {
        await widget.journal.evidence(
          id,
          await Vision.preparePhoto(await file.readAsBytes()),
        );
        if (mounted) await _open(id);
      } else {
        setState(() => busy = true);
        await _diagnose(file);
      }
    } on UnsupportedError {
      // Lost camera results are only supported by the Android plugin.
    } catch (_) {
      if (mounted) context.error();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _capture(ImageSource source) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.journal.setPreference('pendingCapture', 'scan');
      final file = await choose(source);
      await widget.journal.setPreference('pendingCapture', null);
      if (file != null) await _diagnose(file);
    } on PlatformException catch (error) {
      if (!mounted) return;
      if (error.code.contains('access') || error.code.contains('permission')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'Revisa los permisos de cámara o fotos en los ajustes del teléfono.',
                'Check camera or photo access in your phone settings.',
              ),
            ),
          ),
        );
      } else {
        context.error();
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'Elige una imagen JPEG o PNG de hasta 28 MB y 32 megapíxeles.',
                'Choose a JPEG or PNG image up to 28 MB and 32 megapixels.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) context.error();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _diagnose(XFile photo) async {
    if (await photo.length() > 28 * 1024 * 1024) {
      throw const FormatException('Image size');
    }
    final scan = await widget.vision.scan(await photo.readAsBytes());
    if (!mounted) return;
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => DiagnosisPage(
          scan: scan,
          journal: widget.journal,
          knowledge: widget.knowledge,
        ),
      ),
    );
    if (id != null && mounted) await _open(id);
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            RepairPage(id: id, journal: widget.journal, choose: choose),
      ),
    );
    if (mounted) setState(() => sessions = widget.journal.list());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ReparaAI',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.6),
        ),
        actions: [
          IconButton(
            tooltip: context.t('Switch to English', 'Cambiar a español'),
            icon: const Icon(Icons.language_outlined),
            onPressed: () async {
              try {
                await widget.changeLocale(context.language == 0 ? 'en' : 'es');
              } catch (_) {
                if (context.mounted) context.error();
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: history ? 1 : 0,
        onDestinationSelected: busy
            ? null
            : (index) => setState(() => history = index == 1),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.center_focus_weak),
            label: context.t('Escáner', 'Scanner'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: context.t('Historial', 'History'),
          ),
        ],
      ),
      body: history ? _history(context) : _scanner(context),
    );
  }

  Widget _scanner(BuildContext context) => PageBody(
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.center_focus_strong_rounded,
              size: 54,
              color: lime,
            ),
            const SizedBox(height: 28),
            Text(
              context.t('Repara una prenda', 'Repair a garment'),
              style: const TextStyle(
                color: paper,
                fontSize: 36,
                height: 1.06,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.6,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.t(
                'Busca un posible agujero en una foto y sigue un procedimiento de reparación con fuente.',
                'Look for a possible hole in a photo and follow a repair procedure with a source.',
              ),
              style: const TextStyle(color: lime, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('camera'),
        onPressed: busy ? null : () => _capture(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(context.t('Tomar fotografía', 'Take a photo')),
      ),
      OutlinedButton.icon(
        key: const ValueKey('gallery'),
        onPressed: busy ? null : () => _capture(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(context.t('Elegir de la galería', 'Choose from gallery')),
      ),
      if (busy) ...[
        const LinearProgressIndicator(),
        Text(
          context.t('Procesando la fotografía…', 'Processing the photo…'),
          textAlign: TextAlign.center,
        ),
      ],
      Text(
        context.t(
          'Extiende la prenda, ilumínala de manera uniforme y acerca la cámara a la zona dañada. Las fotos y el historial se guardan en este dispositivo al iniciar una reparación.',
          'Lay the garment flat, use even light and frame the damaged area closely. Photos and history are stored on this device when you start a repair.',
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );

  Widget _history(BuildContext context) => FutureBuilder(
    future: sessions,
    builder: (context, snapshot) => PageBody(
      children: [
        Text(
          context.t('Tus reparaciones', 'Your repairs'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (snapshot.hasError)
          OutlinedButton(
            onPressed: () => setState(() => sessions = widget.journal.list()),
            child: Text(
              context.t(
                'Reintentar cargar el historial',
                'Retry loading history',
              ),
            ),
          )
        else if (!snapshot.hasData)
          const LinearProgressIndicator()
        else if (snapshot.data!.isEmpty)
          Text(
            context.t(
              'Las reparaciones que inicies aparecerán aquí.',
              'Repairs will appear here once you start them.',
            ),
          )
        else
          for (final row in snapshot.data!)
            Card(
              child: ListTile(
                title: Text(
                  Procedure(
                    jsonDecode(row['plan'] as String) as Map<String, dynamic>,
                  ).title(context.language),
                ),
                subtitle: Text(
                  '${outcomeLabel(context, row['outcome'] as String?)} · ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(DateTime.parse(row['started'] as String).toLocal())}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(row['id'] as int),
              ),
            ),
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: child),
          ],
        ),
      ),
    ),
  );
}

String scanLabel(BuildContext context, String status) => switch (status) {
  'candidate' => context.t(
    'Posible agujero · experimental',
    'Possible hole · experimental',
  ),
  'resolution' => context.t(
    'Resolución insuficiente',
    'Insufficient resolution',
  ),
  'lighting' => context.t(
    'Iluminación insuficiente o excesiva',
    'Image too dark or too bright',
  ),
  'focus' => context.t(
    'Falta de detalle o enfoque',
    'Insufficient detail or focus',
  ),
  _ => context.t('El modelo se abstuvo', 'The model abstained'),
};

String outcomeLabel(BuildContext context, String? outcome) => switch (outcome) {
  'repaired' => context.t(
    'Reparado según el usuario',
    'Repaired, self-reported',
  ),
  'partial' => context.t('Resultado parcial', 'Partial result'),
  'stopped' => context.t('Interrumpida', 'Stopped'),
  _ => context.t('En progreso', 'In progress'),
};

class PhotoPanel extends StatelessWidget {
  const PhotoPanel({
    super.key,
    required this.photo,
    required this.label,
    this.box,
  });
  final Uint8List photo;
  final String label;
  final Rect? box;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 310,
        child: ColoredBox(
          color: ink,
          child: FittedBox(
            child: CustomPaint(
              foregroundPainter: box == null ? null : _BoxPainter(box!),
              child: Image.memory(photo, excludeFromSemantics: true),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BoxPainter extends CustomPainter {
  const _BoxPainter(this.box);
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );
    final outline = Paint()
      ..color = ink
      ..strokeWidth = size.shortestSide * .013
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, outline);
    canvas.drawRect(
      rect,
      outline
        ..color = lime
        ..strokeWidth = size.shortestSide * .006,
    );
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) => oldDelegate.box != box;
}

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

class SourceLink extends StatelessWidget {
  const SourceLink({super.key, required this.plan});
  final Procedure plan;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () async {
      try {
        if (await launchUrl(plan.url, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Display the same feedback when no browser or handler is available.
      }
      if (context.mounted) context.error();
    },
    icon: const Icon(Icons.open_in_new, size: 16),
    label: Text(plan.source),
  );
}

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
        Text(
          plan.title(context.language),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(outcomeLabel(context, finished)),
        LinearProgressIndicator(
          value: count / steps.length,
          semanticsLabel: context.t('Avance de pasos', 'Step progress'),
        ),
        Text(
          '$count / ${steps.length} ${context.t('pasos completados', 'steps complete')}',
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
          Card(
            child: ListTile(
              leading: Icon(
                index < count
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
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
            PhotoPanel(
              photo: row['before_photo'] as Uint8List,
              label: context.t('Antes', 'Before'),
            ),
            if (after != null) ...[
              const SizedBox(height: 12),
              PhotoPanel(photo: after, label: context.t('Después', 'After')),
            ],
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
