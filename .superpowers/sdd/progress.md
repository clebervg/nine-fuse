# Dynamic Extra Moves (DEM) — progresso

Plano: docs/superpowers/plans/2026-08-15-dynamic-extra-moves.md
Spec: docs/superpowers/specs/2026-08-15-dynamic-extra-moves-design.md
Worktree: /Users/cleber/projects/nine_fuse-dem
Branch: feat/dynamic-extra-moves
Base: b802770
Baseline: 704 testes passando, analyze limpo.

## Tarefas
- [x] 1 GameBalanceEngine + constantes — completa (commit 606f388, revisão limpa, 709 testes)
- [x] 2 GameState.rewardedMoves — completa (commit 0279f31, revisão aprovada, 2 achados Menores, 712 testes)
- [x] 3 grantBonusMoves dinâmico — completa (commit 47dbd5b, revisão aprovada). Árvore VERMELHA de propósito: moves_offer_test.dart quebra até a Task 4.
- [x] 4 Convite anuncia o prêmio; kPreChurnReward removido — completa (commit 8b5f416, revisão aprovada, 2 achados Menores). Árvore verde: 713 testes.
- [x] 5 Registro no CLAUDE.md — completa (commit f0a5a34)

## Achados menores (para a revisão final triar)

## Notas de execução
- main está com a working tree suja de OUTRA sessão (ícones, l10n, widgets, CLAUDE.md).
  Daí o worktree isolado. NÃO mergear nem dar push sem autorização explícita do dono.
- Subagentes: proibido mergear, dar push, ou tocar em qualquer coisa fora do worktree.
- Menor (rev. T2): os 3 testes de `rewardedMoves` só exercitam `reachDigit`. O ramo
  de `objectiveTarget` para `clearAllObstacles` foi conferido à mão pelo revisor (a
  subtração colapsa em "unidades restantes no tabuleiro" nos três tipos), mas não
  está travado por teste.
- Menor (rev. T2): `rewardedMoves` não guarda contra fase já ganha — com
  `objectiveMet`, a conta dá 0 ou negativo e a fórmula devolve o piso (4). Inofensivo
  porque quem decide *quando* oferecer é `shouldOfferMoves`. **A revisão das Tasks 3 e
  4 tem de confirmar que nenhum consumidor lê o getter sem esse gate.**
- **Erro do plano (T3), corrigido pelo implementador e confirmado pelo revisor:** o
  teste do plano com `objective: 2` era impossível de passar. `_boardWithTrio(5)` +
  `_playTrio` funde três 5 num 6, que é o próprio dígito-alvo — cada jogada já avança
  `objectiveProgress` em 1. Com objetivo 2, o restante pós-jogada é 1 e o prêmio é 4,
  nunca 6. Virou `objective: 3` (restante 2 → 6). O plano estava errado, não o código.
- Menor (rev. T3): redundância inofensiva entre `'dois alvos restantes pagam seis'`
  (T2, sem jogar) e o teste novo da T3 (após `_playTrio`) — mesma combinação por
  caminhos diferentes. Serve de checagem cruzada.
- Achado herdado da T2 FECHADO: o único chamador de produção de `grantBonusMoves`
  (`game_screen.dart:351`) já é protegido por `_movesOfferOpen && !state.isOver`, e
  `_movesOfferOpen` só liga via `shouldOfferMoves`, que exige objetivo em aberto.
  Dupla proteção com a guarda interna de `status != playing`.
- Menor (rev. T4): `movesAdProvider` em `moves_offer_dialog.dart` levou reformatação
  cosmética do `dart format` (arrow quebrada em duas linhas), sem relação com o escopo.
  Ruído de diff, não bug.
- Menor (rev. T4): o "Expected" do Step 2 do plano não bateu com a falha real — o
  plano especulava a mensagem, e a asserção acabou apertada com `descendant`. Ambos
  provam o mesmo RED. Lição: não escrever mensagem de falha especulada no plano.
- Nota (rev. T4): a contagem de 713 (e não os ~715 que o plano estimava) NÃO é
  enfraquecimento — nenhum teste foi removido; a estimativa do plano é que estava alta.
