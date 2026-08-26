# Evento Nova — progresso

Plano: docs/superpowers/plans/2026-08-26-evento-nova.md
Spec: docs/superpowers/specs/2026-08-25-evento-nova-design.md
Worktree: /Users/cleber/projects/nine_fuse/.claude/worktrees/evento-nova
Branch: worktree-evento-nova
Base: 7a2425b

Baseline: `flutter test` completo — 760 testes passando.

## Tarefas
- [x] 1 NovaEvent — tipo de dado e constantes de placar — completa (commit 7a2425b..4f324eb, revisão aprovada, sem achados críticos/importantes)
- [x] 2 Plumbing — novaEvents em FusionOutcome/ResolutionStep/Resolution — completa (commit 4f324eb..f50267b, revisão aprovada, sem achados críticos/importantes)
- [x] 3 Geometria e gatilho — Nova tier 1 (3 peças, 3x3/5x5) — completa (commit f50267b..e255b7c, revisão aprovada, sem achados críticos/importantes). Implementador corrigiu 2 testes do brief que checavam `resolution.board` (pós-gravidade) em vez de `boardAfterFusion` (pré-gravidade) — desvio verificado e legítimo, revisor confirmou que só o alvo do assert mudou, não os valores esperados.
- [x] 4 Tiers 2 e 3 — 4 peças (7x7) e 5+ (tabuleiro inteiro) — completa (commit e255b7c..e0d7ce9, revisão aprovada, sem achados críticos/importantes, test-only conforme esperado)
- [x] 5 Imunidade de peças especiais — completa (commit e0d7ce9..c196dc3, revisão aprovada, sem achados críticos/importantes, test-only conforme esperado)
- [x] 6 Gatilho por cascata, independência do Super 9, match pendente por budget — completa (commit c196dc3..21ede30, revisão aprovada). Achado Important *plan-mandated*: o teste de esgotamento do CascadeBudget não reproduziu o cenário exato (match pendente formado pela Nova) e degradou para "documenta intenção, sem asserção real" — comportamento explicitamente previsto e justificado no plano (a garantia real já é coberta pelos testes pré-existentes de CascadeBudget/Super 9). Levar para a revisão final da branch: decidir se vale tentar outro seed/grade ou aceitar como está.
- [x] 7 Registro no CLAUDE.md — completa (commit 21ede30..2cfc62d, revisão aprovada, sem achados)

Todas as 7 tasks do plano completas.

## Revisão final da branch (7a2425b..a14ce20..71a42d5)

Revisão final (Opus) encontrou 1 achado Crítico e 3 Importantes:
- Crítico: `NovaEvent.obstacleHits` nunca era mesclado em `ResolutionStep.obstacleHits`,
  então a Nova destruía obstáculos sem creditar objetivos de fase (repetição do
  bug já documentado 2x no CLAUDE.md para a explosão antiga e o martelo).
- Importante: imunidade de peças especiais lia o tabuleiro pré-fusão em vez do
  mapa `updates` — um Super 9 nascido na mesma passada podia ser destruído.
- Importante (mesma causa): "last write wins" no tier 3 era sistemático, não
  raro.
- Importante — decisão do usuário: placar da Nova estava substituindo
  (não somando) o placar antigo, contra o texto do spec. Usuário escolheu
  somar; corrigido.

Corrigido em commit a14ce20 (781→783 testes). Re-revisão (Opus) confirmou as
4 correções e apontou 3 itens de polimento: comentário de `novaScoreForTier`
contradizendo o código, falta de asserção exata do placar aditivo, nome de
teste enganoso após reescrita da Task 6. Fechado em commit 71a42d5
(116/116 em match_engine_test.dart, 783/783 na suíte completa,
`dart format` limpo nos 3 arquivos tocados).

**Ready to merge: Yes.**

Próximo passo: `superpowers:finishing-a-development-branch`.

## Notas de execução (continuação)
- O subagente da correção de polimento retomou sozinho após uma notificação
  incompleta ("waiting for background test run") e terminou o trabalho
  (commit 71a42d5) enquanto o controlador verificava o mesmo estado em
  paralelo — sem conflito, ambos convergiram no mesmo resultado.

## Notas de execução
- Ledger anterior deste arquivo (brand-refresh, já mergeado) sobrescrito para
  começar este trabalho do zero — histórico completo preservado em `git log`.
- Trabalhando em worktree isolado (.claude/worktrees/evento-nova) — não
  mergear/dar push sem autorização explícita.
