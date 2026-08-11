import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// O Martelo de Fusão, do ponto de vista do estado.
///
/// Vive num objeto só, e não em cinco campos soltos, porque **duas** partidas
/// diferentes o carregam — a fase da campanha e a corrida do Endless. Espalhar
/// os campos obrigaria os dois estados a repetir a mesma lista, e a lista a ser
/// mantida em dois lugares.
@immutable
class HammerState {
  const HammerState({
    this.count = 0,
    this.isTargeting = false,
    this.strike,
    this.strikes = 0,
    this.pendingTarget,
  });

  /// Martelos em estoque. É inventário do **jogador**: atravessa fase, corrida e
  /// fechamento do app, e os dois modos leem e gastam do mesmo saldo.
  final int count;

  /// O jogador está escolhendo em que célula bater.
  ///
  /// Ligado inclusive com estoque zero — o **Modo Fantasma**: deixá-lo escolher
  /// o alvo antes de descobrir que não tem martelo é o que dá sentido ao convite
  /// de aquisição. Ele já sabe o que quer quebrar.
  final bool isTargeting;

  /// Onde o último golpe caiu, e **qual dígito morreu**.
  ///
  /// O dígito viaja aqui porque, quando a UI desenha o estilhaço, a peça já saiu
  /// do tabuleiro e não há de onde tirar a cor.
  final (Position, int)? strike;

  /// Quantos golpes esta partida levou. Só serve de chave para a animação: dois
  /// golpes na mesma célula, com o mesmo dígito, seriam indistinguíveis por
  /// [strike] e o segundo não reacenderia o estilhaço.
  final int strikes;

  /// Alvo escolhido no Modo Fantasma, à espera do martelo.
  ///
  /// Guardá-lo evita cobrar duas vezes pelo mesmo golpe: quem assistiu ao
  /// anúncio não deve ter que mirar de novo.
  final Position? pendingTarget;

  HammerState copyWith({
    int? count,
    bool? isTargeting,
    (Position, int)? strike,
    int? strikes,
    Position? pendingTarget,
    bool clearPendingTarget = false,
  }) => HammerState(
    count: count ?? this.count,
    isTargeting: isTargeting ?? this.isTargeting,
    strike: strike ?? this.strike,
    strikes: strikes ?? this.strikes,
    pendingTarget: clearPendingTarget
        ? null
        : (pendingTarget ?? this.pendingTarget),
  );

  /// O mesmo estoque, sem nada de uma partida.
  ///
  /// É o que atravessa o início de uma fase ou corrida nova: o saldo é do
  /// jogador, a mira e o estilhaço eram da partida que acabou.
  HammerState get inventoryOnly => HammerState(count: count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HammerState &&
          count == other.count &&
          isTargeting == other.isTargeting &&
          strike == other.strike &&
          strikes == other.strikes &&
          pendingTarget == other.pendingTarget;

  @override
  int get hashCode =>
      Object.hash(count, isTargeting, strike, strikes, pendingTarget);

  @override
  String toString() =>
      'HammerState($count em estoque, mirando: $isTargeting, '
      '$strikes golpes)';
}

/// A regra do Martelo de Fusão, compartilhada pelos dois modos de jogo.
///
/// Existe como mixin porque campanha e Endless têm notifiers irmãos, e não pai e
/// filho: cada um tem o seu estado, o seu desfecho e a sua contagem. O que eles
/// **não** têm é uma segunda versão do booster — duas cópias da mesma regra
/// divergiriam no primeiro ajuste de balanceamento, e o jogador veria o mesmo
/// item se comportar de dois jeitos.
///
/// Quem implementa fornece cinco coisas: onde está o tabuleiro, qual é o motor,
/// como ler e escrever o [HammerState], se a partida aceita interação agora, e o
/// que fazer com a [Resolution] do golpe.
mixin HammerBooster<S> on StateNotifier<S> {
  /// Batida leve ao entrar no modo de mira, e aviso de mira errada.
  ///
  /// Injetáveis porque são o único ponto daqui que fala com a plataforma: nos
  /// testes viram contadores, e a suíte não depende de canal nativo. São únicos
  /// para os dois modos — o mesmo item não deve soar diferente em cada tela.
  static void Function() targetingFeedback = HapticFeedback.selectionClick;

  static void Function() rejectionFeedback = () =>
      SystemSound.play(SystemSoundType.alert);

  // --- o que cada notifier fornece -------------------------------------------

  GameStorage get hammerStorage;

  /// Motor da partida em curso. Nulo antes de ela começar.
  MatchEngine? get hammerEngine;

  Board get hammerBoard;

  HammerState get hammer;

  /// Publica o novo [HammerState] no estado do notifier.
  void writeHammer(HammerState value);

  /// A partida aceita interação agora: em andamento e sem encenação no ar.
  bool get acceptsHammer;

  /// Aplica a resolução do golpe. Cada modo tem o seu desfecho — o que os dois
  /// têm em comum é que o golpe **não conta como movimento**.
  void playHammerResolution(MatchEngine engine, Resolution resolution);

  // --- ações -----------------------------------------------------------------

  /// Liga ou desliga o modo de mira.
  void toggleHammerTargeting() {
    if (!acceptsHammer) return;

    if (hammer.isTargeting) {
      cancelHammerTargeting();
      return;
    }

    targetingFeedback();
    writeHammer(hammer.copyWith(isTargeting: true));
    onHammerTargetingStarted();
  }

  /// Gancho para o notifier limpar o que não convive com a mira — a seleção de
  /// troca, por exemplo: uma peça acesa para trocar, enquanto o dedo vai
  /// martelar, diz duas coisas ao mesmo tempo.
  void onHammerTargetingStarted() {}

  /// Sai do modo de mira, descartando o alvo pendente.
  void cancelHammerTargeting() {
    writeHammer(hammer.copyWith(isTargeting: false, clearPendingTarget: true));
  }

  /// Bate na célula [pos]: oblitera peça e cobertura, sem gastar movimento.
  ///
  /// Mira errada (fora do tabuleiro, casa vazia) avisa e **não cobra** — a mira
  /// continua ligada, para o jogador tentar de novo. Cobrar um martelo por um
  /// erro de dedo é o pior lugar possível para o jogo cobrar.
  ///
  /// Com estoque zero o alvo é apenas guardado, e quem abre o convite de
  /// aquisição é a tela. O golpe sai depois, em [grantHammer].
  void useHammer(Position pos) {
    if (hammerEngine == null || !acceptsHammer) return;

    if (hammerBoard.getTileAt(pos) == null) {
      rejectionFeedback();
      return;
    }

    if (hammer.count <= 0) {
      writeHammer(hammer.copyWith(pendingTarget: pos));
      return;
    }

    _strike(pos);
  }

  /// Credita martelos e, se havia alvo escolhido no Modo Fantasma, bate nele.
  void grantHammer({int count = 1}) {
    _setHammerCount(hammer.count + count);

    final pending = hammer.pendingTarget;
    if (pending == null || hammerEngine == null || !acceptsHammer) return;

    if (hammerBoard.getTileAt(pending) == null) {
      // O tabuleiro pode ter andado enquanto o anúncio rodava. O martelo fica no
      // estoque; o que se perde é só a mira.
      cancelHammerTargeting();
      return;
    }

    _strike(pending);
  }

  void _strike(Position pos) {
    final engine = hammerEngine!;
    final victim = hammerBoard.getTileAt(pos);
    final resolution = engine.smash(hammerBoard, pos);
    if (victim == null || resolution == null) {
      rejectionFeedback();
      return;
    }

    _setHammerCount(hammer.count - 1);
    writeHammer(
      hammer.copyWith(
        isTargeting: false,
        clearPendingTarget: true,
        strike: (pos, victim.value),
        strikes: hammer.strikes + 1,
      ),
    );

    playHammerResolution(engine, resolution);
  }

  /// Grava o novo saldo e o publica no estado.
  ///
  /// A gravação é assíncrona e o estado não espera por ela: travar a jogada até o
  /// disco responder seria pagar latência de I/O no meio da partida. Falha de
  /// escrita custa o inventário na próxima abertura, e não a jogada de agora.
  void _setHammerCount(int count) {
    writeHammer(hammer.copyWith(count: count));
    _persistHammers(count);
  }

  Future<void> _persistHammers(int count) async {
    try {
      await hammerStorage.writeHammerCount(count);
    } catch (error, stack) {
      debugPrint('Falha ao gravar o inventário de martelos: $error\n$stack');
    }
  }

  /// Relê o estoque do disco.
  ///
  /// Chamado ao começar uma fase ou corrida, e não só no construtor: os dois
  /// notifiers podem estar vivos ao mesmo tempo (a tela do Endless é aberta por
  /// cima da campanha), então um martelo gasto num modo tem de aparecer gasto no
  /// outro. É o mesmo remédio que `EndlessHighScore.refresh` já usa para o
  /// recorde.
  ///
  /// Uma leitura que chega depois de o saldo ter mudado em memória é descartada:
  /// o disco está velho, e adotá-lo apagaria um martelo recém-creditado.
  Future<void> refreshHammers() async {
    final before = hammer.count;
    try {
      final saved = await hammerStorage.readHammerCount();
      if (!mounted || hammer.count != before) return;
      writeHammer(hammer.copyWith(count: saved));
    } catch (error, stack) {
      debugPrint('Falha ao ler o inventário de martelos: $error\n$stack');
    }
  }
}
