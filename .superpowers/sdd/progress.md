# Fases infinitas procedurais — progresso

Plano: docs/superpowers/plans/2026-08-13-fases-infinitas-procedurais.md
Spec: docs/superpowers/specs/2026-08-13-fases-infinitas-procedurais-design.md
Branch: feat/fases-infinitas
Base: 9ef8b4f (plano de implementação)
Baseline: 662 testes passando, analyze limpo.

## Tarefas
- [x] 1 LevelGenerator — completa (commit 61f4d3a, revisão limpa, 669 testes)
- [ ] 2 levelAt + capítulos infinitos
- [ ] 3 A campanha deixa de ter fim
- [ ] 4 O mapa perde o "Em Breve"
- [ ] 5 Janela deslizante + denominador do capítulo
- [ ] 6 Poda dos registros de fase
- [ ] 7 Calibragem por simulação

## Achados menores (para a revisão final triar)
- Menor (rev. T1): `ice = (2 + block % 3).clamp(1, 4)` — o `clamp` é código morto,
  `2 + block%3` já vive em [2,4]. Os clamps de `glass`/`stone` são necessários.
- Menor (rev. T1): `generateLevel` recusa fase artesanal por `assert`, que some em
  release — lá rodaria com `block`/`position` negativos. É o padrão do resto do
  projeto (`Objective`, `GameLevel`), não regressão. A Task 2 decide se a guarda
  de entrada fica antes da chamada.
- Menor (rev. T1): o teste de recusa só cobre `n=10`; não cobre 0 nem negativo.

## Notas de execução
- Tasks 2 e 5 deixam a árvore sem compilar entre si (remover `kCampaignStarTotal`
  quebra `level_select_screen.dart` até a Task 5). Previsto no plano.
- Subagentes: trabalhar em primeiro plano; não disparar comandos em segundo
  plano nem criar subtarefas (lição da branch anterior).

## Dívida registrada, fora desta branch
- **Baú de capítulo vira torneira infinita.** `Wallet.claimChapterChest` paga
  `kChapterChestReward` (200) por capítulo e guarda os reclamados num `Set`
  persistido. Com capítulos infinitos são 200 moedas a cada 10 fases, para
  sempre, e um `Set` que cresce sem teto — o mesmo problema que esta branch
  resolve para `levelRecords`. Hoje o método não está fiado a nenhuma UI (só
  testes o chamam), então não é bug agora. Precisa de teto ou de valor
  decrescente **antes** de a Fase B do baú ligá-lo à tela.
