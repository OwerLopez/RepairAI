import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'diagnosis_page.dart';
import 'glass.dart';
import 'impact_widget.dart';
import 'journal.dart';
import 'l10n/strings.dart';
import 'procedures.dart';
import 'repair_page.dart';
import 'services/image_service.dart';
import 'settings_page.dart';
import 'ui.dart';
import 'vision.dart';

/// Primary root screen providing camera capture, repair history, and application settings.
class Home extends StatefulWidget {
  /// Creates the primary [Home] view.
  const Home({
    super.key,
    required this.journal,
    required this.vision,
    required this.knowledge,
    required this.changeLocale,
  });

  /// The SQLite persistence journal for repair sessions and preferences.
  final Journal journal;

  /// Neural vision inference engine.
  final Vision vision;

  /// Repair procedure catalog knowledge base.
  final Knowledge knowledge;

  /// Callback to change the active locale ('es' or 'en').
  final Future<void> Function(String) changeLocale;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final picker = ImagePicker();
  bool busy = false;
  int tabIndex = 0;
  late Future<List<Map<String, Object?>>> sessions = widget.journal.list();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  /// Prompts the user to pick an image from [source] with platform-appropriate quality settings.
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
    final lang = context.language;
    try {
      if (!kIsWeb) {
        await widget.journal.setPreference('pendingCapture', 'scan');
      }
      final file = await choose(source);
      if (!kIsWeb) {
        await widget.journal.setPreference('pendingCapture', null);
      }
      if (file != null) await _diagnose(file);
    } on PlatformException catch (error) {
      if (!mounted) return;
      if (error.code.contains('access') || error.code.contains('permission')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Strings.permissionError(lang))));
      } else {
        context.error();
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Strings.imageSizeFormatError(lang))),
        );
      }
    } catch (_) {
      if (mounted) context.error();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _diagnose(XFile photo) async {
    await ImageService.validateFile(photo);
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

  Future<void> _refreshHistory() async {
    setState(() {
      sessions = widget.journal.list();
    });
    await sessions;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.language;

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
            tooltip: Strings.switchLanguageTooltip(lang),
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
        selectedIndex: tabIndex,
        onDestinationSelected: busy
            ? null
            : (index) => setState(() => tabIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.center_focus_weak),
            label: Strings.scannerTitle(lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: Strings.historyTitle(lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: Strings.settingsTitle(lang),
          ),
        ],
      ),
      body: switch (tabIndex) {
        0 => _scanner(context),
        1 => _history(context),
        _ => SettingsPage(
          journal: widget.journal,
          changeLocale: widget.changeLocale,
          onDataCleared: () {
            setState(() => sessions = widget.journal.list());
          },
        ),
      },
    );
  }

  Widget _scanner(BuildContext context) {
    final lang = context.language;
    return PageBody(
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
                  const Icon(
                    Icons.phonelink_lock_rounded,
                    size: 17,
                    color: ice,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      Strings.worksOffline(lang),
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
                Strings.repairGarment(lang),
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
                Strings.inspectDamageDesc(lang),
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
          label: Text(Strings.takePhoto(lang)),
        ),
        OutlinedButton.icon(
          key: const ValueKey('gallery'),
          onPressed: busy ? null : () => _capture(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(Strings.chooseFromGallery(lang)),
        ),
        if (busy) ...[
          const LinearProgressIndicator(),
          Text(Strings.processingPhoto(lang), textAlign: TextAlign.center),
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
                      Strings.setupPhotoTitle(lang),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Strings.setupPhotoDesc(lang),
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
                label: Text(Strings.downloadApk(lang)),
                icon: const Icon(Icons.download_outlined),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://github.com/OwerLopez/RepairAI/blob/main/research/paper/dist/reparaai-ieee-es.pdf',
                  ),
                ),
                label: Text(Strings.ieeePaper(lang)),
                icon: const Icon(Icons.description_outlined),
              ),
            ],
          ),
      ],
    );
  }

  Widget _history(BuildContext context) {
    final lang = context.language;
    return FutureBuilder<List<Map<String, Object?>>>(
      future: sessions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refreshHistory,
            child: PageBody(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                OutlinedButton(
                  onPressed: () =>
                      setState(() => sessions = widget.journal.list()),
                  child: Text(Strings.retryLoadingHistory(lang)),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snapshot.data!;
        final completedRepairs = list
            .where((row) => row['outcome'] == 'repaired')
            .length;

        return RefreshIndicator(
          onRefresh: _refreshHistory,
          child: PageBody(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (completedRepairs > 0)
                ImpactWidget(completedRepairs: completedRepairs),
              GlassCard(
                child: Row(
                  children: [
                    const Glyph(Icons.history_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        Strings.yourRepairs(lang),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
              ),
              if (list.isEmpty)
                GlassCard(child: Text(Strings.emptyHistory(lang)))
              else
                for (final row in list)
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
                          jsonDecode(row['plan'] as String)
                              as Map<String, dynamic>,
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
      },
    );
  }
}
