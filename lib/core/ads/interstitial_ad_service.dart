import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tempo mínimo **de jogo** entre dois intersticiais (regra de monetização).
///
/// Medido em partida, e não no relógio de parede, de propósito: 45 s de
/// relógio passam sozinhos com o jogador parado no mapa, lendo a loja ou com o
/// app em segundo plano — e um anúncio a cada saída de fase rápida viraria o
/// que o jogador lembra do jogo. Contar só o tempo jogado garante que entre
/// dois anúncios houve, de fato, 45 s de jogo.
const Duration kInterstitialMinPlayTime = Duration(seconds: 45);

/// Até vencer esta fase da campanha, nenhum intersticial: é o onboarding.
///
/// As três primeiras fases ensinam a regra. Interromper o jogador ali, antes
/// de ele saber se gosta do jogo, é a forma mais cara de anúncio que existe.
const int kInterstitialOnboardingLevels = 3;

/// Em que momento o jogo pergunta se cabe um intersticial.
///
/// `afterDefeat` existe só para a regra ficar escrita e testada: a derrota
/// **nunca** mostra anúncio (anti-churn), e quem chama não precisa lembrar
/// disso — basta dizer onde está.
enum InterstitialMoment {
  /// Saindo do cartão de vitória (próxima fase ou voltar ao mapa).
  afterVictory,

  /// Voltando ao mapa sem ter vencido nem perdido (desistiu antes do fim).
  exitToMap,

  /// Saindo de uma derrota. Nunca mostra.
  afterDefeat,
}

/// Um intersticial já carregado, pronto para ser exibido uma vez.
///
/// Mesma razão de existir do `RewardedAdHandle`: o tipo do SDK fala com o
/// canal de plataforma, e a suíte não tem binding nativo.
abstract class InterstitialAdHandle {
  /// Exibe o anúncio e completa quando ele fecha (ou falha ao exibir).
  Future<void> show();

  /// Devolve os recursos do anúncio. Obrigatório depois de exibir.
  void dispose();
}

/// De onde vêm os intersticiais.
abstract class InterstitialAdPort {
  /// Carrega um anúncio da unidade [unitId], ou `null` sem inventário (ou sem
  /// consentimento). Nunca lança: sem anúncio é resposta, não erro.
  Future<InterstitialAdHandle?> load(String unitId);
}

/// A porta padrão: nenhum anúncio, nenhum canal de plataforma.
///
/// É o que a suíte usa. Quem liga o AdMob é o `main`, por `admobOverrides()`.
class NoInterstitialAdPort implements InterstitialAdPort {
  const NoInterstitialAdPort();

  @override
  Future<InterstitialAdHandle?> load(String unitId) async => null;
}

/// Decide **se** um intersticial cabe agora e o exibe.
///
/// Toda a regra de monetização do intersticial mora aqui, em Dart puro:
/// nunca na derrota, nunca no onboarding, nunca com o passe sem anúncios e
/// nunca antes de [minPlayTime] de jogo desde o último. A tela só diz onde
/// está ([InterstitialMoment]) e quanto o jogador jogou ([addPlayTime]).
///
/// Sem estoque, **não** carrega na hora (ao contrário do premiado): o
/// intersticial não foi pedido pelo jogador, e segurar a navegação esperando a
/// rede seria cobrar uma espera por um anúncio que ele não quer. Pula, repõe o
/// estoque e tenta na próxima oportunidade.
class InterstitialAdService {
  InterstitialAdService({
    required this.port,
    required this.unitId,
    this.minPlayTime = kInterstitialMinPlayTime,
    this.onShowStart,
    this.onShowEnd,
  });

  final InterstitialAdPort port;
  final String unitId;
  final Duration minPlayTime;

  /// Chamados em volta da exibição — é por onde a música do jogo pausa.
  final VoidCallback? onShowStart;
  final VoidCallback? onShowEnd;

  InterstitialAdHandle? _ready;
  Future<void>? _loading;

  /// Tempo de partida acumulado desde o último intersticial exibido.
  ///
  /// Começa em zero: o primeiro anúncio da sessão também espera 45 s de jogo.
  Duration _playSinceLast = Duration.zero;

  /// Há anúncio em estoque agora?
  bool get isReady => _ready != null;

  @visibleForTesting
  Duration get playSinceLast => _playSinceLast;

  /// Soma tempo de partida ao relógio de jogo. Negativo é ignorado.
  void addPlayTime(Duration played) {
    if (played > Duration.zero) _playSinceLast += played;
  }

  /// Carrega um anúncio para estar pronto na próxima oportunidade.
  /// Idempotente, como o do premiado.
  Future<void> preload() {
    if (_ready != null) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      _ready = await port.load(unitId);
    } catch (error, stack) {
      debugPrint('Falha ao carregar o intersticial $unitId: $error\n$stack');
      _ready = null;
    } finally {
      _loading = null;
    }
  }

  /// A regra, sem efeito colateral: cabe um intersticial em [moment]?
  ///
  /// [campaignProgress] é a última fase vencida; [adsRemoved] é o passe sem
  /// anúncios (hoje sempre falso).
  bool allows({
    required InterstitialMoment moment,
    required int campaignProgress,
    required bool adsRemoved,
  }) {
    if (adsRemoved) return false;
    if (moment == InterstitialMoment.afterDefeat) return false;
    if (campaignProgress < kInterstitialOnboardingLevels) return false;
    return _playSinceLast >= minPlayTime;
  }

  /// Exibe um intersticial se a regra permitir e houver estoque.
  ///
  /// Devolve se exibiu. Completa quando o anúncio fecha, para quem chama só
  /// seguir a navegação depois dele.
  Future<bool> maybeShow({
    required InterstitialMoment moment,
    required int campaignProgress,
    required bool adsRemoved,
  }) async {
    if (!allows(
      moment: moment,
      campaignProgress: campaignProgress,
      adsRemoved: adsRemoved,
    )) {
      return false;
    }

    final ad = _ready;
    if (ad == null) {
      unawaited(preload());
      return false;
    }

    // Sai do estoque antes de exibir: um intersticial só vale uma vez.
    _ready = null;
    // O relógio zera no instante da exibição, e não no fim: o tempo que o
    // anúncio passa na tela não é jogo.
    _playSinceLast = Duration.zero;

    onShowStart?.call();
    try {
      await ad.show();
    } catch (error, stack) {
      debugPrint('Falha ao exibir o intersticial $unitId: $error\n$stack');
    } finally {
      ad.dispose();
      onShowEnd?.call();
      unawaited(preload());
    }
    return true;
  }

  /// Devolve o anúncio que ficou em estoque sem ser exibido.
  void dispose() {
    _ready?.dispose();
    _ready = null;
  }
}
