import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/position.dart';

/// Largura máxima do tabuleiro. Em tablet, crescer sem limite só afastaria as
/// peças umas das outras.
const double kMaxBoardSide = 520;

/// Alvo mínimo de toque recomendado pelas diretrizes de iOS e Android.
/// Serve de referência para o teste de tamanho da célula.
const double kMinTouchTarget = 44;

/// Onde cada célula do tabuleiro é desenhada.
///
/// Existe porque **duas** camadas precisam da mesma conta: o tabuleiro, que
/// posiciona as peças, e a camada de efeitos, que faz a pontuação flutuante
/// nascer exatamente na célula da fusão. Duplicar a fórmula significaria que
/// mexer no espaçamento de uma delas desalinharia a outra em silêncio.
class BoardGeometry {
  BoardGeometry({required double availableWidth})
    : side = min(availableWidth, kMaxBoardSide),
      _originX = (availableWidth - min(availableWidth, kMaxBoardSide)) / 2;

  /// Padding e espaçamento apertados de propósito. Num 8x8 cada ponto gasto na
  /// moldura sai do dedo: com padding 6 e gap 4 a célula ficava em ~41pt num
  /// celular comum, abaixo dos 44pt de alvo mínimo de toque.
  static const double padding = 4;
  static const double gap = 3;

  /// Lado do tabuleiro, já limitado por [kMaxBoardSide].
  final double side;

  /// Deslocamento horizontal quando o tabuleiro é menor que o espaço dado.
  final double _originX;

  late final double tileSize =
      (side - padding * 2 - gap * (Board.boardSize - 1)) / Board.boardSize;

  /// Canto esquerdo da coluna.
  double left(int col) => _originX + padding + col * (tileSize + gap);

  /// Topo da linha.
  double top(int row) => padding + row * (tileSize + gap);

  /// Centro da célula, que é onde os efeitos nascem.
  Offset centerOf(Position position) => Offset(
    left(position.col) + tileSize / 2,
    top(position.row) + tileSize / 2,
  );

  /// Que célula está sob [local], em coordenadas do tabuleiro. Nulo fora dele.
  ///
  /// É o caminho inverso de [centerOf], e existe para a camada de mira do
  /// martelo: durante a mira quem recebe o toque é a camada, e não a peça, para
  /// que um toque **fora** do tabuleiro possa cancelar. Sem esta conta a camada
  /// teria a sua própria, e um dia elas discordariam — o jogador bateria numa
  /// célula e veria a vizinha explodir.
  ///
  /// O vão entre as células pertence à peça anterior: recusar o toque ali faria
  /// o dedo escorregar entre as peças.
  Position? cellAt(Offset local) {
    final stride = tileSize + gap;
    final col = ((local.dx - _originX - padding) / stride).floor();
    final row = ((local.dy - padding) / stride).floor();

    final cell = Position(row: row, col: col);
    return Board.contains(cell) ? cell : null;
  }
}
