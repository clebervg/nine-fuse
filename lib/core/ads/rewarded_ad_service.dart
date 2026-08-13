import 'dart:async';

import 'package:flutter/foundation.dart';

/// Um anúncio premiado já carregado, pronto para ser exibido uma vez.
///
/// Existe como interface, e não como o tipo do SDK, porque é o que permite
/// exercitar a máquina de estoque do [RewardedAdService] em teste puro: o
/// `RewardedAd` do google_mobile_ads fala com o canal de plataforma no
/// construtor, e a suíte não tem binding nativo.
abstract class RewardedAdHandle {
  /// Exibe o anúncio e responde se o jogador **ganhou** o prêmio.
  ///
  /// Falso é o caso normal de quem fechou antes do fim — a rede distingue os
  /// dois, e pagar os dois transformaria o anúncio num botão.
  Future<bool> show();

  /// Devolve os recursos do anúncio. Obrigatório depois de exibir.
  void dispose();
}

/// De onde vêm os anúncios premiados.
abstract class RewardedAdPort {
  /// Carrega um anúncio da unidade [unitId], ou `null` se a rede não tiver
  /// inventário agora. Nunca lança: sem anúncio é resposta, não erro.
  Future<RewardedAdHandle?> load(String unitId);
}

/// Mantém um anúncio premiado carregado e o entrega quando o jogo pedir.
///
/// **O preload é a razão de esta classe existir.** Carregar no toque do botão
/// põe a rede no caminho crítico da decisão do jogador: ele vê uma espera de
/// alguns segundos entre "quero" e "assisti", e a regra de monetização do
/// projeto manda carregar no início do nível justamente por isso.
///
/// Um anúncio de cada vez, e não uma fila: o jogo só exibe um por vez, e um
/// estoque maior seria memória parada — a rede também expira o que fica velho.
class RewardedAdService {
  RewardedAdService({required this.port, required this.unitId});

  /// De onde os anúncios vêm. Público porque é a costura de injeção: é o que um
  /// teste troca por uma rede de mentira sem tocar em mais nada.
  final RewardedAdPort port;

  /// A unidade de anúncio desta instância. Cada gatilho tem a sua (martelo,
  /// reforço de saldo), porque é por unidade que a rede reporta receita — uma
  /// só impediria de saber qual funil paga.
  final String unitId;

  RewardedAdHandle? _ready;

  /// Uma carga já está em andamento. Sem esta trava, dois `preload` seguidos
  /// (início de fase + reposição depois de uma exibição) pediriam dois anúncios
  /// à rede, e o segundo a chegar sobrescreveria o primeiro sem devolvê-lo.
  Future<void>? _loading;

  /// Há anúncio em estoque agora?
  bool get isReady => _ready != null;

  /// Carrega um anúncio para estar pronto quando o jogador pedir.
  ///
  /// Idempotente de propósito: dá para chamar a cada início de fase sem
  /// perguntar se o estoque já está cheio.
  Future<void> preload() {
    if (_ready != null) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      _ready = await port.load(unitId);
    } catch (error, stack) {
      // Rede indisponível vale como estoque vazio. Ficar sem anúncio é ruim;
      // derrubar a fase por causa disso é pior — a mesma régua que o
      // `GameStorage` usa para falha de leitura.
      debugPrint('Falha ao carregar o anúncio premiado $unitId: $error\n$stack');
      _ready = null;
    } finally {
      _loading = null;
    }
  }

  /// Exibe um anúncio e responde se o jogador ganhou o prêmio.
  ///
  /// Sem estoque, carrega na hora em vez de recusar: o convite já está aberto e
  /// o jogador já tocou em "assistir" — responder "não tem anúncio" porque o
  /// preload não terminou seria perder a conversão por sincronia.
  Future<bool> show() async {
    if (_ready == null) await preload();

    final ad = _ready;
    if (ad == null) return false;

    // Sai do estoque **antes** de exibir: um premiado só pode ser mostrado uma
    // vez, e mantê-lo aqui daria um segundo prêmio de graça na próxima chamada.
    _ready = null;

    try {
      return await ad.show();
    } finally {
      ad.dispose();
      // Repõe o estoque para o próximo convite. Sem `await`: o jogador está
      // olhando o resultado do anúncio que acabou, não esperando o seguinte.
      unawaited(preload());
    }
  }

  /// Devolve o anúncio que ficou em estoque sem ser exibido.
  void dispose() {
    _ready?.dispose();
    _ready = null;
  }
}
