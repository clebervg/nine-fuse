import 'package:flutter/material.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/domain/tile.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';
import 'package:nine_fuse/features/game/presentation/widgets/tile_widget.dart';

/// Chave da área tocável de uma posição do tabuleiro.
///
/// O toque é endereçado por **posição** e o desenho por **identidade da peça**:
/// são coisas diferentes. Uma peça em queda muda de posição no meio da
/// animação, e o toque precisa continuar valendo pela célula, não por onde o
/// desenho está naquele instante.
Key tileKey(Position position) => Key('tile_${position.row}_${position.col}');

/// Chave do desenho de uma peça, estável enquanto ela existir.
Key tileVisualKey(String tileId) => Key('tile_visual_$tileId');

/// Chave do rastro de uma peça que está saindo do tabuleiro.
Key tileExitKey(String tileId) => Key('tile_exit_$tileId');

/// Duração da queda e do deslize das peças.
const Duration kTileMoveDuration = Duration(milliseconds: 220);

/// Duração do vai-e-volta de uma troca recusada.
const Duration kRejectedSwapDuration = Duration(milliseconds: 260);

/// Duração do desaparecimento de uma peça consumida pela fusão.
const Duration kTileExitDuration = Duration(milliseconds: 180);

/// Quanto tempo parado antes de o tabuleiro apontar uma jogada.
///
/// Longo o bastante para não atropelar quem está pensando, curto o bastante
/// para resgatar quem travou. O tabuleiro 8x8 costuma esconder a jogada num
/// canto, e varrer as 64 células à mão é cansativo.
const Duration kHintDelay = Duration(seconds: 6);

/// Tempo que o brilho da dica leva para acender.
const Duration kHintFadeDuration = Duration(milliseconds: 400);

/// Tabuleiro 8x8 animado.
///
/// As peças ficam num [Stack] em coordenadas absolutas, com a chave amarrada ao
/// id da peça. Assim, quando uma peça muda de lugar, o Flutter reaproveita o
/// mesmo widget e o [AnimatedPositioned] interpola o movimento — em vez de duas
/// células simplesmente trocarem de conteúdo.
class BoardGridWidget extends StatefulWidget {
  const BoardGridWidget({
    super.key,
    required this.board,
    this.selectedTile,
    this.rejectedSwap,
    this.hint,
    this.bigFusionTileIds = const {},
    this.hintEnabled = true,
    this.onTileTap,
    this.onTileSwipe,
  });

  final Board board;
  final Tile? selectedTile;

  /// Troca recusada a animar. A UI mostra o vai-e-volta; sem isso o toque
  /// parece não ter funcionado.
  final (Position, Position)? rejectedSwap;

  /// Uma jogada possível, destacada depois de [kHintDelay] parado.
  final (Position, Position)? hint;

  /// Peças nascidas de combinação grande, que ganham efeito mais forte.
  final Set<String> bigFusionTileIds;

  /// Arrastar uma peça na direção da vizinha. É o gesto que o gênero
  /// consagrou; o toque duplo continua valendo como alternativa.
  final void Function(Position from, Position to)? onTileSwipe;

  /// Encurta a espera da dica nos testes.
  ///
  /// Sem isso todo `pumpAndSettle` teria de avançar os segundos do relógio de
  /// ociosidade, e a suíte de widget fica seis vezes mais lenta sem ganho
  /// nenhum de cobertura.
  @visibleForTesting
  static Duration? debugHintDelayOverride;

  static Duration get _effectiveHintDelay =>
      debugHintDelayOverride ?? kHintDelay;

  /// Desliga a dica. A fase acabada não deve ficar piscando sugestões.
  final bool hintEnabled;

  final void Function(Position)? onTileTap;

  @override
  State<BoardGridWidget> createState() => _BoardGridWidgetState();
}

class _BoardGridWidgetState extends State<BoardGridWidget>
    with TickerProviderStateMixin {
  late final AnimationController _rejection = AnimationController(
    vsync: this,
    duration: kRejectedSwapDuration,
  );

  /// Relógio da saída das peças. É um controlador, e não um `Future.delayed`,
  /// porque temporizador solto não respeita o relógio dos testes nem para
  /// quando o widget sai de tela.
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: kTileExitDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && _leaving.isNotEmpty) {
            setState(_leaving.clear);
          }
        });

  /// Vai a 1 no meio do caminho e volta a 0: as peças avançam uma para a outra
  /// e retornam.
  late final Animation<double> _nudge = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _rejection, curve: Curves.easeOut));

  /// Relógio da ociosidade. Acende a dica ao chegar ao fim.
  ///
  /// É um controlador, e não um `Timer`, por dois motivos: não deixa
  /// temporizador pendente nos testes, e o brilho acende sozinho ao final sem
  /// precisar de callback. A animação **não** se repete de propósito — um
  /// pulso infinito faria `pumpAndSettle` nunca terminar, quebrando toda a
  /// suíte de widget.
  late final Duration _delay = BoardGridWidget._effectiveHintDelay;

  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: _delay + kHintFadeDuration,
  );

  /// Intensidade do brilho: zero durante a espera, sobe até 1 no fim.
  late final Animation<double> _hintGlow = CurvedAnimation(
    parent: _idle,
    // A dica só começa a acender depois da espera.
    curve: Interval(
      _delay.inMilliseconds / (_delay + kHintFadeDuration).inMilliseconds,
      1,
      curve: Curves.easeIn,
    ),
  );

  /// Peças que saíram do tabuleiro e ainda estão desaparecendo.
  ///
  /// Sem isso a peça consumida pela fusão sumiria de um frame para o outro. Com
  /// as vizinhas deslizando suavemente, esse corte seco fica *mais* visível, não
  /// menos.
  final List<Tile> _leaving = [];

  @override
  void initState() {
    super.initState();
    _restartIdleClock();
  }

  @override
  void didUpdateWidget(BoardGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final rejected = widget.rejectedSwap;
    if (rejected != null && rejected != oldWidget.rejectedSwap) {
      _rejection.forward(from: 0);
    }

    _trackDepartures(oldWidget.board, widget.board);

    // Qualquer sinal de atividade zera a contagem: mexer no tabuleiro, mudar a
    // seleção, ou ter a troca recusada. Quem está tentando não precisa de dica.
    final acted =
        widget.board != oldWidget.board ||
        widget.selectedTile?.id != oldWidget.selectedTile?.id ||
        widget.rejectedSwap != oldWidget.rejectedSwap ||
        widget.hintEnabled != oldWidget.hintEnabled;

    if (acted) _restartIdleClock();
  }

  void _restartIdleClock() {
    if (widget.hintEnabled && widget.hint != null) {
      _idle.forward(from: 0);
    } else {
      _idle.stop();
      _idle.value = 0;
    }
  }

  /// Deslocamento acumulado do arraste em curso.
  Offset _drag = Offset.zero;

  /// Já resolvemos este arraste? Um gesto só vale uma troca: sem isso, manter
  /// o dedo pressionado dispararia trocas em sequência.
  bool _dragResolved = false;

  void _onDragUpdate(Position from, Offset delta, double tileSize) {
    if (_dragResolved) return;

    _drag += delta;

    // Um terço da célula: curto o bastante para responder rápido, longo o
    // bastante para não confundir tremor de dedo com intenção.
    final threshold = tileSize / 3;
    if (_drag.distance < threshold) return;

    // O eixo dominante decide a direção; arrasto na diagonal não é ambíguo.
    final target = _drag.dx.abs() > _drag.dy.abs()
        ? Position(row: from.row, col: from.col + (_drag.dx > 0 ? 1 : -1))
        : Position(row: from.row + (_drag.dy > 0 ? 1 : -1), col: from.col);

    _dragResolved = true;

    if (Board.contains(target)) widget.onTileSwipe?.call(from, target);
  }

  /// A peça em [position] faz parte da dica que está acesa?
  bool _isHinted(Position position) {
    final hint = widget.hint;
    if (hint == null || !widget.hintEnabled || _hintGlow.value == 0) {
      return false;
    }
    return position == hint.$1 || position == hint.$2;
  }

  void _trackDepartures(Board before, Board after) {
    final remaining = after.getAllTiles().map((tile) => tile.id).toSet();
    final survivors = before.getAllTiles().where(
      (tile) => remaining.contains(tile.id),
    );

    // Nenhuma peça sobreviveu: o tabuleiro foi **substituído**, não teve peças
    // eliminadas. Acontece ao recomeçar a fase, iniciar corrida nova ou dar
    // hot restart. Sem esta guarda, as 64 peças antigas viram rastro de uma vez
    // e o tabuleiro novo nasce coberto de dígitos fantasma.
    if (survivors.isEmpty) {
      if (_leaving.isNotEmpty) setState(_leaving.clear);
      return;
    }

    final departed = [
      for (final tile in before.getAllTiles())
        if (!remaining.contains(tile.id)) tile,
    ];

    if (departed.isEmpty) return;

    setState(() => _leaving.addAll(departed));
    // Uma nova leva reinicia o relógio, o que reacende as anteriores por um
    // instante. Como a resolução de um movimento chega de uma vez só, na
    // prática não há levas concorrentes.
    _exit.forward(from: 0);
  }

  @override
  void dispose() {
    _rejection.dispose();
    _exit.dispose();
    _idle.dispose();
    super.dispose();
  }

  /// Deslocamento da peça em [position] durante a animação de recusa: ela anda
  /// um pouco na direção da parceira e volta.
  Offset _rejectionOffset(Position position, double tileSize) {
    final rejected = widget.rejectedSwap;
    if (rejected == null || _nudge.value == 0) return Offset.zero;

    final (a, b) = rejected;
    final other = position == a ? b : (position == b ? a : null);
    if (other == null) return Offset.zero;

    // Um terço da célula é o suficiente para ler o gesto sem parecer que a
    // troca aconteceu.
    final travel = tileSize * 0.33 * _nudge.value;
    return Offset(
      (other.col - position.col) * travel,
      (other.row - position.row) * travel,
    );
  }

  /// O maior valor em jogo, ou `null` quando ele é comum demais para brilhar.
  ///
  /// Num tabuleiro recém-sorteado o topo é o teto da janela de spawn e aparece
  /// numa peça em cada quatro — acender dezesseis células de uma vez não
  /// destacaria nada. O brilho só faz sentido quando a peça alta é rara, que é
  /// exatamente quando ela importa: ela é a que o jogador precisa achar para
  /// fundir, e a que assoreia o tabuleiro se ficar sem par.
  int? _peakValue() {
    final values = widget.board.getAllTiles().map((t) => t.value).toList();
    if (values.isEmpty) return null;

    final peak = values.reduce((a, b) => a > b ? a : b);
    final count = values.where((v) => v == peak).length;

    return count <= kPeakGlowMaxTiles ? peak : null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A geometria é montada sobre o **lado da moldura**, e não sobre o
        // espaço disponível: quem centraliza o tabuleiro num espaço maior é o
        // `Center` abaixo. Somar aqui o deslocamento de centralização que o
        // `Center` já aplica empurrava as peças para fora da própria moldura em
        // qualquer tela mais larga que `kMaxBoardSide`.
        final side = BoardGeometry(availableWidth: constraints.maxWidth).side;
        final geometry = BoardGeometry(availableWidth: side);
        final tileSize = geometry.tileSize;
        final peak = _peakValue();

        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              // Moldura com leve degradê e sombra externa: separa o tabuleiro
              // do fundo em vez de deixá-lo flutuando num retângulo chapado.
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF23262B), Color(0xFF15171A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Fundo das células, para o tabuleiro não sumir enquanto uma
                // peça está em queda.
                for (int row = 0; row < Board.boardSize; row++)
                  for (int col = 0; col < Board.boardSize; col++)
                    Positioned(
                      left: geometry.left(col),
                      top: geometry.top(row),
                      width: tileSize,
                      height: tileSize,
                      // Célula vazia rebaixada: parece um encaixe onde a peça
                      // se apoia, e dá ao tabuleiro textura mesmo quando uma
                      // peça está no ar durante a queda.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),

                // As peças, endereçadas por identidade.
                //
                // Duas camadas de movimento, de propósito: o
                // [AnimatedPositioned] cuida da célula que a peça ocupa (a
                // queda, interpolada em kTileMoveDuration), e o
                // [Transform.translate] de dentro cuida do empurrão da troca
                // recusada. Se o empurrão entrasse no `left`, o
                // AnimatedPositioned ficaria perseguindo um alvo em movimento e
                // amortizaria o gesto até ele desaparecer.
                for (final tile in widget.board.getAllTiles())
                  AnimatedPositioned(
                    key: tileVisualKey(tile.id),
                    duration: kTileMoveDuration,
                    curve: Curves.easeOutCubic,
                    left: geometry.left(tile.position.col),
                    top: geometry.top(tile.position.row),
                    width: tileSize,
                    height: tileSize,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_nudge, _hintGlow]),
                      builder: (context, _) => Transform.translate(
                        offset: _rejectionOffset(tile.position, tileSize),
                        child: TileWidget(
                          tile: tile,
                          side: tileSize,
                          isSelected: widget.selectedTile?.id == tile.id,
                          hintGlow: _isHinted(tile.position)
                              ? _hintGlow.value
                              : 0,
                          fromBigMatch: widget.bigFusionTileIds.contains(
                            tile.id,
                          ),
                          isPeak: peak != null && tile.value == peak,
                        ),
                      ),
                    ),
                  ),

                // Peças saindo: encolhem e apagam no lugar onde estavam.
                for (final tile in _leaving)
                  Positioned(
                    key: tileExitKey(tile.id),
                    left: geometry.left(tile.position.col),
                    top: geometry.top(tile.position.row),
                    width: tileSize,
                    height: tileSize,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _exit,
                        builder: (context, child) {
                          final remaining = 1 - _exit.value;
                          return Opacity(
                            opacity: remaining.clamp(0, 1),
                            child: Transform.scale(
                              scale: 0.6 + 0.4 * remaining,
                              child: child,
                            ),
                          );
                        },
                        child: TileWidget(
                          tile: tile,
                          side: tileSize,
                          animateEntrance: false,
                        ),
                      ),
                    ),
                  ),

                // Áreas tocáveis por cima, endereçadas por posição.
                for (int row = 0; row < Board.boardSize; row++)
                  for (int col = 0; col < Board.boardSize; col++)
                    Positioned(
                      left: geometry.left(col),
                      top: geometry.top(row),
                      width: tileSize,
                      height: tileSize,
                      child: Builder(
                        builder: (context) {
                          final cell = Position(row: row, col: col);
                          return GestureDetector(
                            key: tileKey(cell),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onTileTap?.call(cell),
                            onPanStart: (_) {
                              _drag = Offset.zero;
                              _dragResolved = false;
                            },
                            onPanUpdate: (details) =>
                                _onDragUpdate(cell, details.delta, tileSize),
                            onPanEnd: (_) {
                              _drag = Offset.zero;
                              _dragResolved = false;
                            },
                          );
                        },
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
