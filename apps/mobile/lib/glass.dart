import 'dart:ui';

import 'package:flutter/material.dart';

const midnight = Color(0xff06111f);
const deepBlue = Color(0xff10263b);
const frost = Color(0xffeff7ff);
const ice = Color(0xff8af1e3);
const softText = Color(0xffbdcedf);
const glassBorder = Color(0x5484b4d2);

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const RepaintBoundary(child: CustomPaint(painter: _Aurora())),
      BackdropGroup(child: child),
    ],
  );
}

class _Aurora extends CustomPainter {
  const _Aurora();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0d2540), midnight, Color(0xff0d2734)],
        ).createShader(bounds),
    );

    void light(Alignment at, Color color, double radius) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: at,
            radius: radius,
            colors: [color, color.withAlpha(0)],
          ).createShader(bounds),
      );
    }

    light(const Alignment(.92, -.68), const Color(0x944079ab), .88);
    light(const Alignment(-1.03, .68), const Color(0x8040878d), .85);
    final bands = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x2d84cce1);
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 9; i++) {
      final phase = i * 13.0;
      final line = Path()
        ..moveTo(-30, h * .43 + phase)
        ..cubicTo(
          w * .42,
          h * .56 + phase,
          w * .54,
          h * .19 + phase,
          w + 35,
          h * .30 + phase,
        )
        ..cubicTo(
          w * 1.25,
          h * .34 + phase,
          w * .91,
          h * .65 + phase,
          w * .48,
          h * .79 + phase,
        )
        ..cubicTo(
          w * .10,
          h * .89 + phase,
          w * .25,
          h * 1.06 + phase,
          w * .78,
          h * 1.03 + phase,
        );
      canvas.drawPath(line, bands);
    }
  }

  @override
  bool shouldRepaint(_Aurora oldDelegate) => false;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: accent ? const Color(0x9785e4e2) : glassBorder,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: accent
                  ? const [Color(0xce19445c), Color(0xe210253d)]
                  : const [Color(0xc41b334c), Color(0xdb10263b)],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Glyph extends StatelessWidget {
  const Glyph(this.icon, {super.key, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .30),
        border: Border.all(color: const Color(0x6678eddf)),
        gradient: const LinearGradient(
          colors: [Color(0x2630e4dc), Color(0x22639ce4)],
        ),
      ),
      child: Icon(icon, color: ice, size: size * .48),
    ),
  );
}
