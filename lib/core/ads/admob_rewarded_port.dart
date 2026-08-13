import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nine_fuse/core/ads/rewarded_ad_service.dart';

/// A ponte com o SDK do AdMob.
///
/// É deliberadamente fina e **não tem teste**: tudo o que ela faz é traduzir os
/// retornos de chamada do `google_mobile_ads` para os dois métodos de
/// [RewardedAdHandle]. Toda a decisão — quando carregar, quando repor, o que
/// fazer sem estoque — vive no [RewardedAdService], que é testável em Dart
/// puro. Testar esta classe exigiria um binding nativo e mediria o SDK, não o
/// jogo.
class AdMobRewardedPort implements RewardedAdPort {
  const AdMobRewardedPort();

  @override
  Future<RewardedAdHandle?> load(String unitId) async {
    // Sem unidade não há o que pedir: fora de Android e iOS o `AdIds` devolve
    // string vazia de propósito, e chamar o SDK ali estouraria no canal.
    if (unitId.isEmpty) return null;

    final completer = Completer<RewardedAdHandle?>();

    // O `await` aqui não é decorativo, e a falta dele foi um bug de verdade.
    // `RewardedAd.load` fala com o canal de plataforma e **estoura** quando o
    // lado nativo não está registrado — o caso clássico é adicionar o plugin e
    // dar hot restart em vez de reinstalar o app. Sem awaitar, a exceção escapa
    // como erro assíncrono não tratado, o `Completer` nunca completa, e o
    // `preload` do serviço fica pendurado para sempre: `_loading` não limpa e
    // toda tentativa seguinte é engolida. Um anúncio que não vem é um convite
    // que falha; um serviço pendurado é o jogo sem anúncio pelo resto da
    // sessão.
    try {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => completer.complete(_AdMobRewardedAd(ad)),
          // Sem inventário é resposta, não erro: quem chamou trata `null` como
          // "não tem anúncio agora".
          onAdFailedToLoad: (_) => completer.complete(null),
        ),
      );
    } catch (error, stack) {
      debugPrint('SDK de anúncio indisponível para $unitId: $error\n$stack');
      return null;
    }

    return completer.future;
  }
}

class _AdMobRewardedAd implements RewardedAdHandle {
  _AdMobRewardedAd(this._ad);

  final RewardedAd _ad;

  @override
  Future<bool> show() {
    final completer = Completer<bool>();
    // O prêmio e o fechamento chegam por caminhos diferentes, e em ordem: a
    // recompensa vem primeiro, o fechamento depois. Só o fechamento encerra a
    // espera — completar na recompensa devolveria o controle ao jogo com o
    // anúncio ainda em tela por cima do tabuleiro.
    var earned = false;

    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!completer.isCompleted) completer.complete(earned);
      },
      // Falha ao exibir não paga, e precisa encerrar a espera do mesmo jeito:
      // sem isto o convite ficaria travado no estado "assistindo" para sempre.
      onAdFailedToShowFullScreenContent: (_, _) {
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _ad.show(onUserEarnedReward: (_, _) => earned = true);

    return completer.future;
  }

  @override
  void dispose() => _ad.dispose();
}
