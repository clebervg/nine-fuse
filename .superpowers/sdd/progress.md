# Fases infinitas procedurais — progresso

Plano: docs/superpowers/plans/2026-08-13-fases-infinitas-procedurais.md
Spec: docs/superpowers/specs/2026-08-13-fases-infinitas-procedurais-design.md
Branch: feat/fases-infinitas
Base: 9ef8b4f (plano de implementação)
Baseline: 662 testes passando, analyze limpo.

## Tarefas
- [x] 1 LevelGenerator — completa (commit 61f4d3a, revisão limpa, 669 testes)
- [x] 2 levelAt + capítulos infinitos — completa (commit 67695a5, revisão limpa)
- [x] 3 A campanha deixa de ter fim — completa (commits 0d33672..c886984, revisão limpa após 1 reparo)
- [x] 4 O mapa perde o "Em Breve" — completa (commit e600e8b, revisão aprovada, 1 achado Menor)
- [x] 5 Janela deslizante + denominador do capítulo — completa (commits bd23b0d..1d886ca, revisão limpa após 1 reparo). Árvore verde de novo: 680 testes.
- [x] 6 Poda dos registros de fase — completa (commits cb2bd9b..aae3fb2, revisão limpa após 2 reparos). 689 testes.
- [x] 7 Calibragem por simulação — completa (commits dc7332f..454d0ff, após 1 rejeição e 2 reparos)
- [x] 8 (extra, autorizada) Onda de choque credita objetivo de cobertura — commit 5c51cf1

## Achados menores (para a revisão final triar)
- Menor (rev. T7): `kDigitMovesPerPiece = 2.2` é quase inerte — com count 1-4 a base
  fica abaixo de `kMinMoveLimit`, então quem decide o limite das fases de dígito é o
  piso de 10, não o multiplicador. Documentado como tal, mas é sinal de que o eixo
  de calibragem disponível é estreito.
- **Dívida de fórmula (rev. T7, decisão do dono do produto: registrar, não corrigir):**
  `digit = position.isOdd ? spawnMax + 2 : spawnMax + 1` cria dois arquétipos com
  custo ~5x diferente. 3 em cada 10 fases são "+2"; as de contagem alta medem ~2%.
  Nenhum multiplicador linear em `count` separa os dois — exige mexer na fórmula do
  objetivo, o que esta branch tinha proibido.
- Menor (re-rev. T6): `reset()` ainda dispara `_persistArchivedStars()` e
  `_persistPrunedBelow()` como dois `unawaited` independentes, sem o encadeamento
  que `_pruned()` passou a ter. Hoje `reset()` não tem chamador em `lib/` — é só
  teste. Vale corrigir quando ganhar um caminho de UI.
- Menor (re-rev. T6): fase abaixo da marca d'água fica congelada em zero estrelas
  no mapa e não recupera `bestScore`. É o preço aceito da poda, documentado em
  comentário, mas é visível ao jogador.
- Menor (rev. T5): a "janela deslizante" **não desliza** — `_visibleCount` é
  `progress + kLookahead`, um prefixo que cresce sem teto: na fase 500 o `build`
  monta 508 pins. É o que o plano especificou (a aritmética de `_currentIndex`
  depende de a janela começar na fase 1), mas o doc-comment vende "não alocar mil
  fases para mostrar oito" enquanto o código faz isso a longo prazo. Precisa de
  recorte inferior ou de um TODO honesto.
- Menor (rev. T5): asserção `find.text('JOGAR').evaluate().isNotEmpty || ...` foge
  do sistema de matchers (mensagem de falha vira "Expected: true") e não é
  `descendant` do pin 11.
- Menor (rev. T5): `_currentIndex` tem `clamp` inalcançável nas duas pontas.
- Menor (re-rev. T5): `campaign_header.dart:150` ainda cita "CAMPANHA" como
  exemplo dentro de um comentário sobre `excludeSemantics`.
- Menor (rev. T4): o teste `'mostra pins além da última fase artesanal'` verifica
  `levelCardKey(11)` e `(18)`, mas a fixture passa 18 fases reais — os índices caem
  dentro da lista e renderizam como pin comum. O nome promete `_FuturePin`.
- Menor (rev. T1): `ice = (2 + block % 3).clamp(1, 4)` — o `clamp` é código morto,
  `2 + block%3` já vive em [2,4]. Os clamps de `glass`/`stone` são necessários.
- Menor (rev. T1): `generateLevel` recusa fase artesanal por `assert`, que some em
  release — lá rodaria com `block`/`position` negativos. É o padrão do resto do
  projeto (`Objective`, `GameLevel`), não regressão. A Task 2 decide se a guarda
  de entrada fica antes da chamada.
- Menor (rev. T1): o teste de recusa só cobre `n=10`; não cobre 0 nem negativo.

## Notas de execução
- Obrigações acumuladas para a Task 5: (a) `kCampaignStarTotal` em 5 arquivos;
  (b) `saga_map_test.dart:388-399` ainda afirma a existência do rótulo "Em Breve"
  já removido; (c) o teste `'mostra pins além da última fase artesanal'` em
  `saga_map_infinite_test.dart` promete mais do que verifica — hoje só confirma
  pins comuns. Conferir se passa a exercitar um `_FuturePin` de verdade.
- O plano errou uma conta: pedia `chapterOf(1000).number == 102`; o algoritmo do
  próprio plano dá 101 (990 fases além do artesanal, bloco 98, 2+98+1). Implementador
  e revisor conferiram a aritmética em separado; a asserção do teste foi corrigida
  para 101. O plano é que estava errado, não a implementação.
- Fallout de `kCampaignStarTotal` é maior do que o plano previa: além de
  `level_select_screen.dart`, quebram `test/features/game/presentation/saga_map_test.dart`
  (4 usos) e `test/l10n/english_screens_test.dart` (1 uso). **A Task 5 tem de cobrir
  os três arquivos**, senão a árvore segue vermelha.
- Tasks 2 e 5 deixam a árvore sem compilar entre si (remover `kCampaignStarTotal`
  quebra `level_select_screen.dart` até a Task 5). Previsto no plano.
- Subagentes: trabalhar em primeiro plano; não disparar comandos em segundo
  plano nem criar subtarefas (lição da branch anterior).

- A Task 3 deixou dois testes antigos de `game_notifier_test.dart` vermelhos (eles
  afirmavam "nextLevel repete a última fase") e o relatório do implementador afirmou
  que a árvore só estava vermelha pelo `kCampaignStarTotal` — não estava. Reparo em
  c886984: um teste removido por redundância real com `infinite_campaign_test.dart`
  (verificada por álgebra: `levelAt(10) == kCampaign.last`), o outro reescrito.
  Lição: pedir ao implementador a lista de arquivos de teste que **mencionam** o
  comportamento removido, não só os que ele tocou.

- **A poda quase virou farm de moedas.** `record()` calcula o ganho como
  `merged.stars - existing.stars`, e a torneira paga por esse retorno. Com o
  detalhe podado, `existing` é nulo: rejogar a fase pagava tudo de novo, e a
  repoda devolvia o estado ao anterior — ciclo infinito. Fechado por marca d'água
  (`prunedBelow`, a maior fase já podada; abaixo dela rende zero), mais a guarda
  de que a marca nunca regride na carga assíncrona. A revisão em opus achou;
  a auto-revisão do implementador não.

## Dívida registrada, fora desta branch
- **Baú de capítulo vira torneira infinita.** `Wallet.claimChapterChest` paga
  `kChapterChestReward` (200) por capítulo e guarda os reclamados num `Set`
  persistido. Com capítulos infinitos são 200 moedas a cada 10 fases, para
  sempre, e um `Set` que cresce sem teto — o mesmo problema que esta branch
  resolve para `levelRecords`. Hoje o método não está fiado a nenhuma UI (só
  testes o chamam), então não é bug agora. Precisa de teto ou de valor
  decrescente **antes** de a Fase B do baú ligá-lo à tela.
