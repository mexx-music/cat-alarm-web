import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Title is generated from localized resources so it updates with locale.
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      // Localization wiring: delegates, supported locales and a resolution callback
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[
        Locale('de'),
        Locale('en'),
        Locale('es'),
        Locale('zh', 'CN'),
      ],
      localeResolutionCallback:
          (Locale? locale, Iterable<Locale> supportedLocales) {
        // If no locale provided, fallback to first supported
        if (locale == null) return supportedLocales.first;

        // Exact match (language + country)
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode &&
              (supported.countryCode == locale.countryCode)) {
            return supported;
          }
        }

        // Handle Chinese variants: prefer zh_CN when countryCode is CN
        if (locale.languageCode == 'zh') {
          if (locale.countryCode == 'CN') return const Locale('zh', 'CN');
          return const Locale('zh');
        }

        // Fallback to language-only match
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) return supported;
        }

        // Final fallback
        return supportedLocales.first;
      },
      debugShowCheckedModeBanner: false,
      // ⬇️ Fix: System-Schriftgrößen neutralisieren (Huawei/EMUI)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
      home: const CatAlarmScreen(),
    );
  }
}
