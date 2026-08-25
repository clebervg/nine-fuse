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
- [x] 6 Providers e UI — recompilar contra o novo contrato — completa (commit 964c52a..599fa11, revisão aprovada após 1 rodada de fix, 739/739 testes). Fix: ativação do Super 9 não atualizava objectiveProgress (contagem por diff de tabuleiro antes/depois) nem consecutiveLosses/endlessOfferShown. Endless confirmado sem sistema de objetivo/loss-streak — nada a corrigir lá.
- [x] 7 JuicePriority e JuiceDirector — completa (commit 5107c79..d20c2a8, revisão aprovada, 745/745 testes).
- [x] 8 Apresentação do evento Supernova — completa (commit d7e0d7e..7677599, revisão aprovada após 1 rodada de fix, 748/748 testes). Fix: janela de corrida de 250ms sem `isResolving` travando `swapTiles` durante o hitstop (gap herdado do próprio brief). Endless mode NÃO ganhou o evento Supernova nesta task — decisão de escopo do brief, registrada.
- [x] 9 Recalibrar economia e registrar achado — completa (commit f535e55..f0a3f08, revisão aprovada, docs-only). Fase 1000 "limpe todo stone" caiu de 63%→35% e fase 108 "quebre 3 stone" de 51%→40% (janela de spawn alta, medição isolada contra 745bf39 para não confundir com outro commit não relacionado já mergeado). Registrado em CLAUDE.md; recalibragem explicitamente fora do escopo desta task.

## Achados menores (para a revisão final triar)
- T3: comentários obsoletos mencionando "explosão" removida (match_engine.dart, hoje
  ~linhas 101 e 560 — números vão mudar com tasks seguintes).
- T3: `_clearBlockersAround` varre a célula central (onde o 9 nasceu) no raio 3x3;
  inofensivo (célula central nunca carrega obstáculo, pela invariante de que peça
  coberta não entra em combinação), mas sem comentário explicando isso.
- T5: sem teste explícito de Super 9 num canto/borda do tabuleiro interagindo com
  gravidade/refill, nem de trocar o Super 9 com um vizinho de valor 9 (só coberto
  por leitura de código, `match_engine.dart` linhas ~498-500).
- T6: `apexCelebrated` ficou um sinal morto (nenhum caminho de código o liga mais) —
  esperado ficar vivo de novo na Task 8 (evento Supernova).
- T6: `convertedFrom` chega a `_applySuperNineActivation` e agora é usado para o
  cálculo de objectiveProgress — não é mais parâmetro morto.
- T6: sem teste explícito de contagem de peças pré-existentes no valor-alvo antes da
  troca do Super 9 (a fórmula por diff é correta por construção, mas o caso não tem
  teste dedicado provando isso).
- T8: Endless não tem o evento Supernova (banner/hitstop/focus-fade) — só campanha.
  Ativação do Super 9 no Endless continua funcionando (converte, some, etc.), só sem
  a apresentação nova. Fica para uma task futura se o dono do produto quiser paridade.
- T8: `pendingSupernova` não é limpo no ramo `MoveRejected` de `swapTiles` — inofensivo
  hoje (o widget não re-anima, já ficou completo), mas é inconsistência latente se
  ganhar um segundo consumidor.

## Revisão final da branch (745bf39..06c1eba)

Achados Critical/Important a corrigir antes do merge:
1. CRITICAL: `decaySpecials` só é chamado dentro de `_applySuperNineActivation` (na
   própria jogada que consome o Super 9) — nunca em `_finishMove`. O decaimento de
   3 turnos nunca roda de verdade, e o limite de 1 Super 9 ativo trava para sempre
   se o jogador nunca usar o que já nasceu.
2. IMPORTANT: `_clearBlockersAround` (Bloco 9) soma hits com `_damageObstacles` sem
   deduplicar posições — cobertura na vizinhança de ambos os raios (comum) leva 2
   impactos no mesmo passo, quebrando a invariante "um impacto por passo".
3. IMPORTANT: `objectiveProgress` da ativação do Super 9 mede diferença de contagem
   no tabuleiro **depois** de `applyGravity`+`refill` — peças sorteadas pelo refill
   no valor-alvo inflam o ganho. Devia contar só `_countValue(state.board,
   convertedFrom)` (peças que existiam antes, por construção).
4. IMPORTANT: `apexCelebrated` ficou morto (nenhum código liga mais) — a celebração
   do dígito máximo sumiu de campanha e Endless sem decisão registrada.
5. IMPORTANT: textos de UI/loja ainda descrevem a explosão antiga (`LevelTip.
   apexExplodes`, ARBs de loja mencionando movimentos bônus).
6. IMPORTANT: CLAUDE.md (topo do arquivo, "Core Gameplay") ainda descreve a
   explosão antiga como mecânica atual; não há seção nova para Bloco 9/Super 9/
   CascadeBudget.
7. IMPORTANT: `JuiceDirector`/`JuicePriority` não são usados em produção — a
   criação do Super 9 (5+ peças) não dispara o evento Supernova, só a ativação.

Achados Minor (registrar, não bloqueiam): assimetria Endless sem apresentação
Supernova (e sem guard/hitstop — risco futuro se alguém adicionar delay lá sem
replicar o fix da corrida); comentários obsoletos remanescentes em match_engine.dart
(linhas ~102, ~150, ~626); `_clearBlockersAround` sem comentário sobre célula
central; `var stepScore` que nunca reatribui (podia ser `final`); sem teste
end-to-end nascimento→ativação do Super 9 pelo notifier.

## Notas de execução
- Ledger anterior deste arquivo (Dynamic Extra Moves, e depois Splash Screen) foi
  commitado sem querer na main de branches antigas; sobrescrito para começar este
  trabalho do zero.
- Trabalhando em worktree isolado — não mergear/dar push sem autorização explícita.
