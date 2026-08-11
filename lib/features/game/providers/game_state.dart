import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

/// Por que a fase foi perdida.
///
/// Existe porque as duas causas são **independentes** e a UI não deve inferir
/// uma da outra: um relato de "falso fim de jogo" veio justamente daí — a fase
/// acabou por saldo de movimentos, o tabuleiro seguia cheio de jogadas, e a
/// mensagem "os movimentos acabaram" foi lida como "não há mais jogadas".
enum LossReason {
  /// O limite de movimentos da fase chegou a zero sem o objetivo cumprido.
  /// Só existe na campanha; o tabuleiro continua jogável.
  moveLimitReached,

  /// Não há nenhuma troca que forme combinação. Nada a ver com saldo.
  boardStuck,
}

/// Situação da fase em andamento.
enum GameStatus {
  /// Nenhuma fase começou.
  idle,

  playing,

  /// Objetivo cumprido.
  won,

  /// Movimentos esgotados, ou tabuleiro sem jogada possível.
  lost,
}

/// Estado imutável de uma fase em andamento.
class GameState {
  const GameState({
    required this.board,
    required this.level,
    this.score = 0,
    this.status = GameStatus.idle,
    this.selectedTile,
    this.moves = 0,
    this.objectiveProgress = 0,
    this.rejectedSwap,
    this.hint,
    this.bigFusionTileIds = const {},
    this.activeStep,
    this.comboCount = 0,
    this.isResolving = false,
    this.lossReason,
    this.bonusMoves = 0,
    this.runId = 0,
    this.apexCelebrated = false,
    this.boardObstacleGoal,
  });

  final Board board;

  /// A fase sendo jogada: objetivo, limite de movimentos e janela de spawn.
  final GameLevel level;

  final int score;
  final GameStatus status;
  final Tile? selectedTile;

  /// Movimentos gastos. Troca recusada não conta.
  final int moves;

  /// O quanto do objetivo já foi cumprido.
  ///
  /// A unidade depende do tipo do objetivo: peças **criadas** por fusão no
  /// [ObjectiveType.reachDigit], coberturas **destruídas** nos outros dois.
  final int objectiveProgress;

  /// Quantas coberturas do tipo pedido o tabuleiro sorteado realmente trouxe.
  ///
  /// Só vale para [ObjectiveType.clearAllObstacles], e é fixado quando a fase
  /// começa. Existe porque `placeObstacles` descarta a cobertura que não acha
  /// lugar: cobrar do jogador as quatro pedras que a fase pediu, quando o
  /// tabuleiro só coube três, seria uma fase impossível por acidente de sorteio.
  ///
  /// Nulo fora desse objetivo — e também quando o tabuleiro foi montado à mão
  /// antes de o valor ser calculado, caso em que [objectiveTarget] o deduz do
  /// que ainda está no tabuleiro mais o que já foi quebrado.
  final int? boardObstacleGoal;

  /// Posições da última troca recusada por não formar combinação. A UI usa
  /// isso para animar a volta das peças; `null` quando não houve recusa.
  final (Position, Position)? rejectedSwap;

  /// Uma jogada que funciona, para a UI destacar quando o jogador travar.
  /// `null` significa que não existe jogada — o mesmo que fim de fase.
  final (Position, Position)? hint;

  /// Peças nascidas de combinação grande no último movimento, para a UI dar a
  /// elas um efeito mais forte.
  final Set<String> bigFusionTileIds;

  /// Passo da cascata sendo encenado agora. `null` fora de uma jogada.
  final ResolutionStep? activeStep;

  /// Número da cascata em curso: 1 é o movimento do jogador, 2+ são as
  /// cascatas que ele desencadeou. Alimenta o aviso de combo.
  final int comboCount;

  /// A jogada está sendo encenada. Enquanto isso o tabuleiro não aceita
  /// toques — deixar o jogador jogar por cima da animação embaralharia o que
  /// ele está vendo com o que já aconteceu.
  final bool isResolving;

  /// Por que perdeu. Nulo fora de [GameStatus.lost].
  ///
  /// Registrado pelo notifier, que é quem sabe. Deixar a UI deduzir pelo saldo
  /// de movimentos foi a origem da mensagem confusa de fim de jogo.
  final LossReason? lossReason;

  /// Movimentos ganhos de presente ao criar o dígito máximo.
  ///
  /// Somam ao limite da fase em vez de descontar do gasto: assim o histórico de
  /// [moves] continua sendo "quantas jogadas o jogador fez", que é o que o
  /// cartão de fim de fase relata.
  final int bonusMoves;

  /// Contador de partidas iniciadas, incrementado a cada `startLevel`.
  ///
  /// Existe porque "uma fase começou" não dá para deduzir do resto do estado:
  /// recomeçar a fase atual sem tê-la perdido é `playing → playing`, com o
  /// mesmo número de fase — indistinguível de nada ter acontecido. A UI usa
  /// isto para reabrir o cartão de início.
  final int runId;

  /// A partida já criou o dígito máximo pelo menos uma vez.
  ///
  /// Serve à comemoração de fusão máxima, que aparece **uma vez por partida**:
  /// repetir a cada 9 transformaria a conquista em ruído. Vive no estado, e não
  /// na tela, porque quem sabe que a explosão aconteceu é o notifier — a UI só
  /// vê o tabuleiro antes e depois.
  final bool apexCelebrated;

  /// Tudo o que a fase ofereceu de movimento: o limite mais os bônus.
  int get movesAvailable => level.moveLimit + bonusMoves;

  /// Movimentos que ainda restam, nunca negativo.
  int get movesLeft => (movesAvailable - moves).clamp(0, movesAvailable);

  /// Quanto o objetivo pede, nesta partida.
  ///
  /// Quase sempre é o número declarado pela fase. A exceção é
  /// [ObjectiveType.clearAllObstacles], em que "todas" só tem sentido contra o
  /// tabuleiro que o jogador recebeu.
  int get objectiveTarget =>
      level.objective.type == ObjectiveType.clearAllObstacles
      // Restantes + já quebradas: a soma é invariante porque nenhuma cobertura
      // nasce no meio da fase. É o que salva o caso do tabuleiro montado à mão.
      ? boardObstacleGoal ??
            board.countObstacles(level.objective.obstacle) + objectiveProgress
      : level.objective.count;

  /// O objetivo já foi cumprido?
  bool get objectiveMet => objectiveProgress >= objectiveTarget;

  /// Fração do objetivo concluída, de 0 a 1. Serve para a barra de progresso.
  double get objectiveFraction => objectiveTarget <= 0
      ? 1.0
      : (objectiveProgress / objectiveTarget).clamp(0.0, 1.0);

  /// A fase terminou, de qualquer forma?
  bool get isOver => status == GameStatus.won || status == GameStatus.lost;

  /// Cria um novo GameState com valores opcionalmente alterados.
  ///
  /// [selectedTile] e [rejectedSwap] precisam poder voltar a `null`, o que
  /// `??` não permite — daí as flags `clear*` explícitas.
  GameState copyWith({
    Board? board,
    GameLevel? level,
    int? score,
    GameStatus? status,
    Tile? selectedTile,
    bool clearSelectedTile = false,
    int? moves,
    int? objectiveProgress,
    (Position, Position)? rejectedSwap,
    bool clearRejectedSwap = false,
    (Position, Position)? hint,
    bool clearHint = false,
    Set<String>? bigFusionTileIds,
    ResolutionStep? activeStep,
    bool clearActiveStep = false,
    int? comboCount,
    bool? isResolving,
    LossReason? lossReason,
    bool clearLossReason = false,
    int? bonusMoves,
    int? runId,
    bool? apexCelebrated,
    int? boardObstacleGoal,
    bool clearBoardObstacleGoal = false,
  }) => GameState(
    board: board ?? this.board,
    level: level ?? this.level,
    score: score ?? this.score,
    status: status ?? this.status,
    selectedTile: clearSelectedTile
        ? null
        : (selectedTile ?? this.selectedTile),
    moves: moves ?? this.moves,
    objectiveProgress: objectiveProgress ?? this.objectiveProgress,
    rejectedSwap: clearRejectedSwap
        ? null
        : (rejectedSwap ?? this.rejectedSwap),
    hint: clearHint ? null : (hint ?? this.hint),
    bigFusionTileIds: bigFusionTileIds ?? this.bigFusionTileIds,
    activeStep: clearActiveStep ? null : (activeStep ?? this.activeStep),
    comboCount: comboCount ?? this.comboCount,
    isResolving: isResolving ?? this.isResolving,
    lossReason: clearLossReason ? null : (lossReason ?? this.lossReason),
    bonusMoves: bonusMoves ?? this.bonusMoves,
    runId: runId ?? this.runId,
    apexCelebrated: apexCelebrated ?? this.apexCelebrated,
    boardObstacleGoal: clearBoardObstacleGoal
        ? null
        : (boardObstacleGoal ?? this.boardObstacleGoal),
  );

  /// Estado antes de qualquer fase começar.
  factory GameState.initial() => GameState(
    board: Board.empty(),
    level: kCampaign.first,
    status: GameStatus.idle,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          board == other.board &&
          level == other.level &&
          score == other.score &&
          status == other.status &&
          selectedTile == other.selectedTile &&
          moves == other.moves &&
          objectiveProgress == other.objectiveProgress &&
          rejectedSwap == other.rejectedSwap &&
          hint == other.hint &&
          identical(activeStep, other.activeStep) &&
          comboCount == other.comboCount &&
          isResolving == other.isResolving &&
          lossReason == other.lossReason &&
          bonusMoves == other.bonusMoves &&
          runId == other.runId &&
          apexCelebrated == other.apexCelebrated &&
          boardObstacleGoal == other.boardObstacleGoal;

  @override
  int get hashCode => Object.hash(
    board,
    level,
    score,
    status,
    selectedTile,
    moves,
    objectiveProgress,
    rejectedSwap,
    hint,
    activeStep,
    comboCount,
    isResolving,
    lossReason,
    bonusMoves,
    runId,
    apexCelebrated,
    boardObstacleGoal,
  );

  @override
  String toString() =>
      'GameState(fase ${level.number}, $status, '
      '$objectiveProgress/$objectiveTarget do objetivo, '
      '$moves/$movesAvailable mov, score $score)';
}
