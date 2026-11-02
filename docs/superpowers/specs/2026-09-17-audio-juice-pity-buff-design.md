# AudioJuiceDirector & PityBuffSystem (2026-09-17)

## Contexto

Auditoria da estratégia de "motor de dopamina" do produto contra o estado
atual do NineFuse identificou dois gaps reais (ver conversa de origem):
não existe motor de áudio no projeto, e a regra das 3 derrotas consecutivas
hoje só sugere migrar para o Modo Recorde, sem afrouxar a fase atual nem
oferecer uma fase de respiro depois de uma fase hard. Este documento cobre
as duas frentes.

## 1. AudioJuiceDirector

### Objetivo
Adicionar a camada de áudio que acompanha o Juice visual já existente
(`JuiceOverlay`, `JuiceDirector`, `JuiceTimings`), com pitch progressivo por
cascata e reação ao clímax do Nova/Super 9 — sem tocar na lógica visual/tátil
já implementada.

### Arquitetura
- **`AudioJuicePort`** (interface, `lib/features/game/domain/audio_juice_port.dart`):
  contrato mínimo — `playMerge(MergeTier tier)`, `playCascadeStep(int step)`,
  `playComboFanfare()`, `playNovaStinger(NovaTier tier)`, `duckBgm(Duration d)`.
  Mesmo padrão de `RewardedAdPort`/`AdMobRewardedPort`: a porta separa decisão
  (testável em Dart puro) de execução (SDK real, sem teste automatizado).
- **`AudioJuiceDirector`** (`lib/features/game/providers/audio_juice_director.dart`):
  classe pura, sem Riverpod nem estado de widget. Recebe uma `Resolution`
  (mesma estrutura que a UI já consome) e decide:
  - Tier de fusão por valor da peça: 1-4 → `MergeTier.low`, 5-8 →
    `MergeTier.mid`. Nada acima disso (9/Nova) passa por aqui — é tratado
    pelo caminho de clímax abaixo.
  - `cascadeStep`: contador interno, incrementado a cada `ResolutionStep`
    com `cascade > 0` dentro da mesma `Resolution`; resetado no início de
    cada jogada nova (golpe de martelo ou swap). Pitch:
    `1.0 + (cascadeStep * 0.0594)`, com cap em `2.0` (12 semitons).
  - `cascadeStep >= 5` (a quinta cascata da mesma jogada): dispara
    `playComboFanfare()` ao final da resolução, além do som de cascata normal.
  - `NovaEvent`/`apexCelebrated` no step: dispara `playNovaStinger(tier)` +
    `duckBgm(Duration(seconds: 1))`, alinhado ao `hitstop` que `JuiceTimings`
    já define (90ms Nova / 250ms Super Nova) — o stinger dispara no mesmo
    instante em que o hitstop começa, não depois.
- **`AudioPlayersJuicePort`** (`lib/core/audio/audioplayers_juice_port.dart`):
  implementação concreta sobre o pacote `audioplayers`, com pool de players
  pré-carregados (`AudioCache`) para os 4 assets. Pitch é aplicado via
  `setPlaybackRate` (o pacote suporta rate ≠ 1.0 no `AudioPlayer` de baixa
  latência). Sem teste automatizado — mediria o pacote, não o jogo, mesma
  régua já registrada para `AdMobRewardedPort`.
- **Ducking sem BGM real**: o projeto não tem trilha musical hoje.
  `duckBgm` na implementação concreta é no-op seguro (não lança, não trava)
  até existir uma BGM carregada — evita acoplar este trabalho a uma feature
  que ainda não existe.
- **Assets**: `sfx_merge_low.wav`, `sfx_merge_mid.wav`,
  `sfx_combo_fanfare.wav`, `sfx_nova_impact.wav` — tons sintéticos gerados
  por script (`tool/generate_placeholder_sfx.dart` ou script Python via
  `numpy`/`wave`, a decidir na implementação), não arte de áudio real. São
  placeholders explícitos a substituir quando houver SFX de produção — mesmo
  espírito dos IDs de teste do AdMob.
- **Integração**: `GameNotifier`/`EndlessNotifier` (os dois notifiers
  irmãos, mesmo padrão do `HammerBooster`) chamam `AudioJuiceDirector` no
  mesmo ponto em que já disparam a encenação visual (`_playResolution`),
  passando a `Resolution` da jogada. Um único `audioJuiceDirectorProvider`
  compartilhado pelos dois, análogo ao que já existe para boosters.

### Testes
- `AudioJuiceDirector` puro, com uma `FakeAudioJuicePort` registrando
  chamadas: tier correto por valor de peça, `cascadeStep` incrementa e
  reseta certo entre jogadas, fórmula de pitch bate (incluindo o cap em
  2.0 a partir do 18º semitom equivalente), combo ≥5 dispara fanfarra,
  Nova/Super 9 dispara stinger + ducking.
- Sem teste de widget novo — a integração nos notifiers é uma chamada a
  mais no mesmo método já coberto por `game_notifier_test.dart`.

## 2. PityBuffSystem

### Objetivo
Substituir o efeito puramente informativo da regra de 3 derrotas
consecutivas por uma ajuda real na tentativa seguinte, e declarar uma fase
de respiro depois de toda fase hard — sem violar a invariante já registrada
do projeto: o tabuleiro nunca é fixado por seed, e `generateLevel(n)`
continua sendo função pura de `n`.

### Regras
- **`GameState.isPityBuffActive`** (novo campo bool, default `false`).
  Setado para `true` na mesma transição que hoje já calcula
  `consecutiveLosses >= 3` (derrota), e resetado para `false` assim que
  `startLevel` é chamado com o buff já aplicado — consumido uma única vez,
  não persiste entre tentativas além da primeira depois da terceira derrota.
- **LuckyStart (retry por rejeição)**: `startLevel`, quando
  `isPityBuffActive`, estende a checagem de jogabilidade que a Fase 13 já
  faz (gera tabuleiro, confere `hasValidMoves`, senão tenta de novo) com uma
  condição extra: o tabuleiro só é aceito se existir, entre as trocas
  candidatas, alguma que resulte em fusão de peça nível 5+. Mesmo cap de
  tentativas que a checagem de jogabilidade já usa, para não criar um loop
  sem teto — se o cap for atingido sem sucesso, aceita o melhor tabuleiro
  já gerado (nunca trava a fase por causa do buff).
- **+3 movimentos**: aplicado direto ao `moveLimit` resolvido da fase em
  `startLevel`, somente quando `isPityBuffActive` — não usa `bonusMoves`
  (reservado a recompensas *durante* uma fase já iniciada, como o DEM).
- **Fase de alívio pós-hard**: dentro de `generateLevel(n)`
  (`lib/features/game/domain/level_generator.dart`), quando
  `isHardLevel(n - 1)` é verdadeiro, a fase `n`:
  - aplica `_obstaclesFor(block, hard: false)` e reduz o resultado em 50%
    adicional (arredondando para baixo, mínimo 0);
  - vieses a janela de spawn dessa fase para favorecer 6 e 7 (ajusta
    `spawnMin`/`spawnMax` para essa fase específica, sem alterar o degrau
    normal de progressão do bloco — a fase seguinte a ela volta ao cálculo
    padrão);
  - prioriza objetivo `reachDigit` (em vez de cobertura) nessa posição
    específica do bloco, para o jogador conseguir montar Nova/Super 9 com
    facilidade.
  - Continua função pura de `n`: nenhum estado de `GameState` entra em
    `generateLevel`, preservando a decisão da Fase 15.

### Testes
- `level_generator_test.dart`: nova invariante de faixa (11 a 1000, mesma
  disciplina das invariantes existentes) — toda fase imediatamente após uma
  `isHardLevel` tem obstáculo ≤ 50% do que a fórmula normal daria e janela
  de spawn deslocada para 6/7.
- `game_state_test.dart` / `game_notifier_test.dart`: `isPityBuffActive`
  liga na terceira derrota consecutiva e desliga após o próximo
  `startLevel`; `moveLimit` recebe +3 só quando o buff está ativo; LuckyStart
  rejeita um tabuleiro fake sem match 5+ e aceita um que tenha.

## Fora de escopo (decisão explícita)
- BGM real e mixagem de ducking de verdade — o ducking é no-op seguro até
  existir trilha.
- SFX de produção — os 4 arquivos são placeholders sintéticos.
- Qualquer ajuste ao `HammerBooster`/`JuiceOverlay` existentes além dos
  pontos de integração descritos.
- Persistência de `isPityBuffActive` em disco — é estado de sessão, mesmo
  espírito de `consecutiveLosses` já não ser persistido hoje.
