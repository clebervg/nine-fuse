import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// A Bomba, do ponto de vista do estado.
///
/// Espelha [HammerState] de propósito — mesmo formato, mesmos campos — mas é
/// uma classe **irmã**, não uma generalização dos dois num tipo comum: Martelo
/// e Bomba são mecânicas diferentes (uma célula contra uma área 3x3), e a
/// regra do projeto de "não duplicar a mesma lógica" é sobre as **duas telas**
/// do mesmo booster (campanha e Endless), não sobre dois boosters distintos.
/// Generalizar os dois num tipo só criaria acoplamento entre regras que podem
/// divergir no primeiro ajuste de balanceamento de qualquer um deles.
@immutable
class BombState {
  const BombState({
    this.count = 0,
    this.isTargeting = false,
    this.strike,
    this.strikes = 0,
  });

  /// Bombas em estoque. Inventário do jogador, como o Martelo.
  final int count;

  /// O jogador está escolhendo o centro da área 3x3.
  ///
  /// Sem Modo Fantasma: ao contrário do Martelo, a Bomba não tem funil de
  /// aquisição hoje — estoque zero simplesmente recusa o toque no dock, sem
  /// entrar em mira.
  final bool isTargeting;

  /// O centro do último estouro e **cada célula realmente destruída**, com o
  /// dígito que ela carregava.
  ///
  /// O mapa (e não só o centro) existe porque a explosão pode atingir até 9
  /// células — a UI precisa de um estilhaço por peça destruída, não um só no
  /// centro, e por isso não basta guardar `(Position, int)` como o Martelo
  /// guarda para um golpe de célula única.
  final (Position, Map<Position, int>)? strike;

  /// Quantas explosões esta partida já teve. Só serve de chave para a
  /// animação, mesmo papel de `HammerState.strikes`.
  final int strikes;

  BombState copyWith({
    int? count,
    bool? isTargeting,
    (Position, Map<Position, int>)? strike,
    int? strikes,
  }) => BombState(
    count: count ?? this.count,
    isTargeting: isTargeting ?? this.isTargeting,
    strike: strike ?? this.strike,
    strikes: strikes ?? this.strikes,
  );

  /// O mesmo estoque, sem nada de uma partida — mesmo papel de
  /// `HammerState.inventoryOnly`.
  BombState get inventoryOnly => BombState(count: count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BombState &&
          count == other.count &&
          isTargeting == other.isTargeting &&
          strike == other.strike &&
          strikes == other.strikes;

  @override
  int get hashCode => Object.hash(count, isTargeting, strike, strikes);

  @override
  String toString() =>
      'BombState($count em estoque, mirando: $isTargeting, $strikes '
      'explosões)';
}

/// A regra da Bomba, compartilhada pelos dois modos de jogo — mesmo desenho
/// de [HammerBooster], sem o funil de aquisição (Modo Fantasma, anúncio,
/// compra): não foi pedido para a Bomba, e adicioná-lo sem pedido inventaria
/// um fluxo de monetização que o dono do produto não decidiu ainda.
mixin BombBooster<S> on StateNotifier<S> {
  /// Mesmos três avisos do Martelo, e pelo mesmo motivo: engajar a mira,
  /// errar a mira e o estouro precisam soar diferentes um do outro.
  static void Function() targetingFeedback = () {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  };

  static void Function() rejectionFeedback = () =>
      SystemSound.play(SystemSoundType.alert);

  /// O estouro é mais violento que o golpe do Martelo — nove células em vez
  /// de uma —, mas o projeto não tem um nível de intensidade tátil maior que
  /// `heavyImpact`; a diferença de peso fica para o Screen Shake, que aceita
  /// amplitude maior.
  static void Function() strikeFeedback = HapticFeedback.heavyImpact;

  // --- o que cada notifier fornece -------------------------------------------

  GameStorage get bombStorage;

  MatchEngine? get bombEngine;

  Board get bombBoard;

  BombState get bomb;

  void writeBomb(BombState value);

  /// A partida aceita interação agora: em andamento e sem encenação no ar.
  bool get acceptsBomb;

  /// Aplica a resolução do estouro. Não conta como movimento, igual ao
  /// Martelo.
  void playBombResolution(MatchEngine engine, Resolution resolution);

  // --- ações -----------------------------------------------------------------

  /// Liga ou desliga o modo de mira. Estoque zero recusa em vez de entrar em
  /// mira — sem Modo Fantasma aqui.
  void toggleBombTargeting() {
    if (!acceptsBomb) return;

    if (bomb.isTargeting) {
      cancelBombTargeting();
      return;
    }

    if (bomb.count <= 0) {
      rejectionFeedback();
      return;
    }

    targetingFeedback();
    writeBomb(bomb.copyWith(isTargeting: true));
    onBombTargetingStarted();
  }

  /// Gancho para o notifier limpar o que não convive com a mira da bomba —
  /// mesmo papel de `HammerBooster.onHammerTargetingStarted`.
  void onBombTargetingStarted() {}

  void cancelBombTargeting() {
    writeBomb(bomb.copyWith(isTargeting: false));
  }

  /// Explode a área 3x3 centrada em [pos]. Mira errada (fora do tabuleiro,
  /// área inteira vazia) avisa e não cobra — mesma régua do Martelo.
  void useBomb(Position pos) {
    if (bombEngine == null || !acceptsBomb || bomb.count <= 0) return;

    final engine = bombEngine!;
    final board = bombBoard;

    // O mapa de destruídos é montado **antes** do estouro, a partir do
    // tabuleiro atual: depois de `smashArea` as células já estão vazias, e a
    // UI perderia de onde tirar o dígito e a cor de cada estilhaço.
    final destroyed = <Position, int>{
      for (int row = pos.row - 1; row <= pos.row + 1; row++)
        for (int col = pos.col - 1; col <= pos.col + 1; col++)
          if (Board.contains(Position(row: row, col: col)))
            if (board.getTileAt(Position(row: row, col: col)) case final tile?)
              Position(row: row, col: col): tile.value,
    };

    final resolution = engine.smashArea(board, pos);
    if (resolution == null) {
      rejectionFeedback();
      return;
    }

    strikeFeedback();
    _setBombCount(bomb.count - 1);
    writeBomb(
      bomb.copyWith(
        isTargeting: false,
        strike: (pos, destroyed),
        strikes: bomb.strikes + 1,
      ),
    );

    playBombResolution(engine, resolution);
  }

  /// Credita bombas ao inventário do jogador.
  void grantBomb({int count = 1}) => _setBombCount(bomb.count + count);

  void _setBombCount(int count) {
    writeBomb(bomb.copyWith(count: count));
    _persistBombs(count);
  }

  Future<void> _persistBombs(int count) async {
    try {
      await bombStorage.writeBombCount(count);
    } catch (error, stack) {
      debugPrint('Falha ao gravar o inventário de bombas: $error\n$stack');
    }
  }

  /// Relê o estoque do disco — mesmo remédio de `HammerBooster.refreshHammers`,
  /// pelo mesmo motivo: os dois modos de jogo podem estar vivos ao mesmo tempo
  /// e compartilham o saldo.
  Future<void> refreshBombs() async {
    final before = bomb.count;
    try {
      final saved = await bombStorage.readBombCount();
      if (!mounted || bomb.count != before) return;
      writeBomb(bomb.copyWith(count: saved));
    } catch (error, stack) {
      debugPrint('Falha ao ler o inventário de bombas: $error\n$stack');
    }
  }
}
