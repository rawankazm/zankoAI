import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/sqlite_database_service.dart';
import 'services/ai_service.dart';
import 'services/language_provider.dart';
import 'services/theme_provider.dart';
import 'views/splash_screen.dart';

import 'package:device_preview/device_preview.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !const bool.fromEnvironment('dart.vm.product'),
      builder: (context) => const ZankoApp(),
    ),
  );
}

class ZankoApp extends StatelessWidget {
  const ZankoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => MockAuthService(),
        ),
        ChangeNotifierProvider<DatabaseService>(
          create: (_) => SqliteDatabaseService()..loadData(),
        ),
        ChangeNotifierProvider<AiService>(
          create: (_) => ZankoAiService(),
        ),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, langProvider, themeProvider, child) {
          return MaterialApp(
            title: 'ZankoAI',
            debugShowCheckedModeBanner: false,
            builder: DevicePreview.appBuilder,
            theme: ZankoTheme.getLightTheme(themeProvider.activeTheme, languageFontFamily: langProvider.fontFamily),
            darkTheme: ZankoTheme.getDarkTheme(themeProvider.activeTheme, languageFontFamily: langProvider.fontFamily),
            themeMode: themeProvider.themeMode,
            localizationsDelegates: const [
              _KurdishMaterialLocalizationsDelegate(),
              _KurdishCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ku', ''),
              Locale('ar', ''),
              Locale('en', ''),
            ],
            locale: Locale(langProvider.languageCode, ''),
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
            },
          );
        },
      ),
    );
  }
}

// Fallback Material Localizations for Kurdish using Arabic locale behavior for RTL formatting
class _KurdishMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(LocalizationsDelegate<MaterialLocalizations> old) => false;
}

// Fallback Cupertino Localizations for Kurdish using Arabic locale behavior for RTL formatting
class _KurdishCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(LocalizationsDelegate<CupertinoLocalizations> old) => false;
}
