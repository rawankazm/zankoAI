import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_database_service.dart';
import 'services/database_service.dart';
import 'services/ai_service.dart';
import 'services/language_provider.dart';
import 'services/theme_provider.dart';
import 'services/score_service.dart';
import 'services/offline_archive_service.dart';
import 'services/study_roadmap_service.dart';
import 'services/notification_service.dart';
import 'views/splash_screen.dart';

import 'services/zankoline_service.dart';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch unexpected rendering and platform errors gracefully
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Dispatcher Error: $error');
    return true;
  };

  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
    );
    unawaited(NotificationService().init().catchError((e) {
      debugPrint('Notification init notice: $e');
    }));
  } catch (e) {
    debugPrint('Supabase core initialization notice: $e');
  }

  runApp(
    DevicePreview(
      enabled: kIsWeb && !kReleaseMode,
      builder: (context) => const ZankoApp(),
    ),
  );
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class ZankoApp extends StatelessWidget {
  const ZankoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => SupabaseAuthService(),
        ),
        ChangeNotifierProvider<DatabaseService>(
          create: (_) => SupabaseDatabaseService(),
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
        ChangeNotifierProvider<ScoreService>.value(
          value: ScoreService.instance,
        ),
        ChangeNotifierProvider<OfflineArchiveService>.value(
          value: OfflineArchiveService.instance,
        ),
        ChangeNotifierProvider<StudyRoadmapService>.value(
          value: StudyRoadmapService.instance,
        ),
        ChangeNotifierProxyProvider<AiService, ZankolineService>(
          create: (context) => ZankolineService(Provider.of<AiService>(context, listen: false)),
          update: (context, aiService, previous) => (previous ?? ZankolineService(aiService))..updateAiService(aiService),
        ),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, langProvider, themeProvider, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
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
              Locale('badini', ''),
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

// Fallback Material Localizations for Kurdish (Sorani & Badini) using Arabic locale behavior for RTL formatting
class _KurdishMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku' || locale.languageCode == 'badini';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(LocalizationsDelegate<MaterialLocalizations> old) => false;
}

// Fallback Cupertino Localizations for Kurdish (Sorani & Badini) using Arabic locale behavior for RTL formatting
class _KurdishCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku' || locale.languageCode == 'badini';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(LocalizationsDelegate<CupertinoLocalizations> old) => false;
}
