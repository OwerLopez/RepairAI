import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'glass.dart';
import 'l10n/strings.dart';
import 'procedures.dart';

/// Extension on [BuildContext] for convenient localization and feedback.
extension Copy on BuildContext {
  /// Language index: `0` for Spanish (`es`), `1` for English (`en`).
  int get language => Localizations.localeOf(this).languageCode == 'es' ? 0 : 1;

  /// Returns [es] when language is Spanish, or [en] otherwise.
  String t(String es, String en) => language == 0 ? es : en;

  /// Shows a transient error snackbar with standard retry messaging.
  void error() => ScaffoldMessenger.of(
    this,
  ).showSnackBar(SnackBar(content: Text(Strings.actionError(language))));
}

/// Standard responsive container constraining content width with standard padding.
class PageBody extends StatelessWidget {
  /// Creates a responsive [PageBody] with standard vertical item spacing.
  const PageBody({super.key, required this.children, this.physics});

  /// The list of child widgets arranged in the scrollable body.
  final List<Widget> children;

  /// Optional scroll physics for the internal [ListView].
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          physics: physics,
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

/// Localized human-readable label for a vision scan [status].
String scanLabel(BuildContext context, String status) {
  final lang = context.language;
  return switch (status) {
    'candidate' => Strings.scanLabelCandidate(lang),
    'resolution' => Strings.scanLabelResolution(lang),
    'lighting' => Strings.scanLabelLighting(lang),
    'focus' => Strings.scanLabelFocus(lang),
    _ => Strings.scanLabelAbstained(lang),
  };
}

/// Localized human-readable label for a repair [outcome].
String outcomeLabel(BuildContext context, String? outcome) {
  final lang = context.language;
  return switch (outcome) {
    'repaired' => Strings.outcomeRepaired(lang),
    'partial' => Strings.outcomePartial(lang),
    'stopped' => Strings.outcomeStopped(lang),
    _ => Strings.outcomeInProgress(lang),
  };
}

/// Panel widget rendering an image with optional bounding box and focus crosshair overlays.
class PhotoPanel extends StatelessWidget {
  /// Creates a [PhotoPanel] displaying [photo] with optional target overlays.
  const PhotoPanel({
    super.key,
    required this.photo,
    required this.label,
    this.box,
    this.focus,
    this.onChoose,
    this.height = 310,
  });

  /// The JPEG encoded image bytes.
  final Uint8List photo;

  /// Accessibility semantic label describing the photo.
  final String label;

  /// Normalized bounding box coordinates `[left, top, right, bottom]` in [0, 1].
  final Rect? box;

  /// Normalized focus center coordinates `(dx, dy)` in [0, 1].
  final Offset? focus;

  /// Callback triggered when the user taps on the image to select a focus point.
  final ValueChanged<Offset>? onChoose;

  /// Fixed display height of the photo panel.
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

/// Action link button launching the original published procedure URL in an external browser.
class SourceLink extends StatelessWidget {
  /// Creates a [SourceLink] for the given [plan].
  const SourceLink({super.key, required this.plan});

  /// The procedure containing the source attribution and link.
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

/// Interactive before and after photo comparison slider.
class PhotoComparison extends StatefulWidget {
  /// Creates an interactive [PhotoComparison] view comparing [before] and [after] photos.
  const PhotoComparison({super.key, required this.before, required this.after});

  /// Pre-repair image bytes.
  final Uint8List before;

  /// Post-repair outcome image bytes.
  final Uint8List after;

  @override
  State<PhotoComparison> createState() => _PhotoComparisonState();
}

class _PhotoComparisonState extends State<PhotoComparison> {
  double position = .5;

  @override
  Widget build(BuildContext context) {
    final lang = context.language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          Strings.compareBeforeAndAfter(lang),
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
                    photo(widget.after, Strings.afterPhotoLabel(lang)),
                    ClipRect(
                      clipper: _ComparisonClip(position),
                      child: ColoredBox(
                        color: midnight,
                        child: photo(
                          widget.before,
                          Strings.beforePhotoLabel(lang),
                        ),
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
          label: Strings.photoComparisonControl(lang),
          child: Slider(
            value: position,
            semanticFormatterCallback: (value) =>
                Strings.photoComparisonPercent(lang, (value * 100).round()),
            onChanged: (value) => setState(() => position = value),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => position = 1),
              child: Text(Strings.beforePhotoLabel(lang)),
            ),
            TextButton(
              onPressed: () => setState(() => position = 0),
              child: Text(Strings.afterPhotoLabel(lang)),
            ),
          ],
        ),
      ],
    );
  }
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
