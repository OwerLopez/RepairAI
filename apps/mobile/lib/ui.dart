import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'glass.dart';
import 'procedures.dart';

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
    this.focus,
    this.onChoose,
    this.height = 310,
  });
  final Uint8List photo;
  final String label;
  final Rect? box;
  final Offset? focus;
  final ValueChanged<Offset>? onChoose;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: midnight,
          child: FittedBox(
            child: CustomPaint(
              foregroundPainter: box == null && focus == null
                  ? null
                  : _BoxPainter(box, focus),
              child: Builder(
                builder: (context) => GestureDetector(
                  onTapUp: onChoose == null
                      ? null
                      : (tap) {
                          final size = context.size;
                          if (size == null || size.isEmpty) return;
                          onChoose!(
                            Offset(
                              (tap.localPosition.dx / size.width).clamp(0, 1),
                              (tap.localPosition.dy / size.height).clamp(0, 1),
                            ),
                          );
                        },
                  child: Image.memory(photo, excludeFromSemantics: true),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BoxPainter extends CustomPainter {
  const _BoxPainter(this.box, this.focus);
  final Rect? box;
  final Offset? focus;

  @override
  void paint(Canvas canvas, Size size) {
    final thickness = size.shortestSide;
    if (focus case final point?) {
      final center = Offset(point.dx * size.width, point.dy * size.height);
      canvas.drawCircle(
        center,
        thickness * .028,
        Paint()
          ..color = const Color(0xffa6bbff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness * .005,
      );
    }
    if (box case final region?) {
      final rect = Rect.fromLTRB(
        region.left * size.width,
        region.top * size.height,
        region.right * size.width,
        region.bottom * size.height,
      );
      final outline = Paint()
        ..color = midnight
        ..strokeWidth = thickness * .014
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, outline);
      canvas.drawRect(
        rect,
        outline
          ..color = ice
          ..strokeWidth = thickness * .007,
      );
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) =>
      oldDelegate.box != box || oldDelegate.focus != focus;
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

class PhotoComparison extends StatefulWidget {
  const PhotoComparison({super.key, required this.before, required this.after});
  final Uint8List before;
  final Uint8List after;

  @override
  State<PhotoComparison> createState() => _PhotoComparisonState();
}

class _PhotoComparisonState extends State<PhotoComparison> {
  double position = .5;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.t('Comparar antes y después', 'Compare before and after'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 252,
          child: LayoutBuilder(
            builder: (context, bounds) {
              Widget photo(Uint8List bytes, String label) => Image.memory(
                bytes,
                width: bounds.maxWidth,
                height: 252,
                fit: BoxFit.contain,
                semanticLabel: label,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: midnight),
                  photo(widget.after, context.t('Después', 'After')),
                  ClipRect(
                    clipper: _ComparisonClip(position),
                    child: ColoredBox(
                      color: midnight,
                      child: photo(widget.before, context.t('Antes', 'Before')),
                    ),
                  ),
                  if (position > 0 && position < 1)
                    Positioned(
                      left: bounds.maxWidth * position - 1,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(
                        color: ice,
                        child: SizedBox(width: 2),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      Semantics(
        label: context.t(
          'Control de comparación de fotos',
          'Photo comparison control',
        ),
        child: Slider(
          value: position,
          semanticFormatterCallback: (value) => context.t(
            '${(value * 100).round()} por ciento de la foto anterior',
            '${(value * 100).round()} percent of the before photo',
          ),
          onChanged: (value) => setState(() => position = value),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => setState(() => position = 1),
            child: Text(context.t('Antes', 'Before')),
          ),
          TextButton(
            onPressed: () => setState(() => position = 0),
            child: Text(context.t('Después', 'After')),
          ),
        ],
      ),
    ],
  );
}

class _ComparisonClip extends CustomClipper<Rect> {
  const _ComparisonClip(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_ComparisonClip oldClipper) =>
      oldClipper.fraction != fraction;
}
