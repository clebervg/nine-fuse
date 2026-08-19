# Gatilho de Migração para o Modo Recorde (Endless)

**Data:** 2026-08-19
**Status:** Aprovado, aguardando plano de implementação

## Contexto

Uma análise de retenção/monetização propôs várias iniciativas (liberação do
Endless, gatilho de migração por falhas repetidas, ranking semanal, passe de
temporada). Desta análise, apenas o **gatilho de migração para o Modo Recorde**
foi priorizado para virar spec agora; as demais ficam registradas como
próximas fases (ver "Fora de escopo").

Investigação do código atual (2026-08-19) mostrou que:

- O Endless já é liberado na fase 5 (`kEndlessUnlockLevel`,
  `lib/features/game/providers/endless_notifier.dart:338`), consumido em
  `level_select_screen.dart:212-213`. Isso já é mais cedo do que a análise
  original sugeria (fase 20-30) — essa parte da estratégia já está coberta e
  não precisa de mudança.
- **Não existe nenhum rastreamento de tentativas/derrotas por fase.**
  `CampaignRecords` (`lib/features/game/providers/campaign_records.dart:24`)
  só grava `LevelRecord` em vitórias. É necessário criar esse contador do
  zero.
- `LossReason`/`GameStatus` vivem em `GameState`
  (`lib/features/game/providers/game_state.dart:15,130`), calculados em
  `GameNotifier._outcomeAfterMove`
  (`lib/features/game/providers/game_notifier.dart:441-457`).
- A tela `game_screen.dart` já tem o padrão de overlays condicionais e
  mutuamente exclusivos dentro do `Stack`: `HammerOfferDialog`
  (`pendingHammerTarget != null && !state.isOver`, linha 341-347) e
  `MovesOfferDialog` (`_movesOfferOpen && !state.isOver &&
  pendingHammerTarget == null`, linha 355-362). O novo dialog segue o mesmo
  padrão, mas condicionado a `state.isOver`.

## Objetivo

Quando o jogador perde a mesma fase 3 vezes seguidas — e o Endless já está
desbloqueado — sugerir, via dialog, que ele experimente o Modo Recorde
enquanto "descansa" da fase difícil, em vez de simplesmente tentar de novo ou
desinstalar.

## Design

### 1. Contador de derrotas consecutivas

Novo campo `int consecutiveLosses` em `GameState`, ao lado de `lossReason`.

- Incrementa em `_outcomeAfterMove` sempre que o resultado é
  `GameStatus.lost`, mantendo a mesma fase (`level.number` inalterado).
- Reseta para `0` quando `status == GameStatus.won`, ou quando o jogador
  troca de fase (isto é, `startLevel` é chamado com um `level.number`
  diferente do anterior).
- Vive **apenas em memória** — não persiste em `GameStorage`. Fechar o app no
  meio de uma sequência de derrotas zera a contagem; é uma perda aceitável,
  já que o contador serve só de gatilho de sugestão, não é uma métrica de
  produto que precise sobreviver a reinícios do app.

### 2. Gatilho e critério

Novo getter `shouldOfferEndless` em `GameState`, seguindo o mesmo padrão de
guardas de `shouldOfferMoves`:

```
shouldOfferEndless =
    status == GameStatus.lost
    && consecutiveLosses >= 3
    && !endlessOfferShown
    && isEndlessUnlocked
```

`endlessOfferShown` é um flag por fase (resetado junto com
`consecutiveLosses`) que evita reabrir o convite a cada nova derrota depois
da terceira. `isEndlessUnlocked` reusa a mesma condição de
`kEndlessUnlockLevel` já usada em `level_select_screen.dart`.

Quem marca a oferta como mostrada é a **tela**, não a regra — mesmo padrão já
usado por `markMovesOfferShown()`: a UI sabe quando o cartão de fato subiu, a
regra só sabe que a fase está apertada.

### 3. UI — `EndlessSuggestionDialog`

Novo widget, seguindo exatamente o padrão de `HammerOfferDialog` /
`MovesOfferDialog`: overlay isolado no `Stack` de `game_screen.dart`,
condicionado a

```
state.isOver
&& state.shouldOfferEndless
&& pendingHammerTarget == null
&& !_movesOfferOpen
```

para nunca conviver com os outros dois overlays nem com o `LevelOutcomeCard`
de forma conflitante.

Copy (pt/en, via l10n): *"Sua energia nesta fase acabou! Que tal bater seu
Recorde Pessoal enquanto ela recarrega?"*

Dois botões:
- **"Ir para o Modo Recorde"** — navega para `EndlessScreen`.
- **"Continuar tentando"** — fecha o dialog, mantém o `LevelOutcomeCard`
  visível com o botão de retry normal.

### 4. Testes

- `GameNotifier`: incremento de `consecutiveLosses` em derrotas seguidas na
  mesma fase; reset ao vencer; reset ao trocar de fase.
- `shouldOfferEndless`: as quatro guardas isoladas (fase em derrota, contador
  abaixo/igual/acima de 3, oferta já mostrada, Endless bloqueado).
- `game_screen_test`: o dialog não aparece antes da 3ª derrota; aparece na
  3ª; não aparece se o Endless ainda não foi desbloqueado; não convive com
  `HammerOfferDialog`/`MovesOfferDialog` abertos.

## Fora de escopo (registrado, não decidido para implementação agora)

- **Ranking semanal / Ligas (Bronze–Diamante):** exige backend de
  leaderboard e sincronização online, infraestrutura que o projeto não tem
  hoje.
- **Passe de Temporada / eventos de 7 dias:** mesmo problema de
  infraestrutura, mais desenho de conteúdo recorrente.
- **Bônus de sequência diária (streak):** feature independente, não faz
  parte do gatilho de migração.

Essas três ficam registradas como possíveis próximas fases de retenção de
longo prazo, fora do escopo desta spec.
