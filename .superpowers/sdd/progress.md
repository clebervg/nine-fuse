# Bloco 9, Super 9 e Cascade Budget — progresso

Plano: docs/superpowers/plans/2026-08-25-bloco-9-super-9.md
Spec: docs/superpowers/specs/2026-08-25-bloco-9-super-9-design.md
Worktree: /Users/cleber/projects/nine_fuse/.claude/worktrees/bloco9-super9
Branch: worktree-bloco9-super9
Base: 745bf39

Baseline: `flutter test` completo — 740 testes passando.

## Tarefas
- [x] 1 SpecialTileType + Tile.withSpecial — completa (commit b4b0360..7976e23, revisão aprovada, 743 testes)
- [x] 2 CascadeBudget — completa (commit 07db656..8ef97c5, revisão aprovada, 744 testes). Ajuste fora do brief, verificado pelo revisor: teste pré-existente "o ciclo fecha" precisou aceitar match pendente quando steps.length == kCascadeBudgetPerTurn (consequência esperada da mudança de semântica).
- [x] 3 Bloco 9 — completa (commit fd6e471..099a6e2, revisão aprovada, 86/86 testes do domínio). Duas correções de cenário de teste do brief (posições de gelo em cima do próprio trio; grade que não produzia o 9 em cascata) — verificadas pelo revisor como bugs genuínos do brief, não do motor.
- [x] 4 Super 9 — criação e limite de 1 ativo — completa (commit 324508b..3d7899e, revisão aprovada após 1 rodada de fix, 90/90 testes). Fix: faltava teste do caso de duas fusões de 5+ na mesma jogada (cobertura do ramo `updates` de `_hasActiveSuperNine`).
- [x] 5 Super 9 — ativação por troca, conversão board-wide, decaimento — completa (commit e6d3481..4254a6a, revisão aprovada, 96/96 testes).
- [ ] 6 Providers e UI — recompilar contra o novo contrato
- [ ] 7 JuicePriority e JuiceDirector
- [ ] 8 Apresentação do evento Supernova
- [ ] 9 Recalibrar economia e registrar achado

## Achados menores (para a revisão final triar)
- T3: comentários obsoletos mencionando "explosão" removida (match_engine.dart, hoje
  ~linhas 101 e 560 — números vão mudar com tasks seguintes).
- T3: `_clearBlockersAround` varre a célula central (onde o 9 nasceu) no raio 3x3;
  inofensivo (célula central nunca carrega obstáculo, pela invariante de que peça
  coberta não entra em combinação), mas sem comentário explicando isso.
- T5: sem teste explícito de Super 9 num canto/borda do tabuleiro interagindo com
  gravidade/refill, nem de trocar o Super 9 com um vizinho de valor 9 (só coberto
  por leitura de código, `match_engine.dart` linhas ~498-500).

## Notas de execução
- Ledger anterior deste arquivo (Dynamic Extra Moves, e depois Splash Screen) foi
  commitado sem querer na main de branches antigas; sobrescrito para começar este
  trabalho do zero.
- Trabalhando em worktree isolado — não mergear/dar push sem autorização explícita.
