import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  // Obrigatório antes de falar com qualquer canal de plataforma, e o SDK de
  // anúncio é exatamente isso.
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Mantém a splash nativa (Android/iOS) acesa depois que o engine já
  // renderizaria a primeira tela do Flutter por baixo dela. Sem isso haveria
  // um piscar entre a splash nativa e a tela vazia enquanto o primeiro frame
  // do app monta. Removida no fim de `NineFuseApp.build`, quando esse
  // primeiro frame já está na tela — não há nada assíncrono hoje que valha a
  // pena esperar antes disso (nem fontes, nem o SDK de anúncio, que já é
  // fire-and-forget por design, ver abaixo).
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  AppFonts.registerLicense();

  // A inicialização do SDK é assíncrona e **não é esperada**: ela leva algumas
  // centenas de milissegundos, e segurar o `runApp` até lá trocaria a abertura
  // do jogo por uma tela branca. Um anúncio pedido antes de ela terminar
  // apenas falha em carregar, que é um caso que o `RewardedAdService` já trata
  // como "sem estoque".
  //
  // Só nas plataformas que têm o SDK: em desktop e web o plugin não existe, e
  // a chamada estouraria no canal.
  //
  // O `catchError` também não é decorativo: se o plugin nativo não estiver
  // registrado — o caso de adicionar a dependência e dar hot restart em vez de
  // reinstalar o app —, a chamada estoura com `MissingPluginException` e sobe
  // como erro não tratado no console. O jogo funciona sem anúncio; o que ele
  // não pode é abrir cuspindo pilha.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    MobileAds.instance.initialize().catchError((Object error) {
      debugPrint('SDK de anúncio não inicializou: $error');
      return InitializationStatus(const {});
    });
  }

  runApp(
    ProviderScope(
      // Os funis só falam com o AdMob aqui. O padrão dos providers paga o
      // jogador sem rede nenhuma, e é o que mantém a suíte de widget rodando
      // sem canal de plataforma — ver `admobOverrides`.
      overrides: admobOverrides(),
      child: const NineFuseApp(),
    ),
  );
}

class NineFuseApp extends StatelessWidget {
  const NineFuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Some no primeiro frame renderizado, não antes: remover no `build` em si
    // tiraria a splash antes de haver algo do app para mostrar no lugar dela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

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
