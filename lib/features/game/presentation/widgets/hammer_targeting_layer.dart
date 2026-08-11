import 'package:flutter/material.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';

/// Chave da camada que escurece a tela durante a mira do martelo.
const Key hammerScrimKey = Key('hammer_scrim');

/// Camada que assume o toque enquanto o jogador mira o martelo.
///
/// Cobre a tela inteira e decide o destino de cada toque: dentro do tabuleiro,
/// vira o golpe na célula tocada; fora dele, cancela a mira.
///
/// **Por que a camada, e não a peça.** Deixar o tabuleiro tratar o golpe (como
/// ele trata a seleção de troca) resolveria metade do problema: o toque *fora*
/// do tabuleiro nunca chegaria a ninguém, porque a área vazia da tela pertence à
/// rolagem, que consome o gesto sem repassá-lo. E cancelar tocando fora é
/// justamente a saída que a mira precisa ter — quem entrou por engano no modo de
/// mira não deve ter de acertar um botão para sair dele.
///
/// A conta que converte toque em célula é a do [BoardGeometry], a mesma que
/// posiciona as peças: duas fórmulas para o mesmo alinhamento divergiriam um
/// dia, e o jogador bateria numa célula vendo a vizinha explodir.
class HammerTargetingLayer extends StatefulWidget {
  const HammerTargetingLayer({
    super.key,
    required this.boardKey,
    required this.onCell,
    required this.onCancel,
  });

  /// Chave do widget do tabuleiro, para descobrir onde ele está na tela.
  final GlobalKey boardKey;

  /// O jogador escolheu uma célula.
  final ValueChanged<Position> onCell;

  /// O jogador tocou fora do tabuleiro.
  final VoidCallback onCancel;

  @override
  State<HammerTargetingLayer> createState() => _HammerTargetingLayerState();
}

class _HammerTargetingLayerState extends State<HammerTargetingLayer> {
  /// Chave da própria camada: o recorte do véu é desenhado em coordenadas
  /// locais, e o retângulo do tabuleiro vem em globais.
  final GlobalKey _selfKey = GlobalKey();

  /// Recorte do tabuleiro, já em coordenadas desta camada.
  ///
  /// Nulo no primeiro quadro, quando ainda não há layout de onde tirá-lo — daí
  /// o `setState` agendado: sem ele o véu ficaria sem recorte até o próximo
  /// rebuild, escondendo justamente o tabuleiro que o jogador está mirando.
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final hole = _boardRect();
    final self = _renderBoxOf(_selfKey);
    if (hole == null || self == null) return;

    final local = hole.shift(-self.localToGlobal(Offset.zero));
    if (local != _hole) setState(() => _hole = local);
  }

  static RenderBox? _renderBoxOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  /// Retângulo do tabuleiro em coordenadas globais.
  Rect? _boardRect() {
    final box = _renderBoxOf(widget.boardKey);
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _handleTap(Offset global) {
    final rect = _boardRect();
    if (rect == null || !rect.contains(global)) {
      widget.onCancel();
      return;
    }

    final cell = BoardGeometry(
      availableWidth: rect.width,
    ).cellAt(global - rect.topLeft);

    // Toque na moldura, entre a borda do tabuleiro e a primeira célula: não é
    // uma célula, mas também não é "fora" — cancelar ali puniria a mira torta.
    if (cell != null) widget.onCell(cell);
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: GestureDetector(
      key: hammerScrimKey,
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.globalPosition),
      child: CustomPaint(
        key: _selfKey,
        painter: _ScrimPainter(hole: _hole),
      ),
    ),
  );
}

/// Escurece tudo **menos** o tabuleiro.
///
/// O recorte não é enfeite: um véu uniforme apagaria justamente os dígitos entre
/// os quais o jogador está escolhendo. O que a mira precisa dizer é "o resto da
/// tela está fora agora", e é o contraste que diz isso.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole});

  /// Recorte em coordenadas locais. Nulo no primeiro quadro.
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final veil = Paint()..color = const Color(0x8C000000);

    final cut = hole;
    if (cut == null) {
      canvas.drawRect(full, veil);
      return;
    }

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()
          ..addRRect(RRect.fromRectAndRadius(cut, const Radius.circular(16))),
      ),
      veil,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.hole != hole;
}
