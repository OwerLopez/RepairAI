import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reparaai/ui.dart';

Widget _buildLocalizedWidget({
  required Locale locale,
  required Widget Function(BuildContext) builder,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Builder(builder: builder),
  );
}

void main() {
  group('scanLabel', () {
    testWidgets('returns correct strings for all statuses in Spanish', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _buildLocalizedWidget(
          locale: const Locale('es'),
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      expect(
        scanLabel(capturedContext, 'candidate'),
        'Posible agujero · experimental',
      );
      expect(
        scanLabel(capturedContext, 'resolution'),
        'Resolución insuficiente',
      );
      expect(
        scanLabel(capturedContext, 'lighting'),
        'Iluminación insuficiente o excesiva',
      );
      expect(scanLabel(capturedContext, 'focus'), 'Falta de detalle o enfoque');
      expect(scanLabel(capturedContext, 'uncertain'), 'El modelo se abstuvo');
      expect(
        scanLabel(capturedContext, 'unrecognized_status'),
        'El modelo se abstuvo',
      );
    });

    testWidgets('returns correct strings for all statuses in English', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _buildLocalizedWidget(
          locale: const Locale('en'),
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      expect(
        scanLabel(capturedContext, 'candidate'),
        'Possible hole · experimental',
      );
      expect(
        scanLabel(capturedContext, 'resolution'),
        'Insufficient resolution',
      );
      expect(
        scanLabel(capturedContext, 'lighting'),
        'Image too dark or too bright',
      );
      expect(
        scanLabel(capturedContext, 'focus'),
        'Insufficient detail or focus',
      );
      expect(scanLabel(capturedContext, 'uncertain'), 'The model abstained');
      expect(
        scanLabel(capturedContext, 'unrecognized_status'),
        'The model abstained',
      );
    });
  });

  group('outcomeLabel', () {
    testWidgets('returns correct strings for all outcomes in Spanish', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _buildLocalizedWidget(
          locale: const Locale('es'),
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      expect(
        outcomeLabel(capturedContext, 'repaired'),
        'Reparado según el usuario',
      );
      expect(outcomeLabel(capturedContext, 'partial'), 'Resultado parcial');
      expect(outcomeLabel(capturedContext, 'stopped'), 'Interrumpida');
      expect(outcomeLabel(capturedContext, null), 'En progreso');
      expect(outcomeLabel(capturedContext, 'in-progress'), 'En progreso');
      expect(outcomeLabel(capturedContext, 'other'), 'En progreso');
    });

    testWidgets('returns correct strings for all outcomes in English', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _buildLocalizedWidget(
          locale: const Locale('en'),
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      expect(
        outcomeLabel(capturedContext, 'repaired'),
        'Repaired, self-reported',
      );
      expect(outcomeLabel(capturedContext, 'partial'), 'Partial result');
      expect(outcomeLabel(capturedContext, 'stopped'), 'Stopped');
      expect(outcomeLabel(capturedContext, null), 'In progress');
      expect(outcomeLabel(capturedContext, 'in-progress'), 'In progress');
      expect(outcomeLabel(capturedContext, 'other'), 'In progress');
    });
  });

  group('Copy extension', () {
    testWidgets('language and t helper behave correctly for es and en', (
      tester,
    ) async {
      late BuildContext esContext;
      await tester.pumpWidget(
        _buildLocalizedWidget(
          locale: const Locale('es'),
          builder: (context) {
            esContext = context;
            return const SizedBox();
          },
        ),
      );
      expect(esContext.language, 0);
      expect(esContext.t('Hola', 'Hello'), 'Hola');

      late BuildContext enContext;
      await tester.pumpWidget(
        _buildLocalizedWidget(
          locale: const Locale('en'),
          builder: (context) {
            enContext = context;
            return const SizedBox();
          },
        ),
      );
      expect(enContext.language, 1);
      expect(enContext.t('Hola', 'Hello'), 'Hello');
    });
  });
}
