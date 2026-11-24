import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reparaai/glass.dart';

void main() {
  group('Glass color constants', () {
    test('verify color constants values match expected hex codes', () {
      expect(midnight, const Color(0xff06111f));
      expect(deepBlue, const Color(0xff10263b));
      expect(frost, const Color(0xffeff7ff));
      expect(ice, const Color(0xff8af1e3));
      expect(softText, const Color(0xffbdcedf));
      expect(glassBorder, const Color(0x5484b4d2));
    });
  });

  group('GlassCard', () {
    testWidgets('renders child widget with default styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackdrop(child: GlassCard(child: Text('Card Content'))),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);

      final decoratedBoxFinder = find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(DecoratedBox),
      );
      expect(decoratedBoxFinder, findsOneWidget);

      final decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder);
      final decoration = decoratedBox.decoration as BoxDecoration;

      // Default border: glassBorder
      expect(decoration.border?.top.color, glassBorder);

      // Default gradient colors
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, const [Color(0xc41b334c), Color(0xdb10263b)]);

      // Verify custom padding default (EdgeInsets.all(18))
      final paddingWidget = tester.widget<Padding>(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(Padding),
        ),
      );
      expect(paddingWidget.padding, const EdgeInsets.all(18));
    });

    testWidgets('renders with accent=true applying accent styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackdrop(
              child: GlassCard(
                accent: true,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Accent Card Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Accent Card Content'), findsOneWidget);

      final decoratedBoxFinder = find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(DecoratedBox),
      );
      final decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder);
      final decoration = decoratedBox.decoration as BoxDecoration;

      // Accent border: Color(0x9785e4e2)
      expect(decoration.border?.top.color, const Color(0x9785e4e2));

      // Accent gradient colors: [Color(0xce19445c), Color(0xe210253d)]
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, const [Color(0xce19445c), Color(0xe210253d)]);

      // Verify custom padding
      final paddingWidget = tester.widget<Padding>(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(Padding),
        ),
      );
      expect(
        paddingWidget.padding,
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      );
    });
  });

  group('Glyph', () {
    testWidgets('renders icon with default size 42 and ice color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Glyph(Icons.construction))),
        ),
      );

      expect(find.byType(Glyph), findsOneWidget);
      expect(find.byIcon(Icons.construction), findsOneWidget);

      // Verify Glyph size is 42x42
      expect(tester.getSize(find.byType(Glyph)), const Size(42, 42));

      // Verify Icon properties: color ice and size 42 * 0.48 = 20.16
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.construction));
      expect(iconWidget.color, ice);
      expect(iconWidget.size, closeTo(42 * 0.48, 0.001));

      // Verify ExcludeSemantics is present
      expect(
        find.descendant(
          of: find.byType(Glyph),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });

    testWidgets('renders with custom size', (tester) async {
      const customSize = 64.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Glyph(Icons.check, size: customSize)),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);

      // Verify Glyph custom size
      expect(
        tester.getSize(find.byType(Glyph)),
        const Size(customSize, customSize),
      );

      // Verify Icon size is customSize * 0.48
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(iconWidget.color, ice);
      expect(iconWidget.size, closeTo(customSize * 0.48, 0.001));
    });
  });

  group('GlassBackdrop', () {
    testWidgets('renders child widget within Stack and BackdropGroup', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassBackdrop(child: Text('Under Aurora Content')),
          ),
        ),
      );

      expect(find.text('Under Aurora Content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
