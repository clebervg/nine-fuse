import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_ids.dart';
import 'package:nine_fuse/core/ads/admob_rewarded_port.dart';
import 'package:nine_fuse/core/ads/rewarded_ad_service.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/moves_offer_dialog.dart';

/// De onde vêm os anúncios premiados de verdade.
///
/// Um provider próprio para a porta permite trocar o SDK inteiro num override —
/// é por aqui que um teste de integração entraria sem precisar de rede.
final rewardedAdPortProvider = Provider<RewardedAdPort>(
  (ref) => const AdMobRewardedPort(),
);

/// Serviço do anúncio que paga o Martelo de Fusão.
final hammerAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = RewardedAdService(
    port: ref.watch(rewardedAdPortProvider),
    unitId: AdIds.hammerRewarded,
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
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Deixa os dois anúncios premiados carregados para esta fase/corrida.
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
}

/// Liga os dois funis de anúncio ao AdMob.
///
/// É uma lista de overrides, e não o valor padrão dos providers, de propósito:
/// o padrão de `hammerAdProvider` e `movesAdProvider` **paga o jogador sem
/// anúncio nenhum**, que é o que mantém toda a suíte de widget rodando sem
/// canal de plataforma. Quem escolhe usar a rede de verdade é o `main`.
List<Override> admobOverrides() => [
  hammerAdProvider.overrideWith(
    (ref) => ref.watch(hammerAdServiceProvider).show,
  ),
  movesAdProvider.overrideWith((ref) => ref.watch(movesAdServiceProvider).show),
];
