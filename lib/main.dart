import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/features/game/presentation/screens/splash_screen.dart';
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

  // Os sprites de peça e de cobertura são carregados pela `SplashScreen`, que
  // é quem espera por eles e mostra o progresso — chamá-los aqui também os
  // marcaria como "já tentados" e a barra não teria o que acompanhar.

  // Os funis só falam com o AdMob aqui. O padrão dos providers paga o
  // jogador sem rede nenhuma, e é o que mantém a suíte de widget rodando sem
  // canal de plataforma — ver `admobOverrides`.
  final container = ProviderContainer(overrides: admobOverrides());

  // A inicialização do SDK é assíncrona e **não é esperada**: segurar o
  // `runApp` até lá trocaria a abertura do jogo por uma tela branca. Um
  // anúncio pedido antes de o consentimento resolver apenas espera por ele
  // (ver `AdMobRewardedPort`), e sem permissão vira "sem estoque", caso que o
  // `RewardedAdService` já trata.
  //
  // O consentimento (UMP e, no iOS, ATT) vem ANTES de `initialize`: o Google
  // recomenda inicializar o SDK só depois de `canRequestAds`.
  //
  // Só nas plataformas que têm o SDK: em desktop e web o plugin não existe, e
  // a chamada estouraria no canal. O `catchError` também não é decorativo: se
  // o plugin nativo não estiver registrado — adicionar a dependência e dar hot
  // restart em vez de reinstalar —, a chamada estoura com
  // `MissingPluginException`. O jogo funciona sem anúncio; o que ele não pode é
  // abrir cuspindo pilha.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(
      container
          .read(consentServiceProvider)
          .ensure()
          .then((consent) async {
            if (consent.canRequestAds) await MobileAds.instance.initialize();
          })
          .catchError((Object error) {
            debugPrint('SDK de anúncio não inicializou: $error');
          }),
    );
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const NineFuseApp()),
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
        // O céu do observatório. As telas pintam `NfBackground` (gradiente +
        // estrelas) por cima; esta cor é o que aparece por um quadro durante
        // transições de rota, e tem de ser do mesmo azul para não piscar.
        scaffoldBackgroundColor: NfColors.night1,
        colorScheme: base.colorScheme.copyWith(
          primary: NfColors.gold,
          secondary: NfColors.gem,
          surface: NfColors.night2,
        ),
        // A fonte vale para o app inteiro: misturar Nunito nos números com a
        // fonte do sistema nos rótulos é o tipo de detalhe que faz a tela
        // parecer montada às pressas.
        textTheme: base.textTheme.apply(fontFamily: AppFonts.display),
        primaryTextTheme: base.primaryTextTheme.apply(
          fontFamily: AppFonts.display,
        ),
        appBarTheme: AppBarTheme(
          // Transparente: a barra fica sobre o céu da tela, não numa faixa
          // cinza que cortaria o fundo em dois.
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: NfColors.goldPale),
          titleTextStyle: const TextStyle(
            fontFamily: AppFonts.title,
            fontSize: 24,
            letterSpacing: 0.6,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(0, 2), color: NfColors.gemTitleShadow),
              Shadow(offset: Offset(0, 4), color: NfColors.gemDeep),
            ],
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
      home: const SplashScreen(),
    );
  }
}
