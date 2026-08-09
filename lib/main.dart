import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  AppFonts.registerLicense();
  runApp(const ProviderScope(child: NineFuseApp()));
}

class NineFuseApp extends StatelessWidget {
  const NineFuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      // `onGenerateTitle` e não `title`: o título do app também é texto de
      // jogador, e num `title` fixo ele seria o único ponto do app imune ao
      // idioma do aparelho.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // O inglês vem primeiro porque é o fallback: o algoritmo padrão do
      // Flutter resolve `pt_BR` para `pt` por idioma, e manda qualquer locale
      // desconhecido para o primeiro da lista. É o que dispensa um
      // `localeResolutionCallback` só para dizer o óbvio.
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: AppColors.darkBackground,
        // A fonte vale para o app inteiro: misturar Nunito nos números com a
        // fonte do sistema nos rótulos é o tipo de detalhe que faz a tela
        // parecer montada às pressas.
        textTheme: base.textTheme.apply(fontFamily: AppFonts.display),
        primaryTextTheme: base.primaryTextTheme.apply(
          fontFamily: AppFonts.display,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const LevelSelectScreen(),
    );
  }
}
