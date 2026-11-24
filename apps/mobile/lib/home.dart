import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'diagnosis_page.dart';
import 'glass.dart';
import 'journal.dart';
import 'procedures.dart';
import 'repair_page.dart';
import 'ui.dart';
import 'vision.dart';

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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
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
    final bytes = await photo.readAsBytes();
    final scan = await widget.vision.scan(bytes);
    if (!mounted) return;
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => DiagnosisPage(
          scan: scan,
          journal: widget.journal,
          knowledge: widget.knowledge,
          refine: (point) => widget.vision.scan(bytes, focus: point),
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Glyph(Icons.center_focus_strong_rounded, size: 33),
            SizedBox(width: 10),
            Text(
              'ReparaAI',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.6),
            ),
          ],
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
      GlassCard(
        accent: true,
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Glyph(Icons.document_scanner_outlined, size: 55),
                const Spacer(),
                Icon(Icons.phonelink_lock_rounded, size: 17, color: ice),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.t('Funciona sin conexión', 'Works offline'),
                    style: const TextStyle(
                      color: ice,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              context.t('Repara una prenda', 'Repair a garment'),
              style: const TextStyle(
                color: frost,
                fontSize: 36,
                height: 1.06,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.6,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.t(
                'Examina el daño con una foto y sigue una guía compatible con tu prenda.',
                'Inspect the damage with a photo and follow a guide that fits your garment.',
              ),
              style: const TextStyle(
                color: softText,
                fontSize: 16,
                height: 1.4,
              ),
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
      GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Glyph(Icons.light_mode_outlined, size: 36),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Prepara la foto', 'Set up your photo'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'Extiende la prenda y acércate al daño con luz uniforme.',
                      'Lay the garment flat and frame the damage closely in even light.',
                    ),
                    style: const TextStyle(color: softText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (kIsWeb)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: [
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://github.com/OwerLopez/RepairAI/releases/latest/download/ReparaAI-android-arm64.apk',
                ),
              ),
              label: Text(context.t('Descargar APK', 'Download APK')),
              icon: const Icon(Icons.download_outlined),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://github.com/OwerLopez/RepairAI/blob/main/research/paper/dist/reparaai-ieee-es.pdf',
                ),
              ),
              label: Text(context.t('Artículo IEEE', 'IEEE paper')),
              icon: const Icon(Icons.description_outlined),
            ),
          ],
        ),
    ],
  );

  Widget _history(BuildContext context) => FutureBuilder(
    future: sessions,
    builder: (context, snapshot) => PageBody(
      children: [
        GlassCard(
          child: Row(
            children: [
              const Glyph(Icons.history_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t('Tus reparaciones', 'Your repairs'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
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
          GlassCard(
            child: Text(
              context.t(
                'Las reparaciones que inicies aparecerán aquí.',
                'Repairs will appear here once you start them.',
              ),
            ),
          )
        else
          for (final row in snapshot.data!)
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Glyph(
                  row['outcome'] == 'repaired'
                      ? Icons.check_circle_outline
                      : Icons.layers_outlined,
                  size: 36,
                ),
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
