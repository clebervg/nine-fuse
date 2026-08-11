import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/position.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';

/// Chave da camada que escurece a tela durante a mira do martelo.
const Key hammerScrimKey = Key('hammer_scrim');

/// Chave do desenho da mira: véu, recorte e destaque da célula sob o dedo.
const Key hammerAimKey = Key('hammer_aim');

/// Quanto tempo o véu leva para entrar.
///
/// Curto porque não é uma transição de tela: é a resposta ao toque no botão. Mais
/// que isso e o jogador já teria começado a mover o dedo antes de o jogo mostrar
/// que entrou em modo de mira.
const Duration kHammerScrimFade = Duration(milliseconds: 150);

/// Desfoque do fundo em mira, no auge da transição.
const double kHammerScrimBlur = 3;

/// Opacidade do véu preto em mira.
const double kHammerScrimOpacity = 0.6;

/// Quanto a célula sob o dedo cresce.
const double kHammerAimScale = 1.1;

/// Uma respiração da borda da célula mirada.
///
/// **Finita de propósito.** Uma animação em repetição faria `pumpAndSettle` nunca
/// terminar e derrubaria a suíte de widget inteira — a mesma armadilha que já
/// obrigou o contador de movimentos a pulsar uma vez por jogada em vez de virar
/// relógio. Aqui a borda dá duas batidas ao acender e descansa acesa.
const Duration kHammerAimPulse = Duration(milliseconds: 520);

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
///
/// **O golpe sai no levantar do dedo, não no encostar.** Enquanto o dedo está na
/// tela a célula sob ele fica em destaque, e arrastar move o destaque: é o que
/// dá ao jogador a chance de corrigir a mira antes de gastar o item. Cobrar no
/// `tapDown` transformaria todo escorregão em martelo perdido.
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

class _HammerTargetingLayerState extends State<HammerTargetingLayer>
    with TickerProviderStateMixin {
  /// Chave da própria camada: o véu é desenhado em coordenadas locais, e o
  /// retângulo do tabuleiro vem em globais.
  final GlobalKey _selfKey = GlobalKey();

  /// Retângulo do tabuleiro em coordenadas desta camada.
  ///
  /// Nulo no primeiro quadro, quando ainda não há layout de onde tirá-lo — daí
  /// o `setState` agendado: sem ele o véu ficaria sem recorte até o próximo
  /// rebuild, escondendo justamente o tabuleiro que o jogador está mirando.
  Rect? _boardLocal;

  /// Célula sob o dedo, enquanto ele está na tela.
  Position? _aim;

  /// Onde o dedo está, em coordenadas globais. Guardado porque `onPanEnd` não
  /// informa posição, e é dela que sai o golpe.
  Offset? _finger;

  late final AnimationController _entry = AnimationController(
    duration: kHammerScrimFade,
    vsync: this,
  );

  late final AnimationController _pulse = AnimationController(
    duration: kHammerAimPulse,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _entry.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final board = _boardRect();
    final self = _renderBoxOf(_selfKey);
    if (board == null || self == null) return;

    final local = board.shift(-self.localToGlobal(Offset.zero));
    if (local != _boardLocal) setState(() => _boardLocal = local);
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

  /// Que célula está sob [global], se alguma.
  Position? _cellAt(Offset global) {
    final rect = _boardRect();
    if (rect == null || !rect.contains(global)) return null;
    return BoardGeometry(
      availableWidth: rect.width,
    ).cellAt(global - rect.topLeft);
  }

  /// O dedo desceu ou se moveu: reposiciona o destaque.
  void _aimAt(Offset global) {
    _finger = global;
    final cell = _cellAt(global);
    if (cell == _aim) return;

    setState(() => _aim = cell);
    // A batida recomeça a cada célula nova: é o que faz o destaque parecer
    // acompanhar o dedo, em vez de escorregar de uma casa para a outra.
    if (cell != null) _pulse.forward(from: 0);
  }

  /// O dedo subiu: golpe na célula mirada, ou desistência se estava fora.
  void _release([Offset? global]) {
    final at = global ?? _finger;
    _finger = null;
    final cell = at == null ? null : _cellAt(at);

    if (cell != null) {
      widget.onCell(cell);
      return;
    }

    // Toque na moldura, entre a borda do tabuleiro e a primeira célula: não é
    // uma célula, mas também não é "fora" — cancelar ali puniria a mira torta.
    final rect = _boardRect();
    if (at != null && rect != null && rect.contains(at)) {
      setState(() => _aim = null);
      return;
    }

    widget.onCancel();
  }

  /// Recorte que o véu não cobre: a célula mirada, se há uma; o tabuleiro
  /// inteiro, enquanto não há.
  ///
  /// **O tabuleiro sai do véu antes de o dedo descer** porque é entre os dígitos
  /// dele que o jogador está escolhendo — desfocar a grade na hora de escolher
  /// esconderia justamente a informação que a decisão pede. Assim que o dedo
  /// encosta, o resto recua: aí já há uma escolha em curso, e o que importa é
  /// ver *qual* célula vai morrer.
  Rect? get _hole {
    final board = _boardLocal;
    if (board == null) return null;

    final cell = _aim;
    if (cell == null) return board;

    final geometry = BoardGeometry(availableWidth: board.width);
    final rect = Rect.fromLTWH(
      board.left + geometry.left(cell.col),
      board.top + geometry.top(cell.row),
      geometry.tileSize,
      geometry.tileSize,
    );
    // Cresce a partir do centro: o recorte tem de acompanhar o destaque, senão
    // a borda que cresce nasce por baixo do véu.
    return _scaled(rect, kHammerAimScale);
  }

  static Rect _scaled(Rect rect, double factor) => Rect.fromCenter(
    center: rect.center,
    width: rect.width * factor,
    height: rect.height * factor,
  );

  @override
  Widget build(BuildContext context) {
    // O recorte é remedido a cada quadro de layout: a faixa do botão troca de
    // altura ao entrar em mira (a dica escrita aparece), e isso move o tabuleiro.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    return Positioned.fill(
      child: GestureDetector(
        key: hammerScrimKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _aimAt(d.globalPosition),
        onTapUp: (d) => _release(d.globalPosition),
        // Arrastar corrige a mira, e é o mesmo gesto de trocar peças: quem já
        // joga arrastando não precisa aprender outro para o martelo.
        onPanStart: (d) => _aimAt(d.globalPosition),
        onPanUpdate: (d) => _aimAt(d.globalPosition),
        onPanEnd: (_) => _release(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_entry, _pulse]),
          builder: (context, _) {
            final hole = _hole;
            final t = _entry.value;

            return Stack(
              key: _selfKey,
              fit: StackFit.expand,
              children: [
                ClipRect(
                  // O `ClipRect` externo limita o `BackdropFilter` ao que está
                  // na tela. Sem ele o filtro tenta ler o fundo da árvore
                  // inteira, e num grid 8x8 animado isso aparece como engasgo.
                  child: _ScrimClip(
                    hole: hole,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: kHammerScrimBlur * t,
                        sigmaY: kHammerScrimBlur * t,
                      ),
                      // Cor com alfa animado no lugar de `Opacity` ou
                      // `FadeTransition`: a suíte usa esses dois tipos como
                      // marcadores de outros efeitos, e um a mais os quebraria
                      // em silêncio.
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: kHammerScrimOpacity * t,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                // O destaque é irmão do véu, e não filho: dentro do recorte a
                // prévia vermelha seria cortada junto com o buraco — ela é
                // desenhada justamente sobre a célula que o véu não cobre.
                CustomPaint(
                  key: hammerAimKey,
                  painter: _AimPainter(
                    hole: _aim == null ? null : hole,
                    pulse: _pulse.value,
                    entry: t,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Recorta o véu para tudo **menos** [hole].
///
/// `ClipPath` com a diferença entre a tela e o recorte: é o que deixa o
/// `BackdropFilter` desfocar o fundo sem tocar no que está dentro do buraco. Um
/// véu desenhado por cima escureceria, mas o desfoque continuaria valendo para a
/// célula mirada — e uma célula desfocada é o oposto do que a mira quer dizer.
class _ScrimClip extends StatelessWidget {
  const _ScrimClip({required this.hole, required this.child});

  final Rect? hole;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (hole == null) return child;
    return ClipPath(clipper: _HoleClipper(hole!), child: child);
  }
}

class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper(this.hole);

  final Rect hole;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14))),
  );

  @override
  bool shouldReclip(_HoleClipper oldClipper) => oldClipper.hole != hole;
}

/// Desenha o destaque da célula mirada: aro neon pulsante e prévia vermelha.
///
/// O aro é desenhado **por fora** do recorte, encostado nele: por dentro cobriria
/// o dígito, que é o que o jogador está conferindo antes de soltar o dedo.
class _AimPainter extends CustomPainter {
  const _AimPainter({
    required this.hole,
    required this.pulse,
    required this.entry,
  });

  /// Célula mirada, já em coordenadas locais e escalada. Nulo antes do toque.
  final Rect? hole;

  /// Fase da respiração da borda, de 0 a 1.
  final double pulse;

  /// Fase da entrada do véu, de 0 a 1.
  final double entry;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = hole;
    if (rect == null) return;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    // Duas batidas e descanso aceso: `sin` de duas voltas somado a um piso, para
    // a borda nunca apagar de todo no meio do gesto.
    final beat = 0.65 + 0.35 * math.sin(pulse * 4 * math.pi).abs();
    final neon = AppColors.lighten(AppColors.digit0, 0.25);

    // A prévia vermelha vive na borda de dentro, um fio só: preenchida ela
    // esconderia o dígito, e o jogador perderia de vista o que está prestes a
    // perder.
    canvas.drawRRect(
      rrect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.digit0.withValues(alpha: 0.9 * entry),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = neon.withValues(alpha: beat * entry)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 6 * beat),
    );
  }

  @override
  bool shouldRepaint(_AimPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.pulse != pulse ||
      oldDelegate.entry != entry;
}
