# Economia de Resgate, Boosters Pagos e Ritmo de Dificuldade

Data: 2026-09-11

## Contexto

Três frentes independentes, pedidas juntas nesta tarefa por decisão explícita
do usuário (ver decisão de escopo abaixo): um segundo convite de resgate na
derrota por falta de movimentos, um dreno de moedas para os boosters (Martelo
existente + dois novos, Bomba e Pincel), e uma refatoração do gerador
procedural de fases para intercalar "fases hard" a partir do nível 30.

**Decisão de escopo:** tudo em uma spec só, incluindo os dois boosters novos
(Bomba, Pincel) que ainda não existem no código — decisão explícita do
usuário ao ser questionado, mesmo sabendo que isso aumenta bastante o
trabalho de implementação em relação a mexer só no Martelo.

## 1. Continue Offer — resgate ao zerar movimentos

Segundo convite, distinto do `MovesOfferDialog` pré-derrota já existente
(`kPreChurnMovesLeft`, disparado em `movesLeft == 2`, só anúncio). Este novo
`ContinueOfferDialog` aparece no momento em que a fase chegaria a `lost` por
falta de movimentos (`movesLeft == 0` e objetivo não cumprido), antes desse
estado ser definitivo — mesmo padrão de overlay que
`HammerOfferDialog`/`MovesOfferDialog` já usam sobre `LevelOutcomeCard`.

- `GameState` ganha `continueOfferShown: bool`, mesmo padrão de
  `movesOfferShown`/`hammerOfferShown`: garante o limite de 1 por partida.
- Duas opções, ambas creditam **+5** via `grantBonusMoves(5)` — reaproveita o
  mecanismo de `bonusMoves` que o DEM já usa (não conta como `moves`, pelo
  mesmo motivo já documentado: `moves` é o que o cartão de fim de fase
  relata).
  - **Opção A (vídeo):** novo `continueAdProvider` + `AdIds.continueRewarded`,
    unidade própria — mesmo motivo dos outros três funis de anúncio (saber
    qual funil paga; nunca reaproveitar unidade de outro).
  - **Opção B (moeda):** gasta `kContinueCoinPrice = 100` via `spendCoins`.
- Recusar as duas opções revela o `LevelOutcomeCard` de derrota por baixo,
  intacto — mesmo comportamento dos outros overlays de convite.
- Quem marca `continueOfferShown` é a tela (`ref.listen`), não o notifier —
  mesmo padrão já registrado para `movesOfferShown`/`endlessOfferShown`: só a
  UI sabe se o cartão chegou a subir de verdade.

## 2. Dreno de moedas nos boosters

### Martelo (já existe)

Sem mudança de mecânica. Acrescenta-se um botão "Comprar por
`kHammerCoinPrice`" dentro do `HammerOfferDialog` existente (Modo Fantasma),
ao lado do botão de anúncio — reaproveita o par `spendCoins` + `grantHammer`
que a loja de moedas já usa em outro lugar.

### Bomba (novo)

Mixin `BombBooster<S> on StateNotifier<S>`, mesmo formato do
`HammerBooster` (campanha e Endless são notifiers irmãos, cada um fornece
tabuleiro/motor/leitura-escrita de estado/aceite de interação/tratamento de
`Resolution`). Estado `BombState` — espelho de `HammerState`, mesmos campos
(`count`, `isTargeting`, `strike`, `strikes`, `pendingTarget`), Modo Fantasma
incluído (mesma UX de aquisição do Martelo).

**Efeito:** obliterar a área 3x3 ao redor da célula mirada (peça + obstáculo
em cada uma das 9 células), reaproveitando a rotina de limpeza de raio que o
`MatchEngine._detonate` já usa para a onda de choque do dígito máximo/Bloco 9
— extraída para um método compartilhado (`MatchEngine._clearArea` ou
equivalente) em vez de duplicar a lógica de varredura+`ObstacleHit`. Como o
Martelo (`smash`), não gasta movimento e não gera evolução de número; ao
contrário do Martelo, afeta 9 células. A cobertura destruída soma
`ObstacleHit` para o objetivo de fase, pela mesma razão (já registrada três
vezes no projeto) de qualquer fonte de dano a obstáculo precisar mesclar em
`ResolutionStep.obstacleHits`.

**Preço avulso:** `kBombCoinPrice = 150` — mais caro que Martelo/Pincel por
afetar área, não célula única (decisão do usuário).

### Pincel (novo)

Mixin `BrushBooster<S> on StateNotifier<S>` + `BrushState`, mesmo padrão.

**Efeito:** `MatchEngine.brush(position)` soma **+1** ao dígito da peça
mirada. Sem fusão, sem pontuação, sem gasto de movimento — irmão direto de
`smash`, só que incrementa em vez de remover. Recusa (devolve `null`) nas
mesmas condições que `smash`/`swapTiles` recusam: posição fora do tabuleiro,
casa vazia, peça já no dígito máximo (`kMaxDigit`), peça especial
(Super 9/Curinga, mesma imunidade já aplicada à Nova), fase encerrada ou em
encenação.

**Preço avulso:** `kBrushCoinPrice = 100`.

### UI compartilhada

`HammerBar` (dock de 1 slot) vira `BoosterDock` (dock de 3 slots: Martelo,
Bomba, Pincel), lado a lado, mesma forma/tamanho de célula que o Martelo já
usa. Continua fora do card de métricas (mesma regra: o card informa, o dock
age) e some com a fase encerrada. `HammerTargetingLayer` generaliza para
`BoosterTargetingLayer`, parametrizada pelo booster ativo — continua sendo
camada (não modo do tabuleiro), pela mesma razão já registrada: o toque fora
do tabuleiro precisa alcançar o cancelamento.

## 3. Drenagem via loja pré-jogo / in-game

Sem "pacotes com desconto" — não há requisito de preço de pacote no pedido
original, e nenhum outro item da economia do jogo tem desconto por lote; YAGNI.

- `LevelStartDialog` (pre-game) ganha uma mini-loja com os três preços avulsos
  (Martelo/Bomba/Pincel), mesmo padrão de botão que `HammerOfferDialog` já
  usa (desabilitado quando o saldo não cobre — `GameButton.onPressed`
  anulável já existe para isso).
- In-game, a compra avulsa já é coberta pelo Modo Fantasma de cada booster
  (seção 2) — não há uma segunda loja in-game separada.

## 4. Ritmo de dificuldade — fases hard no gerador procedural

`generateLevel(n)` continua função pura sobre `n` (garantia da Fase 15
preservada: sem histórico de jogo, sem estado mutável).

- **Gatilho:** `_isHardLevel(n)` — `n >= 30` e a posição da fase dentro do
  bloco (`_positionOf`, já existente) cai num degrau fixo por bloco (ex.
  `kBlockSize - 2`, a penúltima posição). Isso dá exatamente 1 fase hard a
  cada `kBlockSize` (10) fases, sem precisar de contador adicional — reusa a
  mesma aritmética de bloco/posição que `_objectiveFor` já usa.
- **Movimentos:** o resultado de `_moveLimitFor(...)` (já passado por
  `kTighteningPerBlock`/`kTighteningFloor`/`_pacingFactor`) é multiplicado por
  `0.75` quando `_isHardLevel(n)`, **antes** de aplicar o piso
  (`kMinMoveLimit`/`kHeavyDigitMoveFloor`) — para nunca cair abaixo do piso de
  projeto já existente, mesma garantia que impede o limite de zerar hoje.
- **Obstáculos:** `_obstaclesFor(block)` ganha um multiplicador de densidade
  quando a fase é hard: dobra a contagem de cada tipo presente no layout
  normal do bloco, respeitando `kMaxObstacles` como teto (mesmo trim que já
  existe para gelo excedente).
- **Fases >200 e uso de Pincel/Bomba:** não há enforcement de código forçando
  o uso de um item específico — o jogador sempre pode resolver por jogo hábil
  ou sorte. A partir da fase 200, quando `_isHardLevel(n)`, o objetivo/janela
  dessas fases é escolhido de forma que a calibragem via
  `simulate_economy.dart` (bot guloso, sem boosters) meça uma taxa de vitória
  visivelmente abaixo (alguns pontos percentuais) da fase não-hard vizinha do
  mesmo arquétipo — sinalizando que a fase foi desenhada esperando o uso de
  um booster, sem travar isso no motor. Registrado aqui como leitura de
  produto, não como regra de jogo verificável por teste unitário.
- **Calibragem obrigatória:** `dart run tool/simulate_economy.dart
  --mode=generated`, comparando fases hard vs. as duas vizinhas não-hard do
  mesmo bloco, antes de fechar a task — mesma disciplina de todas as
  calibragens anteriores do projeto (nunca escolher limite de movimentos a
  olho).

## Testes (parte 5 do pedido original)

- `flutter analyze` e `flutter test` verdes ao final de cada task do plano de
  implementação, não só no fim — mesma disciplina TDD já usada no projeto.
- Testes novos: `ContinueOfferDialog` (limite de 1 por partida, crédito de
  +5 pelas duas vias, revelação do cartão de derrota ao recusar);
  `BombBooster`/`BrushBooster` (efeito de área, efeito de +1, recusas,
  crédito de `ObstacleHit` da Bomba no objetivo, imunidade de peça especial
  no Pincel); `level_generator_test` (invariante de fase hard: -25%
  movimentos antes do piso, densidade dobrada de obstáculos, nunca abaixo do
  piso de projeto).
- Golden tests atualizados onde o HUD mudar de árvore/pixel (dock de 3
  boosters em vez de 1).

## Fora de escopo (decisão explícita)

- Pacotes com desconto por lote de boosters.
- Enforcement de código que impeça vencer uma fase >200 sem usar Bomba/Pincel
  — é calibragem de dificuldade, não regra de jogo.
- Cap diário de anúncios (regra 4 de monetização do CLAUDE.md) — já registrado
  como dívida pré-existente no projeto, não faz parte deste pedido.
