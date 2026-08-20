import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_balance_engine.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/providers/hammer_booster.dart';

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

/// Com quantos movimentos restantes o jogo oferece o reforço de saldo.
///
/// Dois, e não zero: no zero a fase já acabou, e a tela que estaria no ar é a
/// de derrota — onde a regra anti-churn proíbe monetizar. Oferecer com o
/// jogador ainda jogando faz a proposta ser sobre **continuar**, e não sobre
/// reviver; ele decide olhando para um tabuleiro vivo, não para um resultado.
const int kPreChurnMovesLeft = 2;

/// Quantas derrotas seguidas na mesma fase sugerem o Modo Recorde.
///
/// Três, e não uma: sugerir na primeira derrota leria como o jogo desistindo
/// do jogador antes dele. É o mesmo limiar que a análise de retenção do
/// produto definiu como "energia da fase acabou".
const int kConsecutiveLossesForEndlessOffer = 3;

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
    this.explosions = 0,
    this.movesOfferShown = false,
    this.boardObstacleGoal,
    this.hammer = const HammerState(),
    this.consecutiveLosses = 0,
    this.endlessOfferShown = false,
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

  /// Quantos dígitos máximos esta partida já detonou.
  ///
  /// Não se confunde com [apexCelebrated], que é um sinal de uma vez só: o
  /// aviso de "FUSÃO MÁXIMA" aparece uma vez por partida, mas o **tranco** do
  /// tabuleiro é de cada explosão. Um `bool` que nunca desliga não distingue a
  /// segunda explosão da primeira, e a segunda não sacudiria nada.
  ///
  /// É contado por explosão, e não por jogada: uma cascata que detona dois
  /// dígitos máximos soma dois — a mesma unidade que já paga o bônus de
  /// movimentos em `kExplosionBonusMoves`.
  final int explosions;

  /// O convite de reforço de saldo já foi mostrado nesta partida.
  ///
  /// Uma vez por fase, e não uma vez por movimento: [shouldOfferMoves] continua
  /// verdadeiro enquanto o saldo ficar no limiar, e sem esta trava o convite
  /// voltaria a cada jogada. Um anúncio que se reoferece sozinho é exatamente o
  /// churn que ele deveria estar evitando.
  ///
  /// Vive na partida, e não no jogador: recomeçar a fase devolve o convite,
  /// porque a aflição também recomeça.
  final bool movesOfferShown;

  /// Quantas vezes seguidas o jogador perdeu **esta mesma fase**.
  ///
  /// Vive só em memória: fechar o app no meio de uma sequência de derrotas
  /// zera a contagem, e é uma perda aceitável — o contador é gatilho de
  /// sugestão, não métrica de produto que precise sobreviver a reinícios.
  /// Reseta ao vencer a fase ou ao trocar para outra (ver [GameNotifier]);
  /// **não** reseta ao simplesmente recomeçar a mesma fase perdida, porque é
  /// justamente essa sequência de tentativas que o contador mede.
  final int consecutiveLosses;

  /// O convite de migração para o Modo Recorde já foi mostrado nesta fase.
  ///
  /// Mesma razão de [movesOfferShown]: sem a trava, [shouldOfferEndless]
  /// continuaria verdadeiro a cada nova derrota depois da terceira, e o
  /// convite reabriria sozinho.
  final bool endlessOfferShown;

  /// O Martelo de Fusão: estoque, mira e último golpe.
  ///
  /// Num objeto só, e não em cinco campos soltos, porque o Endless carrega
  /// exatamente o mesmo conjunto — ver [HammerState] e [HammerBooster].
  final HammerState hammer;

  /// Atalhos de leitura para a UI e para os testes. O estado é um só; estes
  /// getters só evitam `state.hammer.count` espalhado por toda a apresentação.
  int get hammerCount => hammer.count;
  bool get isHammerTargeting => hammer.isTargeting;
  (Position, int)? get hammerStrike => hammer.strike;
  int get hammerStrikes => hammer.strikes;
  Position? get pendingHammerTarget => hammer.pendingTarget;

  /// Quantos trancos o tabuleiro já levou nesta partida.
  ///
  /// Golpe de martelo e explosão do dígito máximo são dois motivos para a mesma
  /// sacudida, e o `StrikeShake` só reage a um serial que **cresce**. Somar os
  /// dois num número só mantém a garantia de monotonia — dois contadores
  /// separados alimentando o mesmo widget fariam a explosão zerar o tranco do
  /// martelo, e vice-versa.
  int get shakeSerial => hammerStrikes + explosions;

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

  /// Quantos movimentos o anúncio de reforço de saldo paga **nesta fase**.
  ///
  /// Existe como getter — e não como cálculo na tela ou no crédito — porque o
  /// cartão anuncia o número **antes** de o anúncio rodar. Dois consumidores
  /// lendo lugares diferentes divergiriam no primeiro refactor, e a divergência
  /// apareceria como o jogo prometendo dez movimentos e pagando quatro.
  int get rewardedMoves => GameBalanceEngine.calculateRewardedMoves(
    remainingTargets: objectiveTarget - objectiveProgress,
  );

  /// A fase terminou, de qualquer forma?
  bool get isOver => status == GameStatus.won || status == GameStatus.lost;

  /// A fase está apertada o bastante para valer o convite de reforço de saldo?
  ///
  /// As guardas são independentes e nenhuma é decorativa:
  /// **fase em andamento** (na fase encerrada quem está no ar é o cartão de
  /// desfecho, e a regra anti-churn proíbe o anúncio ali), **nada sendo
  /// encenado** (o convite por cima da cascata esconderia justamente o quadro
  /// que explica o saldo), **objetivo em aberto** (com a fase ganha na prática,
  /// vender movimento é vender nada), **ainda não mostrado** e **pelo menos uma
  /// jogada feita**.
  ///
  /// A última é a que separa aflição de desenho de fase: uma fase que já nasce
  /// no limiar é apertada de projeto, e sem essa guarda o convite subiria por
  /// cima do tabuleiro antes do primeiro toque — vendendo movimento a quem
  /// ainda não gastou nenhum, com um "quase lá" que seria falso.
  bool get shouldOfferMoves =>
      status == GameStatus.playing &&
      !isResolving &&
      !objectiveMet &&
      !movesOfferShown &&
      moves > 0 &&
      movesLeft <= kPreChurnMovesLeft;

  /// A fase acabou de perder feio o bastante para valer sugerir o Modo
  /// Recorde?
  ///
  /// As três guardas: **fase perdida** (o convite é sobre o desfecho, não
  /// sobre uma fase em andamento — diferente do convite de movimentos, que é
  /// pre-churn), **contador no limiar** e **ainda não mostrado nesta fase**.
  /// Não checa se o Endless está desbloqueado: `GameState` não tem acesso ao
  /// progresso da campanha (é outro provider); quem combina os dois é
  /// `game_screen.dart`.
  bool get shouldOfferEndless =>
      status == GameStatus.lost &&
      consecutiveLosses >= kConsecutiveLossesForEndlessOffer &&
      !endlessOfferShown;

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
    int? explosions,
    bool? movesOfferShown,
    int? boardObstacleGoal,
    bool clearBoardObstacleGoal = false,
    HammerState? hammer,
    int? consecutiveLosses,
    bool? endlessOfferShown,
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
    explosions: explosions ?? this.explosions,
    movesOfferShown: movesOfferShown ?? this.movesOfferShown,
    boardObstacleGoal: clearBoardObstacleGoal
        ? null
        : (boardObstacleGoal ?? this.boardObstacleGoal),
    hammer: hammer ?? this.hammer,
    consecutiveLosses: consecutiveLosses ?? this.consecutiveLosses,
    endlessOfferShown: endlessOfferShown ?? this.endlessOfferShown,
  );

  /// Estado antes de qualquer fase começar.
  factory GameState.initial() => GameState(
    board: Board.empty(),
    level: levelAt(1),
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
          explosions == other.explosions &&
          movesOfferShown == other.movesOfferShown &&
          boardObstacleGoal == other.boardObstacleGoal &&
          hammer == other.hammer &&
          consecutiveLosses == other.consecutiveLosses &&
          endlessOfferShown == other.endlessOfferShown;

  // `hashAll` em vez de `hash`: com os campos do martelo o estado passou de 20
  // componentes, que é o teto posicional de `Object.hash`.
  @override
  int get hashCode => Object.hashAll([
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
    explosions,
    movesOfferShown,
    boardObstacleGoal,
    hammer,
    consecutiveLosses,
    endlessOfferShown,
  ]);

  @override
  String toString() =>
      'GameState(fase ${level.number}, $status, '
      '$objectiveProgress/$objectiveTarget do objetivo, '
      '$moves/$movesAvailable mov, score $score)';
}
