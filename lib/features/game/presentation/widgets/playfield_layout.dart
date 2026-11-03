import 'package:flutter/material.dart';
import 'package:nine_fuse/core/widgets/coins_header_badge.dart';
import 'package:nine_fuse/core/widgets/nf_back_button.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_frame.dart';
import 'package:nine_fuse/features/game/presentation/widgets/board_geometry.dart';
import 'package:nine_fuse/features/game/presentation/widgets/hammer_button.dart';

/// Margem lateral do tabuleiro **fora** do aro de ouro.
///
/// Somada ao aro ([kBoardRimWidth]) dá os 8pt de cada lado que o cálculo de
/// tamanho de célula assume (largura da tela - 16pt). Mexer num dos dois sem o
/// outro encolhe a célula abaixo do que `board_grid_widget_test` mede.
const double kBoardSideMargin = 8 - kBoardRimWidth;

/// Largura máxima do HUD e do dock. Em tablet, esticá-los até a borda
/// afastaria demais os números do tabuleiro que eles descrevem.
const double kPlayfieldMaxWidth = 560;

/// Ocupa a largura toda até [maxWidth], e centraliza dali em diante.
Widget _capped(Widget child, double maxWidth) => Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: SizedBox(width: double.infinity, child: child),
  ),
);

/// Topo das telas de partida: voltar, título e a pílula de moedas.
///
/// Compartilhado por campanha e Modo Recorde: são a mesma tela de jogo com
/// cabeçalhos diferentes, e dois topos montados à mão divergiriam no primeiro
/// ajuste de margem.
///
/// Só as moedas na pílula: o estoque de boosters já tem número próprio no dock,
/// e o espelho da carteira pode estar velho no meio de uma partida — dois
/// números do mesmo item na mesma tela.
PreferredSizeWidget playfieldAppBar({required String title}) => AppBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  // Sem tinta ao rolar: o corpo rola por baixo em tela curta, e a barra
  // ganharia uma faixa de cor por cima do céu.
  scrolledUnderElevation: 0,
  centerTitle: true,
  automaticallyImplyLeading: false,
  leadingWidth: kNfBackButtonLeadingWidth,
  leading: const NfBackButton(),
  // Encolhe em vez de cortar: "MODO RE…" não diz em que modo o jogador está.
  title: FittedBox(fit: BoxFit.scaleDown, child: NfText.title(title, size: 26)),
  actions: const [CoinsHeaderBadge(), SizedBox(width: 14)],
);

/// O corpo das telas de partida: HUD no topo, tabuleiro no meio e o dock de
/// boosters embaixo, no alcance do polegar.
///
/// **O tabuleiro fica centralizado no espaço que sobra entre HUD e dock**
/// (`spaceBetween` sobre uma coluna com altura mínima de tela), e o dock
/// assenta a [kBoosterDockBottomGap] da área segura. Em tela curta demais a
/// coluna simplesmente passa da altura e rola — nada é espremido.
///
/// Com a fase encerrada o dock sai ([dock] nulo), mas o espaço dele fica: o
/// tabuleiro não pode saltar por baixo do cartão de desfecho.
class PlayfieldLayout extends StatelessWidget {
  const PlayfieldLayout({
    super.key,
    required this.hud,
    required this.board,
    this.dock,
  });

  final Widget hud;
  final Widget board;
  final Widget? dock;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: kBoosterDockBottomGap),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _capped(hud, kPlayfieldMaxWidth),
              ),
              // A folga vertical é a da base 3D da moldura (10pt) mais a dos
              // rebites: sem ela, em tela justa, a moldura encostaria no HUD
              // e no dock.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kBoardSideMargin,
                  14,
                  kBoardSideMargin,
                  22,
                ),
                // O teto vale para a moldura **com** o aro: sem ele, em tela
                // larga o `BoardGridWidget` centraliza o tabuleiro de 520pt
                // dentro de um espaço maior e o aro de ouro sobra em volta
                // de um vão vazio.
                child: _capped(board, kMaxBoardSide + 2 * kBoardRimWidth),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _capped(
                  dock ?? const SizedBox(height: kBoosterDockHeight),
                  kPlayfieldMaxWidth,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
