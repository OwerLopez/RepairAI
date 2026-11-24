import 'package:flutter/material.dart';
import 'glass.dart';
import 'journal.dart';
import 'ui.dart';

/// Settings and about page for ReparaAI.
class SettingsPage extends StatefulWidget {
  /// Creates the [SettingsPage].
  const SettingsPage({
    super.key,
    required this.journal,
    required this.changeLocale,
    this.onDataCleared,
  });

  /// The database journal instance.
  final Journal journal;

  /// Callback to change the active application locale ('es' or 'en').
  final Future<void> Function(String) changeLocale;

  /// Optional callback invoked when all data has been purged.
  final VoidCallback? onDataCleared;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool deleting = false;

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('¿Borrar todos los datos?', 'Delete all data?')),
        content: Text(
          context.t(
            'Se eliminarán permanentemente todas las reparaciones, imágenes y preferencias guardadas. Esta acción no se puede deshacer.',
            'All saved repairs, images, and preferences will be permanently deleted. This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t('Cancelar', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffc53929),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t('Borrar todo', 'Delete all')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => deleting = true);
      try {
        await widget.journal.deleteAll();
        widget.onDataCleared?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t(
                  'Todos los datos han sido eliminados.',
                  'All data has been deleted.',
                ),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) context.error();
      } finally {
        if (mounted) setState(() => deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = Localizations.localeOf(context).languageCode;

    return PageBody(
      children: [
        // App header & Version
        GlassCard(
          accent: true,
          child: Row(
            children: [
              const Glyph(Icons.settings_suggest_rounded, size: 50),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ReparaAI',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: frost,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.t('Versión', 'Version')} 0.2.0',
                      style: const TextStyle(
                        fontSize: 14,
                        color: ice,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Language selector
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Glyph(Icons.language_rounded, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    context.t('Idioma', 'Language'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'es',
                    label: Text(context.t('Español', 'Spanish')),
                    icon: currentLang == 'es' ? const Icon(Icons.check) : null,
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(context.t('Inglés', 'English')),
                    icon: currentLang == 'en' ? const Icon(Icons.check) : null,
                  ),
                ],
                selected: {currentLang},
                onSelectionChanged: (selected) async {
                  final newLang = selected.first;
                  if (newLang != currentLang) {
                    await widget.changeLocale(newLang);
                  }
                },
              ),
            ],
          ),
        ),

        // About section
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Glyph(Icons.info_outline_rounded, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    context.t('Acerca de', 'About'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.t(
                  'ReparaAI es una herramienta inteligente para el diagnóstico y reparación asistida de prendas textiles mediante visión artificial en el dispositivo.',
                  'ReparaAI is an intelligent tool for offline on-device textile damage screening and guided repair assistance.',
                ),
                style: const TextStyle(color: softText, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('Autores', 'Authors'),
                style: const TextStyle(
                  color: ice,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const _AuthorItem(name: 'Lopez Arela, Ower Frank'),
              const _AuthorItem(name: 'Zegarra Puma, Mauricio Eduardo'),
              const _AuthorItem(name: 'Huamani Chañi, Diego Oswaldo'),
            ],
          ),
        ),

        // Privacy section
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Glyph(Icons.shield_outlined, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    context.t('Privacidad', 'Privacy'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.t(
                  'ReparaAI funciona completamente sin conexión. Tus fotografías y registros de reparación se almacenan de manera local y privada en tu dispositivo.',
                  'ReparaAI operates entirely offline. Your photos and repair history remain private and stored strictly on your local device.',
                ),
                style: const TextStyle(color: softText, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: ice, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t(
                        'Sin envío de fotos a servidores externos',
                        'No photos transmitted to external servers',
                      ),
                      style: const TextStyle(color: softText, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: ice, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t(
                        'Inferencia ONNX ejecutada localmente',
                        'ONNX inference executed locally',
                      ),
                      style: const TextStyle(color: softText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Data management section
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Glyph(Icons.cleaning_services_rounded, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    context.t('Gestión de datos', 'Data management'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.t(
                  'Puedes restablecer la base de datos y eliminar todo el historial y configuraciones guardadas.',
                  'You can reset the database and delete all saved history and preferences.',
                ),
                style: const TextStyle(color: softText, height: 1.4),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffff8080),
                  side: const BorderSide(color: Color(0x66ff8080)),
                ),
                onPressed: deleting ? null : _confirmDeleteAll,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(
                  context.t('Borrar todos los datos', 'Delete all data'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorItem extends StatelessWidget {
  const _AuthorItem({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, size: 18, color: ice),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: frost, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
