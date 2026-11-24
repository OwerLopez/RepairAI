import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'glass.dart';
import 'home.dart';
import 'journal.dart';
import 'procedures.dart';
import 'vision.dart';

/// Entry point initializing persistence, loading embedded model assets, and launching the application.
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

/// Root application widget configuring dark theme, glassmorphic styling, and supported locales.
class ReparaApp extends StatefulWidget {
  /// Creates the root [ReparaApp].
  const ReparaApp({
    super.key,
    required this.journal,
    required this.vision,
    required this.knowledge,
    this.language,
  });

  /// The SQLite persistence journal.
  final Journal journal;

  /// Neural vision inference engine.
  final Vision vision;

  /// Bundled repair procedures knowledge base.
  final Knowledge knowledge;

  /// Initial language code ('es' or 'en') restored from user preferences, if set.
  final String? language;

  @override
  State<ReparaApp> createState() => _ReparaAppState();
}

class _ReparaAppState extends State<ReparaApp> {
  late String language = widget.language ?? 'es';

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ice,
          brightness: Brightness.dark,
        ).copyWith(
          surface: deepBlue,
          onSurface: frost,
          onSurfaceVariant: softText,
          primary: ice,
          onPrimary: midnight,
          primaryContainer: const Color(0xff1c505a),
          onPrimaryContainer: frost,
          outline: const Color(0xff527389),
        );
    return MaterialApp(
      title: 'ReparaAI',
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => GlassBackdrop(child: child!),
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xe0112135),
          foregroundColor: frost,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xf0102235),
          indicatorColor: Color(0xff20525d),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: deepBlue),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xda0b1d31),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xff527389)),
            borderRadius: BorderRadius.circular(16),
          ),
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
