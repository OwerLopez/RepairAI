import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home.dart';
import 'journal.dart';
import 'procedures.dart';
import 'ui.dart';
import 'vision.dart';

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
  late String language = widget.language ?? 'es';

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
      locale: Locale(language),
      supportedLocales: const [Locale('es'), Locale('en')],
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
