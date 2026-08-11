# CLAUDE.md - Contexto & Regras do Projeto (NineFuse)

## Visão Geral do Projeto
Jogo de quebra-cabeça estilo Match-3 Lógico (inspirado em Candy Crush + 2048) utilizando números de 0 a 9.
- **Nome do App:** NineFuse
- **Linguagem/Framework:** Dart / Flutter
- **Gerenciamento de Estado:** Riverpod (`flutter_riverpod`)
- **Foco de UX:** Sem trava de vidas, gameplay contínuo, animações fluídas de fusão e visual diegético/clean (Dark Mode por padrão).

## Core Gameplay & Diferenciais
1. **Mecânica de Fusão (Evolução dos Números):** 
   - Ao alinhar 3 ou mais números iguais (ex: três blocos `4`), eles não apenas somem.
   - O bloco central da combinação **evolui para o próximo número** (ex: vira um `5` energizado), e os outros blocos somem liberando espaço para a queda do topo.
2. **A Assinatura do Número 9 (Lendário / Apex Tile):**
   - Alcançar o número `9` é o clímax do jogo: ativa uma animação de onda de choque (*Shockwave*), elimina obstáculos/peças vizinhas fracas, concede **+3 movimentos bônus** (`kExplosionBonusMoves`) e dispara a celebração do evento NineFuse.
3. **Obstáculos do Tabuleiro (Gelo, Vidro, Pedra):**
   - Elementos de bloqueio que adicionam variedade ao Level Design procedural (Gelo = 1 fusão adjacente; Vidro = 2 fusões; Pedra = 3 fusões ou Onda de Choque do 9).
4. **Modos de Jogo:**
   - **Campanha (Saga Map):** Fases com objetivos e limite de movimentos.
   - **Modo Recorde (Endless):** Desbloqueado após a fase 5. Janela de spawn progressiva e recorde persistido.

## Diretrizes de Arquitetura & Código

### Estrutura de Pastas
Organize a pasta `lib/` da seguinte forma:
- `lib/core/` -> Temas, constantes (paleta de cores dos dígitos) e utilitários.
- `lib/features/game/domain/` -> Modelos de dados (`Tile`, `Board`, `Position`, `MatchResult`, `ObstacleType`).
- `lib/features/game/presentation/` -> Telas, componentes do Grid, animações de fusão, modais e HUD diegético.
- `lib/features/game/providers/` -> Notifiers do Riverpod, persitência e lógica do estado do jogo.

### Padrões de Desenvolvimento
- Use **immutability** para o estado do tabuleiro (`Tile` e `Board` imutáveis).
- Mantenha a lógica do algoritmo do Match-3, fusão e gravidade estritamente no `domain` e `providers`.
- **Animações e Performance:** Não use `Future.delayed` em widgets de UI; use `AnimationController`. Evite sombras pesadas em textos que sofrem animação contínua (previne bugs de renderização no Impeller).

## Regras de Execução & Comandos Úteis
- **Rodar o projeto:** `flutter run`
- **Análise estática:** `flutter analyze`
- **Executar testes:** `flutter test`
- **Simular Economia:** `dart run tool/simulate_economy.dart --mode=both`

## Mapeamento Inicial dos Números & Cores
Cada dígito possui uma cor vibrante e bem definida em `lib/core/constants/app_colors.dart`:
- `0`: Vermelho vibrante (`0xFFE53935`)
- `1`: Azul neon (`0xFF1E88E5`)
- `2`: Verde lima (`0xFF43A047`)
- `3`: Amarelo/Dourado (`0xFFFDD835`)
- `4`: Laranja (`0xFFFB8C00`)
- `5`: Roxo (`0xFF8E24AA`)
- `6`: Rosa neon (`0xFFFF3DA5`)
- `7`: Ciano (`0xFF00ACC1`)
- `8`: Violeta/Índigo (`0xFF3949AB`)
- `9`: **Dourado Místico Dinâmico** — Degradê `0xFFFFD700` → `0xFFFF8C00`, com animação de pulso/respiração contínua e brilho neon (`AppColors.apexGlow`).

---

## Roadmap & Registro de Evolução

### Fase 1 a 3: Core, UI & Engine Basal ✅ Concluídas
- Engine de Match-3 isolada e testável (`MatchEngine`).
- Suíte de testes unitários cobrindo cascatas, combinações disjuntas e trocas recusadas.

### Fase 4: Economia de Fusão e Regras de Tabuleiro ✅ Concluída
- Regra de fusão calibrada (`TieredFusion` como padrão).
- Validação da invariância da janela de spawn e resolução do problema de assoreamento.
- Modos Campanha e Endless com persistência via `GameStorage`.

### Fase 8 a 12: Animações, Recompensas e UI Diegética ✅ Concluídas
- Sistema de animação baseado em posições absolutas (`tileVisualKey`).
- Sequenciamento de cascatas, combos e pontos flutuantes (`JuiceTimings`).
- Ritual do Dígito 9 com batida tátil (`HapticFeedback`), partículas e bônus de jogadas.
- Trilha de Fases (Saga Map) com progresso persistido.
- HUD Diegético com botões táteis (`GameButton`), molduras de métricas (`GameMetricCard`) e diálogos com personalidade (`GameDialog`).

### Fase 13: Obstáculos & Expansão de Fases ✅ Concluída
- [x] Enum `ObstacleType { none, ice, glass, stone }` (`domain/obstacle.dart`) e os
      campos `obstacle`/`obstacleHp` no `Tile`.
- [x] Redução de vida via fusão adjacente no `MatchEngine`, com `ObstacleHit` por passo.
- [x] Texturas de Gelo, Vidro e Pedra (`ObstacleOverlay`) e partículas de quebra
      (`ObstacleShatter`, no `JuiceOverlay`).
- [x] Inclusão dos obstáculos nas fases procedurais do Modo Endless e a partir da Fase 8 da Campanha
      (`ObstacleLayout`, `MatchEngine.placeObstacles`, `EndlessProgression.obstaclesFor`).

**A cobertura prende a peça; não a substitui.** O dígito continua embaixo e
continua legível — se o jogador não vê o que vai ganhar, o obstáculo é só um
buraco no tabuleiro. Daí as duas guardas que a mecânica exige: peça coberta não
entra em combinação (`_runs` a trata como casa vazia) e não pode ser trocada.

A segunda importa mais do que parece: `hasValidMoves` é derivado de
`candidateSwaps`, então sem excluir a célula coberta ali o jogo diria "ainda dá
para jogar" apoiado numa jogada que `tryMove` recusa — exatamente o falso fim de
jogo que a `LossReason` existe para evitar.

**A área de dano é ortogonal, e um impacto por passo.** A diagonal fica de fora
porque é a mesma régua da troca válida: misturar as duas faria o jogador esperar
dano onde não pode nem jogar. E o limite de um impacto por passo — por mais
combinações que toquem a mesma célula — é o que impede uma cascata feliz de
derreter uma pedra inteira de uma vez, esvaziando o sentido de "três impactos".
Há teste para cada uma das duas regras.

**O dano roda antes da explosão e da queda**, para a cobertura liberada cair no
mesmo passo em vez de esperar o movimento seguinte. Como efeito colateral
desejado, a onda de choque do `9` varre a célula coberta por inteiro — a pedra
cede ao clímax sem código dedicado.

**`ObstacleHit` guarda o tipo de *antes* do impacto.** Numa quebra o tipo de
depois é sempre `none`, e a UI não saberia que partícula desenhar. A posição é a
de antes da gravidade: é onde a quebra acontece na tela, no mesmo quadro em que
as peças da combinação ainda estão visíveis.

**`withObstacle` é o único caminho de criação.** Passar `obstacleHp` à mão
permitiria um gelo de três impactos, que não é gelo nenhum; um `assert` no
construtor amarra cobertura e vida.

**O desenho de fase pede quantidade; o motor escolhe o lugar.** `ObstacleLayout`
diz *quantas* coberturas de cada tipo a fase quer, e `MatchEngine.placeObstacles`
decide onde cabem. Guardar posições fixas tornaria toda tentativa da fase
idêntica, e a campanha do NineFuse é procedural. Duas guardas, cada uma com
teste: **coberturas nunca nascem encostadas** (a área de dano é ortogonal, então
um bloco maciço teria células internas que nenhuma fusão alcança) e **nenhuma
cobertura é posta se tirar a última jogada** — sem isso o próprio jogo fabricaria
o fim de partida que a `LossReason` existe para explicar. Cobertura que não acha
lugar é descartada, e por isso `types` entrega o tipo mais duro primeiro: perder
um gelo muda pouco; perder a pedra muda o que a fase pede.

**A cobertura entra depois da checagem de jogabilidade, não antes.**
`generateBoard` sorteia, confirma que há jogada e só então cobre — checar antes
daria veredito sobre um tabuleiro que não é o que o jogador recebe.

**Um tipo por estreia, e a pedra por último.** Campanha: fase 8 só gelo (cede a
um impacto, ensina a regra sem punir), fase 9 acrescenta vidro, fase 10 traz a
pedra — porque é a fase que dá a onda de choque, a única saída que varre três
impactos de uma vez. No Endless a cobertura entra **ao subir de degrau**, junto
com a janela: quem provou que domina a faixa recebe o tabuleiro mais apertado. O
primeiro degrau é limpo de propósito — a pressão do modo já vem do sorteio.

**A calibragem foi remedida, não presumida.** `dart run tool/simulate_economy.dart
--mode=phases` passou a gerar o tabuleiro com `level.obstacles`; as fases 8-10
seguem em 87-90% de vitórias, dentro da meta. Um simulador que ignora o obstáculo
mede uma fase que não existe.

**Armadilhas desta rodada:**
- **Nada de `Opacity` nem `FadeTransition` dentro da cobertura.** Os testes de
  saída de peça e de clarão de combinação grande usam esses tipos como
  marcadores dentro do `TileWidget`; um a mais os quebraria em silêncio. A
  translucidez vem de cores com alfa, e há teste travando isso — com o finder
  **escopado na peça**, porque as transições de rota do `MaterialApp` também são
  `FadeTransition` e um `findsNothing` global passa por acidente.
- **Semente fixa nas trincas e nos cacos**, como nas faíscas da explosão: sem
  ela a rachadura dança a cada quadro reconstruído e nenhum golden se sustenta.
- **`_ParticlePainter` ganhou `tint` opcional, não obrigatório.** Sem material
  ele mantém o branco/prata da explosão do dígito máximo — foi o golden
  `juice_fusion.png` não mudando que confirmou o refactor como neutro.

**Ainda não implementado, e é decisão de projeto:** peça coberta **cai** com a
gravidade como qualquer outra. Ancorá-la (com as de cima empilhando) é o que
transforma o obstáculo em ferramenta de level design — "quebre o gelo do canto"
só faz sentido se o gelo ficar no canto —, mas mexe em `applyGravity`.


### Fase 14: Condições de Vitória por Objetivo (`LevelObjective`) ✅ Concluída
1. **Tipos de Metas** (`domain/level_objective.dart`, `ObjectiveType`):
   - `reachDigit`: Formar o dígito alvo em até N movimentos.
   - `clearObstacles`: Destruir N unidades de um obstáculo (Gelo, Vidro ou Pedra).
   - `clearAllObstacles`: Remover 100% dos bloqueios de um determinado tipo do tabuleiro.
2. **Prioridade de Resolução:**
   - A destruição do último obstáculo na jogada final concede a vitória ANTES do encerramento por limite de movimentos (`movesLeft == 0`).

**`Objective` saiu de `game_level.dart` e ganhou arquivo próprio**, com
`export` de volta para quem já lia dali — pedir uma fase quase sempre é pedir o
objetivo junto, e mudar todos os imports não pagaria o trabalho.

**`digit` virou `int?`, e é de propósito.** Uma fase de pedra não tem
dígito-alvo, e um valor de fachada faria o HUD e o mapa pintarem a fase com a
cor de uma peça que ela não pede. Onde não há dígito, a assinatura de cor passa
a ser a da cobertura (`obstacleAccent`) — a mesma que ela tem no tabuleiro.

**`ObjectiveType` existe em vez de `digit == null`.** Deduzir o tipo de um campo
nulo funcionaria hoje e quebraria na primeira meta nova.

**O alvo de "limpe todas" sai do tabuleiro, não do pedido da fase.**
`placeObstacles` descarta a cobertura que não acha lugar, então cobrar as quatro
pedras que a fase pediu num tabuleiro onde só três couberam seria fabricar uma
fase impossível por acidente de sorteio. `GameState.boardObstacleGoal` é fixado
em `startLevel` (e recalculado em `debugSetBoard`, senão a fase cobraria as
coberturas do tabuleiro que o teste substituiu); `objectiveTarget` cai de volta
em "restantes + já quebradas" quando ele é nulo, soma que é invariante porque
nenhuma cobertura nasce no meio da fase.

**Só a quebra conta como progresso** (`Resolution.countCleared`): trincar o
vidro não soma, porque não é o que o jogador vê sumir do tabuleiro. O contador
tem de contar a mesma coisa que o olho.

**A ordem de `_outcomeAfterMove` já resolvia a jogada final** — vitória antes das
derrotas —, e agora há teste para o caso da cobertura: `moveLimit: 1`, o
movimento que quebra o último gelo é o mesmo que zera o saldo, e o desfecho é
`won` com `lossReason` nulo.

**As invariantes de campanha passaram a falar só das fases de dígito**
(`digitLevels` em `game_level_test`): janela de spawn e progressão de
dificuldade não têm o que comparar numa fase de cobertura, e forçá-la para
dentro da conta pediria de volta o número de fachada.

**A calibragem ganhou seção própria** (`--mode=obstacles`), separada da
campanha porque essas fases ainda **não** estão em `kCampaign`: o limite de
movimentos precisa ser escolhido antes de a fase existir. O jogador automático
segue guloso por fusão e nunca mira a cobertura, então o número é um **piso** —
"limpe 3 gelos" dá 78-80% em 15-20 movimentos; vidro e pedra ficam abaixo da
meta mesmo com 40, o que era de esperar de um bot que só as quebra de raspão.
A campanha atual segue intacta e calibrada (fases 8-10 em 83-88%).


### Booster: Martelo de Fusão (`HammerBooster`) ✅ Concluído
1. **Regra Mecânica:** `MatchEngine.smash` oblitera a célula inteira (Peça + Obstáculo) na posição informada. Não reduz `movesLeft` e não gera evolução de número.
2. **Game Feel:** A destruição dispara o `ShatterEffect` na cor do dígito e aciona a gravidade/cascatas imediatamente.
3. **UX de Cancelamento:** O botão no HUD altera de estado para "CANCELAR (X)" durante o modo de mira (`isHammerTargeting == true`), e um toque fora do tabuleiro também desiste.
4. **Funil de Conversão:** Seleção prévia com `hammerCount == 0` permite o "Modo Fantasma", abrindo o modal de Rewarded Ad com o alvo já destacado.

**O golpe não funde nada, mas a queda funde.** O dígito atingido não evolui nem
pontua — não é uma fusão, é uma remoção. Já as combinações que a **queda** forma
por acidente resolvem normalmente, pontuam e contam para o objetivo: deixá-las
alinhadas e inertes seria o único estado do jogo em que uma combinação formada
não resolve, e o jogador leria isso como defeito, não como regra.

**O golpe entra como passo 0 da resolução.** Um `ResolutionStep` de `cascade: 0`,
sem fusões, cujo `boardAfterFusion` é o tabuleiro com o buraco e o
`boardAfterSettle` é o assentamento. Com isso o martelo herda os dois quadros da
encenação sem um caminho de animação paralelo ao das fusões — e, sendo cascata
zero, não anuncia combo. As cascatas que ele causar seguem numeradas de 1.

**A cobertura destruída viaja como `ObstacleHit`.** Não basta ela sair do
tabuleiro: `boardObstacleGoal` é fixado em `startLevel`, então um gelo removido
pelo martelo sem contar como progresso tornaria a fase **impossível de vencer**.
Há teste para o objetivo somando o golpe.

**Recusar não cobra.** Posição fora do tabuleiro ou casa vazia devolve `null` do
motor, e o notifier avisa por som/tato mantendo a mira ligada — cobrar um martelo
por um erro de dedo é o pior lugar possível para o jogo cobrar. Mira e golpe
também são recusados com a fase encerrada ou durante a encenação, pela mesma
régua de `swapTiles`.

**O inventário mora no `GameState`, não num notifier próprio.** A UI lê o saldo
do mesmo lugar de onde a regra o consome; duas fontes de verdade divergiriam no
primeiro anúncio assistido. Atravessa `startLevel` sem zerar (é inventário do
jogador, não da fase) e é persistido em `GameStorage`. Falha de leitura vale como
estoque vazio — perder o martelo é ruim, travar o jogo é pior.

**`hammerStrikes` existe só para ser chave.** Dois golpes na mesma célula com o
mesmo dígito são indistinguíveis por `hammerStrike`, e o segundo não reacenderia
a animação do estilhaço.

**A mira é uma camada, e não um modo do tabuleiro** (`HammerTargetingLayer`).
Tratar o golpe no `onTileTap` resolveria metade: o toque **fora** do tabuleiro
nunca chegaria a ninguém, porque a área vazia da tela pertence à rolagem, que
consome o gesto sem repassá-lo — e cancelar tocando fora é justamente a saída que
a mira precisa ter. A camada converte toque em célula com o `BoardGeometry.cellAt`,
a mesma conta que posiciona as peças: duas fórmulas divergiriam um dia, e o
jogador bateria numa célula vendo a vizinha explodir. O véu recorta o tabuleiro
em vez de cobri-lo, senão apagaria justamente os dígitos entre os quais ele está
escolhendo.

**Sem economia de moedas, de propósito.** O jogo não tem moedas; um botão
desabilitado na tela comunica menos do que sua ausência. O anúncio é uma costura
injetável (`hammerAdProvider`) porque **não há SDK de anúncio no projeto** — o
padrão paga o jogador, já que um funil que nunca conclui é pior do que a casa
pagar. **É o ponto a trocar antes de monetizar de verdade.**

**Bug de tela larga achado no caminho.** `BoardGridWidget` montava a geometria
sobre o espaço disponível e depois centralizava a moldura, somando duas vezes o
deslocamento de centralização: em qualquer tela mais larga que `kMaxBoardSide` as
peças escorriam para fora da própria moldura. Só não aparecia porque em celular
`_originX` é zero. Corrigido, com teste de regressão em tela larga.