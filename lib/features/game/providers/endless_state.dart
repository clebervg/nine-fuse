import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/endless_progression.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';

/// Situação de uma partida Endless.
enum EndlessStatus {
  idle,
  playing,

  /// Não há mais troca que forme combinação. No Endless isso não é falha: é o
  /// fim da corrida, e é o que dá sentido ao placar.
  stuck,
}

/// Estado imutável de uma partida Endless: sem objetivo, sem limite de
/// movimentos, dura até o tabuleiro travar.
class EndlessState {
  const EndlessState({
    required this.board,
    this.score = 0,
    this.status = EndlessStatus.idle,
    this.selectedTile,
    this.moves = 0,
    this.step = EndlessProgression.firstStep,
    this.highestDigit = 0,
    this.explosions = 0,
    this.isRecord = false,
    this.rejectedSwap,
    this.hint,
    this.bigFusionTileIds = const {},
    this.activeStep,
    this.comboCount = 0,
    this.isResolving = false,
    this.apexCelebrated = false,
  });

  final Board board;
  final int score;
  final EndlessStatus status;
  final Tile? selectedTile;
  final int moves;

  /// Degrau da janela de sorteio. Ver [EndlessProgression].
  final int step;

  /// Maior dígito já criado nesta partida.
  final int highestDigit;

  /// Explosões do dígito máximo nesta partida.
  final int explosions;

  /// A partida bateu o recorde salvo.
  final bool isRecord;

  final (Position, Position)? rejectedSwap;

  /// Uma jogada que funciona, para a UI destacar quando o jogador travar.
  /// `null` significa tabuleiro sem saída — o fim da corrida.
  final (Position, Position)? hint;

  /// Peças nascidas de combinação grande no último movimento.
  final Set<String> bigFusionTileIds;

  /// Passo da cascata sendo encenado agora. `null` fora de uma jogada.
  final ResolutionStep? activeStep;

  /// Número da cascata em curso, para o aviso de combo.
  final int comboCount;

  /// A jogada está sendo encenada; o tabuleiro não aceita toques.
  final bool isResolving;

  /// A partida já criou o dígito máximo pelo menos uma vez.
  ///
  /// Serve à comemoração de fusão máxima, que aparece **uma vez por partida**:
  /// repetir a cada 9 transformaria a conquista em ruído.
  final bool apexCelebrated;

  bool get isOver => status == EndlessStatus.stuck;

  EndlessState copyWith({
    Board? board,
    int? score,
    EndlessStatus? status,
    Tile? selectedTile,
    bool clearSelectedTile = false,
    int? moves,
    int? step,
    int? highestDigit,
    int? explosions,
    bool? isRecord,
    (Position, Position)? rejectedSwap,
    bool clearRejectedSwap = false,
    (Position, Position)? hint,
    bool clearHint = false,
    Set<String>? bigFusionTileIds,
    ResolutionStep? activeStep,
    bool clearActiveStep = false,
    int? comboCount,
    bool? isResolving,
    bool? apexCelebrated,
  }) => EndlessState(
    board: board ?? this.board,
    score: score ?? this.score,
    status: status ?? this.status,
    selectedTile: clearSelectedTile
        ? null
        : (selectedTile ?? this.selectedTile),
    moves: moves ?? this.moves,
    step: step ?? this.step,
    highestDigit: highestDigit ?? this.highestDigit,
    explosions: explosions ?? this.explosions,
    isRecord: isRecord ?? this.isRecord,
    rejectedSwap: clearRejectedSwap
        ? null
        : (rejectedSwap ?? this.rejectedSwap),
    hint: clearHint ? null : (hint ?? this.hint),
    bigFusionTileIds: bigFusionTileIds ?? this.bigFusionTileIds,
    activeStep: clearActiveStep ? null : (activeStep ?? this.activeStep),
    comboCount: comboCount ?? this.comboCount,
    isResolving: isResolving ?? this.isResolving,
    apexCelebrated: apexCelebrated ?? this.apexCelebrated,
  );

  factory EndlessState.initial() => EndlessState(board: Board.empty());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EndlessState &&
          runtimeType == other.runtimeType &&
          board == other.board &&
          score == other.score &&
          status == other.status &&
          selectedTile == other.selectedTile &&
          moves == other.moves &&
          step == other.step &&
          highestDigit == other.highestDigit &&
          explosions == other.explosions &&
          isRecord == other.isRecord &&
          rejectedSwap == other.rejectedSwap &&
          hint == other.hint &&
          identical(activeStep, other.activeStep) &&
          comboCount == other.comboCount &&
          isResolving == other.isResolving &&
          apexCelebrated == other.apexCelebrated;

  @override
  int get hashCode => Object.hash(
    board,
    score,
    status,
    selectedTile,
    moves,
    step,
    highestDigit,
    explosions,
    isRecord,
    rejectedSwap,
    hint,
    activeStep,
    comboCount,
    isResolving,
    apexCelebrated,
  );

  @override
  String toString() =>
      'EndlessState($status, $score pts, $moves mov, '
      'degrau $step, maior $highestDigit)';
}
