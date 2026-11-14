import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/terra_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TerraProvider()..initializeZeroLogin(),
      child: const TerraSpaceApp(),
    ),
  );
}

class TerraSpaceApp extends StatelessWidget {
  const TerraSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = context.watch<TerraProvider>().isEnglish;
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF1B5E20),
      scaffoldBackgroundColor: const Color(0xFFF6FAF7),
    );

    return MaterialApp(
      title: isEn
          ? 'Terra Space 🛰️🌱 — Smart Agritech Assistant'
          : 'Terra Space 🛰️🌱 — تطبيق تيرا سبيس الزراعي الذكي',
      debugShowCheckedModeBanner: false,
      locale: isEn ? const Locale('en') : const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      // Zero-Login Conversational Voice UI مباشرة للمزارع
      home: const HomeScreen(),
    );
  }
}
