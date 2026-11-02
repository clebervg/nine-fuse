import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_ids.dart';
import 'package:nine_fuse/core/ads/admob_consent_port.dart';
import 'package:nine_fuse/core/ads/admob_interstitial_port.dart';
import 'package:nine_fuse/core/ads/admob_rewarded_port.dart';
import 'package:nine_fuse/core/ads/consent_service.dart';
import 'package:nine_fuse/core/ads/interstitial_ad_service.dart';
import 'package:nine_fuse/core/ads/rewarded_ad_service.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/features/game/presentation/widgets/daily_spin_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/moves_offer_dialog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';

/// De onde vêm os anúncios premiados de verdade.
///
/// Um provider próprio para a porta permite trocar o SDK inteiro num override —
/// é por aqui que um teste de integração entraria sem precisar de rede.
final rewardedAdPortProvider = Provider<RewardedAdPort>(
  (ref) => AdMobRewardedPort(consent: ref.watch(consentServiceProvider)),
);

/// Consentimento (UMP + ATT) que antecede qualquer pedido de anúncio.
///
/// Um só serviço para o app inteiro: o resultado é calculado uma vez e
/// compartilhado pelos quatro funis.
final consentServiceProvider = Provider<ConsentService>(
  (ref) => ConsentService(
    consent: const UmpConsentPort(),
    tracking: const AttTrackingPort(),
  ),
);

/// Serviço do anúncio que paga o Martelo de Fusão.
final hammerAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(
    port: ref.watch(rewardedAdPortProvider),
    unitId: AdIds.hammerRewarded,
    onShowStart: _pauseMusicForAd,
    onShowEnd: _resumeMusicAfterAd,
  );
  // O anúncio em estoque é memória viva na rede: sem devolvê-lo quando o
  // provider morre, cada recriação do escopo deixaria um para trás.
  ref.onDispose(service.dispose);
  return service;
});

/// Serviço do anúncio que paga o reforço de saldo (gatilho pre-churn).
final movesAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(
    port: ref.watch(rewardedAdPortProvider),
    unitId: AdIds.movesRewarded,
    onShowStart: _pauseMusicForAd,
    onShowEnd: _resumeMusicAfterAd,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Serviço do anúncio que paga moedas dentro do modal de compra.
final coinAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(
    port: ref.watch(rewardedAdPortProvider),
    unitId: AdIds.coinsRewarded,
    onShowStart: _pauseMusicForAd,
    onShowEnd: _resumeMusicAfterAd,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Serviço do anúncio que paga o giro extra da roleta diária.
final spinAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(
    port: ref.watch(rewardedAdPortProvider),
    unitId: AdIds.spinRewarded,
    onShowStart: _pauseMusicForAd,
    onShowEnd: _resumeMusicAfterAd,
  );
  ref.onDispose(service.dispose);
  return service;
});

// A música do jogo cala enquanto um anúncio de tela cheia está no ar: o áudio
// dos dois junto é ruído, e o do anúncio é o que o jogador escolheu ouvir.
void _pauseMusicForAd() => unawaited(GameAudio.service.pauseForAd());
void _resumeMusicAfterAd() => unawaited(GameAudio.service.resumeAfterAd());

/// O "No-Ads Pass": com ele, nenhum intersticial.
///
/// Hoje é sempre falso — não há billing no projeto. É o ponto de extensão:
/// quando a compra existir, este provider passa a ler o direito do jogador, e
/// nenhuma regra do intersticial precisa mudar. Os premiados **não** passam
/// por aqui: são opt-in, e o passe remove só o anúncio que o jogador não pediu.
final adsRemovedProvider = Provider<bool>((ref) => false);

/// De onde vêm os intersticiais.
///
/// O padrão é **nenhum anúncio** (e nenhum canal de plataforma), ao contrário
/// dos premiados, que pagam sem rede: um intersticial não paga nada, então o
/// equivalente "neutro" em teste é simplesmente não existir. Quem liga o AdMob
/// é `admobOverrides()`.
final interstitialAdPortProvider = Provider<InterstitialAdPort>(
  (ref) => const NoInterstitialAdPort(),
);

/// O serviço do intersticial: um só para o app inteiro, porque é ele quem
/// guarda o relógio de jogo desde o último anúncio.
final interstitialAdServiceProvider = Provider<InterstitialAdService>((ref) {
  final service = InterstitialAdService(
    port: ref.watch(interstitialAdPortProvider),
    unitId: AdIds.interstitial,
    onShowStart: _pauseMusicForAd,
    onShowEnd: _resumeMusicAfterAd,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Pergunta ao serviço se cabe um intersticial em [moment] e o exibe.
///
/// Junta aqui o que a regra precisa e a tela não deveria montar à mão: o
/// progresso da campanha (onboarding) e o passe sem anúncios.
Future<bool> maybeShowInterstitial(WidgetRef ref, InterstitialMoment moment) {
  return ref
      .read(interstitialAdServiceProvider)
      .maybeShow(
        moment: moment,
        campaignProgress: ref.read(campaignProgressProvider),
        adsRemoved: ref.read(adsRemovedProvider),
      );
}

/// Deixa os anúncios premiados carregados para esta fase/corrida.
///
/// Chamado no início do nível, e não no toque do botão, porque carregar sob
/// demanda põe a rede no caminho crítico da decisão do jogador: ele veria
/// alguns segundos de espera entre "quero" e "assisti". É a regra de preload
/// obrigatório do projeto.
///
/// Não devolve `Future`: quem chama não tem nada a esperar — o resultado do
/// preload é o estoque do serviço, que o convite consulta quando abrir.
void preloadRewardedAds(WidgetRef ref) {
  ref.read(hammerAdServiceProvider).preload();
  ref.read(movesAdServiceProvider).preload();
  // O de moedas também: ele nasce dentro do modal de compra, que já é aberto
  // no meio de uma decisão — pedir a rede ali é a espera que o preload existe
  // para evitar.
  ref.read(coinAdServiceProvider).preload();
  ref.read(spinAdServiceProvider).preload();
}

/// Liga os funis de anúncio ao AdMob.
///
/// É uma lista de overrides, e não o valor padrão dos providers, de propósito:
/// o padrão de `hammerAdProvider`, `movesAdProvider` e `spinAdProvider` **pagam
/// o jogador sem anúncio nenhum**, que é o que mantém toda a suíte de widget
/// rodando sem canal de plataforma. Quem escolhe usar a rede de verdade é o
/// `main`.
List<Override> admobOverrides() => [
  hammerAdProvider.overrideWith(
    (ref) => ref.watch(hammerAdServiceProvider).show,
  ),
  movesAdProvider.overrideWith((ref) => ref.watch(movesAdServiceProvider).show),
  coinAdProvider.overrideWith((ref) => ref.watch(coinAdServiceProvider).show),
  spinAdProvider.overrideWith((ref) => ref.watch(spinAdServiceProvider).show),
  interstitialAdPortProvider.overrideWith(
    (ref) => AdMobInterstitialPort(consent: ref.watch(consentServiceProvider)),
  ),
];
