import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'procedures.dart';

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
