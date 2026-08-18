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
cede ao clímax fisicamente sem código dedicado, mas contabilmente ela precisou
de um: `_detonate` também lê o `ObstacleType` de cada célula que a onda alcança
antes de esvaziá-la, e `_mergeObstacleHits` funde esse resultado com os
impactos que a fusão já tinha registrado no mesmo passo — sem duplicar hit numa
cobertura que as duas fontes tocaram. **Isto foi bug, não decisão**: até a
calibragem de fases procedurais expor o caso (janela de sorteio alta, quase
todo topo virando `9`, 0% de vitória em fases de "limpe toda a pedra" mesmo com
90 movimentos), a explosão limpava a cobertura da tela sem emitir `ObstacleHit`
nenhum — o pior tipo de bug de regra, porque o jogador *vê* a pedra sumir e o
jogo *discorda* dele, negando o progresso do objetivo por uma ação que acabou
de acontecer diante dos seus olhos. A correção manteve a assimetria de sempre:
o hit da onda é sempre destruição total (`remainingHp: 0`), independente de
quanta vida a cobertura ainda tivesse — é o que já valia fisicamente, e agora
vale também no que o objetivo conta.

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

**O booster vale nos dois modos, e o estoque é um só.** A regra vive num mixin
(`HammerBooster`) que campanha e Endless compartilham, sobre um `HammerState`
único que os dois estados carregam. Campanha e Endless são notifiers **irmãos**,
não pai e filho — cada um tem o seu desfecho —, mas duas cópias da regra
divergiriam no primeiro ajuste de balanceamento e o jogador veria o mesmo item se
comportar de dois jeitos. Cada notifier fornece cinco coisas: tabuleiro, motor,
leitura/escrita do `HammerState`, se aceita interação agora, e o que fazer com a
`Resolution`.

**No Endless o martelo compra outra coisa.** Não há limite de movimentos, então o
que ele compra é o fim da corrida não ser agora — destravar. O golpe segue **não
contando como movimento**, porque `moves` é o que o cartão de fim de corrida
relata. E o **recorde conta normalmente**: decisão de produto, o martelo é parte
do jogo como o bônus do dígito 9.

**Os dois notifiers podem estar vivos ao mesmo tempo** (a tela do Endless abre por
cima da campanha), então o estoque é relido do disco ao começar cada fase ou
corrida — `refreshHammers`, o mesmo remédio que `EndlessHighScore.refresh` já usa
para o recorde. Uma leitura que chega depois de o saldo ter mudado em memória é
descartada: o disco está velho, e adotá-lo apagaria um martelo recém-creditado.

**Bug de tela larga achado no caminho.** `BoardGridWidget` montava a geometria
sobre o espaço disponível e depois centralizava a moldura, somando duas vezes o
deslocamento de centralização: em qualquer tela mais larga que `kMaxBoardSide` as
peças escorriam para fora da própria moldura. Só não aparecia porque em celular
`_originX` é zero. Corrigido, com teste de regressão em tela larga.


### Economia de Moedas ✅ Concluída

**Só estrela nova paga, e isso dispensa qualquer regra anti-farm.**
`CampaignRecords.record()` já devolve o ganho com as estrelas que o jogador
tinha descontadas — é a conta que decide se a fase progrediu, e ela já existia
antes da moeda. Rejogar a fase 1 em looping rende zero porque não há estrela
nova para render, não porque alguém escreveu uma trava contra isso. Inventar uma
regra própria de anti-farm teria sido duplicar uma invariante que o jogo já
garantia por outro motivo.

**A carteira existe apesar de o martelo morar no `GameState`.** O mapa da saga
roda fora de qualquer partida — não há `GameState` de onde ler saldo entre uma
fase e outra, como há para o martelo. O disco continua sendo a autoridade
única (o mesmo remédio de `EndlessHighScore.refresh`); o `Wallet` é só o rosto
dele para as telas de fora da partida. Dentro da fase, nada mudou: o
`GameNotifier` segue sendo quem decide o que a jogada vale.

**O `refresh` conserta o martelo, não a moeda.** A moeda é creditada direto no
`walletProvider`, que o mapa observa — chega em memória sozinha, sem
intermediário. O martelo é gasto por `HammerBooster`, que escreve só no disco;
por isso ele é quem precisa da releitura explícita ao voltar para uma tela viva.
São dois caminhos diferentes porque são dois donos de estado diferentes, e
tratar os dois com o mesmo remédio teria sido copiar a solução sem copiar o
problema.

**`spendCoins` não credita o item — quem credita é `grantHammer`.** A compra
debita a carteira e dispara o mesmo `onGranted` que o anúncio recompensado já
usa; é `HammerOfferDialog` quem chama `grantHammer` depois, no alvo já guardado
pelo Modo Fantasma. Se `spendCoins` também creditasse o martelo, uma compra
feita pelo caminho de anúncio-com-moeda-de-troco daria dois martelos por um
pagamento só. Separar em "paga" e "credita" é o que deixa os dois funis —
anúncio e moeda — convergirem no mesmo `onGranted` sem se pisarem.

**O baú guarda quem já pagou** (`campaign_chests_claimed`), porque sem isso o
mapa repagaria o mesmo baú a cada visita — abrir o mapa de novo não é reabrir o
capítulo. É um baú por capítulo, e por decisão de sequenciamento a UI dele
pertence à fase seguinte: mostrar o baú é trabalho de tela, e a Fase A entrega a
regra, não o nó visual.

**`GameButton.onPressed` virou anulável** para o botão de compra do
`HammerOfferDialog` poder ficar desabilitado quando o saldo não cobre o preço.
Só `onTapDown` checa o callback antes de animar (`if (!_enabled) return;`); com
`_pressed` já falso nesse caminho, `onTapUp` e `onTapCancel` são no-op — não
precisam da mesma checagem. Um botão que afunda ao toque promete uma ação que
não vem quando falta moeda, e essa promessa quebrada é pior do que o botão
simplesmente não reagir.

**Os números são um piso a calibrar, não um veredito.** `kCoinsPerStar = 10`,
`kHammerCoinPrice = 100` e `kChapterChestReward = 200` (`domain/economy.dart`)
dão à campanha inteira em três estrelas 300 moedas, mais 200 por baú — o
suficiente para comprar um martelo antes do fim, não para nadar neles. O
anúncio recompensado segue como caminho principal de aquisição do martelo; a
moeda é o consolo de quem prefere não assistir.

**Ainda não implementado, e é decisão explícita:** a UI da economia — barra de
recursos no mapa, pílula do Endless, nó do baú — é a Fase B, com plano próprio;
a Fase A entrega a economia funcionando e testada, sem nada de novo na tela além
do botão de compra. O cap de 3 martelos/dia da regra de AdMob continua fora,
como já estava.

**O spec pedia `refreshHammers` reconciliando contra o `Wallet`; ficou lendo o
disco direto, e é desvio deliberado.** `HammerBooster.refreshHammers` continua
chamando `readHammerCount()` na fonte, sem passar pelo provider. Não há como os
dois divergirem: o disco é a autoridade única, e `HammerBooster` é o único
escritor de martelo — reconciliar contra o `Wallet` seria comparar duas leituras
do mesmo dado, nunca corrigir uma divergência real. Fazer o booster depender do
`Wallet` acoplaria uma regra de partida (que roda em Dart puro, testável sem
Riverpod) a um `StateNotifierProvider` só para reler um número que já lê direto
— trocaria uma leitura simples por uma dependência circular de camada sem
ganhar nada em troca.


### Regras de Monetização & Exibição de Anúncios (AdMob)
1. **Preload Obrigatorio:** Anúncios Recompensados e Intersticiais devem ser carregados no início do nível (`LevelStart`).
2. **Anti-Churn de Derrota:** Intersticiais são proibidos em telas de Game Over/Derrota. Permitidos apenas pós-vitória ou na saída para o Mapa (respeitando intervalo mínimo de 45s de jogo).
3. **Pre-Churn Trigger:** Oferecer via Rewarded Ad um número dinâmico de
   movimentos (entre 4 e 10, escalando com as metas restantes da fase — ver
   "Dynamic Extra Moves (DEM)") quando `movesLeft == 2` e a vitória não
   estiver garantida.
4. **Cap de Limite:** Máximo de 3 Martelos por dia via Rewarded Ads para preservar a economia interna.
5. **Benefícios No-Ads Pass:** Remove intersticiais e ativa o Bônus Diário VIP (+50 Moedas/dia).

### Diretrizes de UI/UX: Booster Martelo de Fusão
1. **Design de Botão:** Formato circular compacto com badge de quantidade no canto. DEVE ficar fora do card principal de métricas. Posicionado no canto superior direito do grid ou em row dedicada abaixo das métricas.
2. **Estado Zero:** Se quantidade == 0, botão mostra "+" e abre modal de compra/ad ao invés de ativar mira.
3. **Modo de Mira:** Ativa `BackdropFilter` (blur 3px + scrim preto 60%) com transição de 150ms. Remove qualquer efeito antigo de opacidade nas células. A célula sob o toque fura o scrim, escala 1.1x, ganha borda pulsante neon e overlay vermelho de preview.
4. **Cancelamento:** Botão do HUD vira "X" vermelho durante a mira. Toque fora das células cancela.
5. **Feedback Tátil & Sonoro:** `selectionClick` no engajamento da mira + `heavyImpact` na destruição. SFX distintos para ativação e explosão. Camera shake de 100ms + partículas da cor da peça no momento da quebra.
6. **Performance:** Todo `BackdropFilter` deve estar contido em um `ClipRect` para evitar gargalos de renderização no grid.

#### Como as seis diretrizes foram implementadas ✅

**O botão saiu do card, e o card perdeu o parâmetro.** `LevelBanner` e
`EndlessBanner` não recebem mais `onHammer`: a `HammerBar` é montada pelas telas,
numa faixa entre o card de métricas e o tabuleiro. Deixar o botão dentro da
moldura o fazia ler como uma quarta métrica — mais uma coisa a *saber*, quando é
a única coisa ali a *fazer*. O círculo é a forma que o resto do HUD não usa
(nenhuma métrica, pílula ou barra é redonda), então o olho o acha sem rótulo — e
sem rótulo é o que permite ser compacto. Há teste travando que o botão **não** é
descendente do `LevelBanner`: o dia em que alguém o devolver para dentro do card,
a suíte reclama.

**O `+` do estado zero é visual; o Modo Fantasma continua.** A diretriz pedia que
estoque zero abrisse o modal *em vez* de mirar, e isso contraria o funil que já
estava construído e testado: quem escolhe o alvo antes de descobrir que não tem
martelo assiste ao anúncio sabendo o que vai quebrar. Decisão do dono do produto,
tomada explicitamente: **fica o Modo Fantasma**. O badge mostra `+` em verde (e
não `0`, que anunciaria um botão inútil), o toque entra em mira, e o convite abre
com o alvo guardado.

**A faixa também é onde a dica de mira cabe.** O véu diz "o resto da tela está
fora"; ele não diz "toque numa célula". Sem a frase, o modo de mira mudava o
significado do toque no tabuleiro sem nada na tela dizer isso.

**O golpe sai no levantar do dedo.** `tapDown` acende o destaque, arrastar o move,
`tapUp`/`panEnd` golpeia a célula de baixo do dedo. Cobrar no encostar
transformaria todo escorregão em martelo perdido — e o item é pago. Dois testes:
com o dedo na tela nada foi destruído; arrastar para a vizinha mata a vizinha.

**O véu cobre o tabuleiro só depois de haver alvo.** Enquanto o dedo não desceu, o
recorte é o tabuleiro inteiro: é entre aqueles dígitos que o jogador está
escolhendo, e desfocar a grade na hora da escolha esconderia justamente a
informação que a decisão pede. Ao encostar o dedo o recorte encolhe para a célula
(1,1x, com aro neon pulsante e o fio vermelho de prévia) e o resto — tabuleiro
incluído — recua para trás do blur. É a leitura da diretriz 3 que não briga com o
motivo pelo qual o véu era recortado desde o início.

**O destaque é irmão do véu, não filho.** Dentro do `ClipPath` a prévia vermelha
seria recortada junto com o buraco — ela é desenhada exatamente sobre a célula que
o véu não cobre. O `ClipRect` externo é o da diretriz 6, e há teste procurando o
`BackdropFilter` **dentro** do `hammerScrimKey` e um `ClipRect` acima dele.

**Nada de `Opacity` nem `FadeTransition` na entrada do véu.** A transição de 150ms
anima alfa de cor e sigma do blur por `AnimationController`, pela mesma armadilha
já registrada nos obstáculos: a suíte usa esses dois tipos como marcadores de
outros efeitos.

**Toda animação nova é finita.** O aro pulsante dá duas batidas e descansa aceso
(`kHammerAimPulse`), e o tranco do `StrikeShake` dura 100ms e volta ao lugar. Uma
animação em repetição faria `pumpAndSettle` nunca terminar e derrubaria a suíte de
widget inteira — é a mesma razão pela qual o contador de movimentos pulsa uma vez
por jogada em vez de virar relógio. O teste do tranco confere que o tabuleiro
**volta** à posição de repouso depois do golpe.

**O tranco é do tabuleiro, não da tela.** `StrikeShake` embrulha o `Stack` do
tabuleiro *com* o `JuiceOverlay`: sacudir a tela levaria o HUD e o botão junto, e
quem quebrou foi uma peça. Um estilhaço parado sobre um tabuleiro que anda
denunciaria as duas camadas. O sinal é `hammerStrikes`, e não a posição — dois
golpes na mesma célula com o mesmo dígito não se distinguem por nada mais.

**Três avisos, três sons.** `strikeFeedback` (`heavyImpact`) entrou no `_strike`,
ao lado de `targetingFeedback` (`selectionClick` + clique de sistema) e
`rejectionFeedback` (alerta). Engajar a mira e errar a mira são o par que o
jogador mais precisa distinguir, então nenhum dos dois pode soar como o outro. O
golpe fica sem som próprio: **não há motor de áudio no projeto**, e o único som de
sistema sobrando é o de alerta, que significaria erro. É o ponto a trocar quando
houver SFX de verdade. Sendo injetável, o gancho novo teve de ser dublado nos
quatro arquivos de teste que já dublavam os outros dois — em teste puro, sem
binding, o canal de plataforma estoura.

**Rodada de red team sobre a UI do martelo — o que mudou e o que não.**

*Não mudou:* o relatório apontou "células apagadas com um traço atravessado" no
estado normal do tabuleiro como glitch de renderização, e pediu 100% de opacidade
fora da mira. É o `ObstacleOverlay` funcionando: o gelo pinta um véu azul
translúcido com uma **faixa clara diagonal**, e o vidro intacto pinta **uma
faceta diagonal** — exatamente "opacidade baixa e linha atravessada". A
translucidez é a razão de ser da cobertura (o dígito por baixo tem de continuar
legível, senão o obstáculo é só um buraco no tabuleiro). Chapar aquelas células
apagaria a mecânica dos obstáculos inteira. Se a leitura de "peça quebrada"
persistir com jogadores reais, o remédio é reforçar o contorno da cobertura, não
remover o alfa.

*Mudou — a dica de mira virou pílula* (`hammerAimHintKey`). Branco puro sobre
fundo escuro de aro vermelho, centralizada na faixa. O texto nasce no mesmo
instante em que o véu escurece tudo: cinza sobre preto desfocado era a coisa que
o jogador mais precisa ler e a que menos se destacava. A pílula lhe dá fundo
próprio, então a legibilidade deixa de depender do que passa atrás.

*Mudou — a mira sai de cena quando o convite de aquisição sobe.* A camada só é
montada com `pendingHammerTarget == null`. O recorte do véu deixava a célula
mirada sem desfoque e com o aro neon aceso **atrás** do modal, competindo com a
única decisão que o jogador tem ali: o botão do anúncio. Com a camada fora, sobra
o véu homogêneo do próprio modal, e o alvo continua guardado no estado — o Modo
Fantasma não perde nada. Teste em ambas as telas.

**As partículas da cor da peça já existiam** (`ShatterEffect` no `hammerStrike`),
e continuam sendo o que a diretriz 5 pede.


### Diretrizes de Produto, Monetização & Game Feel (NineFuse)

1. **Estratégia de Monetização & Anti-Churn:**
   - **Intersticiais:** NUNCA exibir intersticiais na tela de Game Over / Derrota. Cooldown mínimo de 45s entre exibições em momentos neutros de transição.
   - **Rewarded Ads (Pre-Churn):** Oferecer a opção de ad recompensado antes da derrota (ex: quando restar 1 ou 2 movimentos) ou no modal de falta de boosters.
   - **Estado Zero:** Se `hammerCount == 0`, o toque no booster abre diretamente o `NoHammersDialog` (Rewarded Ad / Store) sem entrar no modo de mira.

2. **Game Feel & Padrões Visuais ("Juice"):**
   - **Dark Mode / Neon:** Manter visual Cyberpunk com contraste limpo.
   - **Clímax do Dígito 9:** Ao atingir '9', obrigatoriamente disparar haptic de grande impacto, tremor de câmera suave (100ms) e efeito de partículas da cor do dígito antes de explodir os vizinhos.
   - **Feedback Tátil:** `HapticFeedback.selectionClick()` na seleção/mira e `HapticFeedback.heavyImpact()` em destruições/combos.

3. **ASO & Posicionamento:**
   - Categoria: **Puzzle / Quebra-cabeça**.
   - Subtítulo Padrão: *"Combine números, evolua até o 9 e libere ondas de choque incríveis!"*
#### Como estas diretrizes foram implementadas ✅

**O SDK do AdMob entrou; o áudio, não.** `google_mobile_ads` está no `pubspec`,
com os **IDs de teste oficiais do Google** em `core/ads/ad_ids.dart`, no
`AndroidManifest.xml` e no `Info.plist`. São quatro lugares, e trocar pelos de
produção é a última coisa antes de publicar — um esquecido não quebra o build, o
anúncio só não vem. Os IDs de teste são deliberados: um build de
desenvolvimento pedindo inventário real conta como tráfego inválido, e é o
caminho mais curto para a conta ser suspensa antes de o jogo chegar à loja.
O SFX de explosão da diretriz 2 **não foi feito**: continua não havendo motor de
áudio nem arquivo de som no projeto, e o gancho tátil é o que existe.

**O SDK fica atrás de uma porta, e a decisão fica fora dele.**
`RewardedAdPort`/`RewardedAdHandle` são duas interfaces de dois métodos; o
`RewardedAdService` é quem decide quando carregar, quando repor e o que fazer sem
estoque — e é testável em Dart puro, com rede de mentira. O `AdMobRewardedPort`
que fala com o `google_mobile_ads` é fino de propósito e **não tem teste**:
testá-lo exigiria binding nativo e mediria o SDK, não o jogo. Nove testes cobrem
a máquina de estoque, incluindo os dois que doem: o anúncio exibido é
**devolvido e sai do estoque** (guardá-lo daria um segundo prêmio de graça) e
**fechar antes do fim não paga** (pagar os dois casos transformaria o anúncio num
botão).

**O padrão dos providers segue pagando o jogador, e isso é o que mantém a suíte
de pé.** `hammerAdProvider` e `movesAdProvider` continuam devolvendo `true` sem
rede nenhuma; quem liga o AdMob é o `main`, por `admobOverrides()`. Fazer o
AdMob ser o padrão obrigaria toda a suíte de widget a ter canal de plataforma.

**O preload é a razão de o serviço existir.** Carregar no toque do botão põe a
rede no caminho crítico da decisão: o jogador veria segundos de espera entre
"quero" e "assisti". `preloadRewardedAds` roda no `initState` das duas telas.
`MobileAds.instance.initialize()` **não é esperado** no `main` — segurar o
`runApp` por ele trocaria a abertura do jogo por uma tela branca, e um anúncio
pedido antes de ele terminar apenas falha em carregar, caso que o serviço já
trata como "sem estoque".

**O gatilho pre-churn tem cinco guardas, e a quinta foi achada por teste
quebrado.** `shouldOfferMoves` exige fase em andamento, nada sendo encenado,
objetivo em aberto, convite ainda não gasto — e **pelo menos uma jogada feita**.
Sem a última, uma fase de `moveLimit: 1` abria o convite por cima do tabuleiro
antes do primeiro toque: seis testes de `game_screen_test` passaram a falhar
justamente aí, e o defeito era do código, não deles. "Pre-churn" tem de
significar que o jogador se meteu em apuros, não que a fase é curta de projeto.

**Quem marca a oferta como gasta é a tela, não a regra.** A regra sabe dizer que
a fase está apertada; só a UI sabe se o cartão chegou a subir. Marcar no
notifier, na jogada que cruza o limiar, gastaria a única oferta da fase mesmo que
o modal nunca abrisse. Daí `markMovesOfferShown()` ser chamado do `ref.listen`, e
daí `_movesOfferOpen` viver na tela: mostrar o convite torna `shouldOfferMoves`
falso no mesmo quadro, então um cartão ligado direto ao getter fecharia sozinho
no frame seguinte ao de abrir.

**O prêmio entra em `bonusMoves`, não descontando de `moves`** — mesma razão do
bônus do dígito máximo: `moves` é "quantas jogadas o jogador fez", e é isso que o
cartão de fim de fase relata. Fase encerrada recusa o crédito.

**A diretriz 1 pedia `NoHammersDialog`; ele não existe e continua não
existindo.** O modal é o `HammerOfferDialog`, e o "Estado Zero" segue sendo o
**Modo Fantasma** já decidido: estoque zero entra em mira, guarda o alvo e só
então abre o convite. É decisão de produto registrada duas seções acima, e o
SDK novo não a muda.

**O tranco do 9 reusa o `StrikeShake`, e o sinal precisou virar soma.** Golpe de
martelo e explosão são dois motivos para a mesma sacudida, e o widget só reage a
um serial que **cresce** — dois contadores separados se cancelariam. `shakeSerial
= hammerStrikes + explosions` nos dois estados. `explosions` é `int` e não
`bool` porque `apexCelebrated` já ocupa o papel de sinal de uma vez só: o aviso
de "FUSÃO MÁXIMA" é uma vez por partida, mas o tranco é de cada explosão. O
contador sobe **no quadro do clarão** (dentro de `_playResolution`), não em
`_finishMove`, pelo mesmo motivo da batida tátil — daí `extraExplosions`, que
segue a mesma convenção de `extraScore` para a resolução instantânea não contar
duas vezes.

**As partículas da onda de choque saem na cor de cada peça varrida, e isso pediu
um campo novo no domínio.** `ResolutionStep.clearedDigits` é `Map<Position,int>`
e guarda o dígito de **antes** do estouro, pelo mesmo motivo que `ObstacleHit`
guarda o tipo de antes do impacto: depois a célula está vazia e a UI não saberia
de que cor pintar. `clearedByExplosion` **continua existindo como `Set` e continua
sendo o raio da onda** — a primeira tentativa o derivou do mapa, e um teste do
motor pegou a regressão na hora: o raio são 9 células, mas só 7 tinham peça (a
fusão que criou o 9 já esvaziou duas). Os dois conceitos são distintos, e é o
raio que a pontuação do clímax remunera — medir pelo que havia de peça faria a
mesma explosão render menos perto de uma borda vazia, punindo quem montou o
dígito máximo no canto.

**Textos de loja moram no ARB** (`storeSubtitle`, `storeShortDescription`,
`storeFullDescription`, `storeKeywords`), em pt e en. Não são lidos por nenhuma
tela: ficam ali para a ficha da loja ter uma fonte da verdade versionada e
traduzida junto com o resto, em vez de viver num documento solto que diverge do
jogo na primeira mudança de mecânica.

**Armadilha achada rodando no aparelho: plugin novo pede reinstalação, não hot
restart.** Adicionar o `google_mobile_ads` com o app em execução e dar hot
restart recarrega só o Dart — o lado nativo do app instalado não tem o plugin
registrado, e tudo estoura com `MissingPluginException`. Isso expôs **dois bugs
reais**, que existiriam em qualquer falha de canal e não só nesta:
`RewardedAd.load` não era awaitada, então a exceção escapava como erro
assíncrono não tratado e o `Completer` **nunca completava** — `preload` ficava
pendurado, `_loading` não limpava e o serviço morria pelo resto da sessão; e
`MobileAds.initialize()` subia sem `catchError`. O jogo pode ficar sem anúncio;
o que ele não pode é abrir cuspindo pilha, nem se envenenar em definitivo por
causa de uma carga que falhou. Dois testes novos travam o contrato do serviço
contra uma porta que estoura.

**A versão do `google_mobile_ads` é PINADA em `9.0.0`, sem `^`, e isso não é
descuido.** A `9.1.0` declara `Google-Mobile-Ads-SDK '~> 13.7'` — faixa aberta —
e resolve para a 13.7.0, em que `GoogleMobileAds_Beta.h` passou a viver em
`PrivateHeaders/`. O plugin continua incluindo esse header como público, o Clang
recusa header não-modular dentro de módulo de framework, e **o build do iOS
quebra** em `FLTAd_Internal.h` e `FLTAdPreloader.h`. O Android compila normal, o
que torna a falha fácil de não ver. A `9.0.0` fixa `'~> 13.3.0'`, série de patch
fechada, e compila. `ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` **não
resolve** — foi tentado, chegou às três configurações do target e o erro
permaneceu; o remédio é a versão, não a flag. Ao subir o plugin um dia, rodar
`flutter build ios --debug --simulator` antes de confiar no `flutter analyze`.

**No iOS o plugin também exige `pod repo update`.** O spec repo local costuma
estar atrás, e o sintoma é `None of your spec sources contain a spec satisfying
the dependency`. O `Podfile` ganhou `platform :ios, '13.0'` explícito: sem a
linha o CocoaPods escolhe sozinho e avisa toda vez, e a versão escolhida pode
divergir do `IPHONEOS_DEPLOYMENT_TARGET` do Xcode — divergência que só aparece
na hora de linkar.

**Ainda não implementado, e é decisão explícita:** intersticiais (com o cooldown
de 45s e a proibição na derrota), o cap de 3 martelos/dia da regra 4, o No-Ads
Pass e o Bônus Diário VIP. O `RewardedAdService` é por unidade de anúncio
justamente para o cap caber depois sem reescrever o funil.


### Fase 15: Campanha Infinita (`LevelGenerator`) ✅ Concluída

**`levelAt` é função, não lista.** As dez fases artesanais continuam vindo de
`kCampaign`, mas a campanha não tem mais fim: guardar fase 11, 500, 10000 numa
lista significaria ou gerar tudo antecipadamente (memória sem teto, para um
jogo que não tem teto de progresso) ou paginar uma estrutura que só existe para
ser indexada por número — o que uma função já é de graça. `levelAt(n)` devolve
`kCampaign[n - 1]` para as dez primeiras e `generateLevel(n)` daí em diante, e é
a única porta: nada além dela lê `kCampaign` fora de `level_catalog.dart`.

**A seed determina o contrato da fase, não o tabuleiro.** `generateLevel(n)` é
aritmética pura sobre `n` — janela de spawn, obstáculos, objetivo e limite de
movimentos —, e nada nela sorteia uma peça. O tabuleiro continua saindo do
`MatchEngine`, a cada tentativa, do mesmo jeito que a Fase 13 decidiu: fixar o
grid faria repetir uma fase perdida virar decorar a solução em vez de jogar de
novo. Uma campanha infinita que gerasse (e persistisse) o tabuleiro pela seed
teria resolvido "infinita" trocando por "decorável" — o problema oposto ao que
a mecânica de fusão tenta resolver.

**A dificuldade não escala pelo dígito-alvo.** `kMaxDigit` é 9, e um gerador que
tentasse "fase 500 pede o dígito 500" não teria onde pôr o número: a partir do
terceiro bloco o dígito já satura no teto, e é aí que a variedade de
`_objectiveFor` (corpo do bloco em dígito, as duas antes do fecho em quebra de
cobertura, o fecho em limpeza total) assume o papel de continuar diferenciando
fases que já pedem o mesmo pico. Os eixos que seguem crescendo são `count`
(até `kMaxObjectiveCount`), o limite de movimentos (aperto de 2% por bloco) e a
quantidade de cobertura (até `kMaxObstacles`) — três eixos com teto próprio,
porque um jogo sem teto em lugar nenhum não tem onde a dificuldade parar de
crescer e começar a *repetir*, que é o que uma campanha longa precisa fazer.

**O degrau da janela de sorteio cicla a partir de 2, e nunca volta a 0 ou 1.**
`_spawnMinFor` sobe um degrau por bloco até a janela alcançar o dígito máximo
(`spawnMax` bate em `kMaxDigit`) e daí cicla entre os degraus de cima. Voltar
ao degrau em que o `0` cai seria regredir uma conquista que a Fase 7 já deu ao
jogador — a campanha longa tem de continuar difícil, nunca fingir que ele
regrediu.

**O denominador da barra de estrelas virou o capítulo, não o total da
campanha.** Uma campanha sem fim não tem "total de estrelas possíveis" para
dividir — o denominador só existe enquanto há um fim declarado. A legenda ao
lado do número dizia "CAMPANHA" enquanto o número já contava dentro do
capítulo ("6/18 CAMPANHA" ao lado de "Capítulo 1", dois escopos diferentes na
mesma linha); virou "CAPÍTULO" nos dois idiomas, e a semântica do leitor de
tela (`Semantics.label`) foi corrigida junto — não é só texto visível, é o que
o VoiceOver/TalkBack anuncia.

**O histórico de fases precisa de poda, e a poda quase virou farm de
moedas.** `CampaignRecords` guarda um registro por fase jogada; sem poda, uma
campanha infinita guarda um registro por fase **para sempre**, um vazamento de
memória e de disco que cresce com o tempo de jogo em vez de com o conteúdo do
jogo. A poda mantém só a soma de estrelas e descarta o detalhe das fases
antigas — e foi aí que o bug apareceu: `record()` calcula o ganho de uma
jogada como `merged.stars - existing.stars`, e é esse retorno que a economia
paga. Com o detalhe da fase podado, `existing` é nulo, e o ganho contra "nada"
é o total de novo — rejogar uma fase de capítulos atrás pagava as mesmas
estrelas outra vez, e a poda seguinte devolvia o histórico ao estado anterior,
fechando um ciclo infinito de moedas. A correção foi uma marca d'água,
`prunedBelow` (a maior fase já podada): fase igual ou abaixo dela rende
**zero**, não o total. Zero é a resposta certa ali porque o crédito daquela
fase já foi dado quando ela foi jogada a primeira vez, antes de ser podada —
sem o detalhe não há como calcular um ganho verdadeiro, e pagar o total de novo
é o pior dos dois erros possíveis (o outro seria não pagar uma fase nova, que
ao menos é visível e reclamável; pagar duas vezes é silencioso e se acumula). A
marca nunca regride quando uma leitura assíncrona do disco chega depois de o
saldo já ter mudado em memória — adotar um `prunedBelow` mais antigo reabriria
a mesma janela que acabou de ser fechada.

**Calibragem por `--mode=generated`, com a mesma disciplina das Fases 4 e 13:
nunca escolher limite de movimentos a olho.** Onze amostras cobrindo os **três**
arquétipos de objetivo em bloco baixo, médio e alto. `_targetOf`/`_gainOf`, já
usados pelo modo `efficiency`, foram reaproveitados em vez de reescritos, para o
novo modo medir exatamente a mesma coisa que os outros — e a conferência contra
`GameNotifier._gainedThisMove` confirmou que medem: dígito só conta se **nasceu
de fusão**, cobertura só conta se **quebrou**. Resultado, com o jogador guloso de
sempre, 200 partidas por linha:

| fase | objetivo         | janela | mov | vitórias |
|------|------------------|--------|-----|----------|
| 14   | Crie um 8        | 3-6    | 10  | 84%      |
| 22   | Crie 2 peças 9   | 4-7    | 10  | 40%      |
| 103  | Crie 6 peças 8   | 4-7    | 10  | 91%      |
| 253  | Crie 6 peças 7   | 3-6    | 10  | 88%      |
| 1003 | Crie 6 peças 6   | 2-5    | 10  | 88%      |
| 18   | Quebre 1 glass   | 3-6    | 12  | 66%      |
| 108  | Quebre 3 stone   | 4-7    | 29  | 45%      |
| 1008 | Quebre 3 stone   | 2-5    | 27  | 33%      |
| 20   | Limpe todo glass | 3-6    | 30  | 83%      |
| 100  | Limpe todo stone | 3-6    | 25  | 44%      |
| 1000 | Limpe todo stone | 5-8    | 22  | 56%      |

Tabela remedida (`--games=200`, mesma disciplina da tabela anterior) depois de
dois eventos: a correção do bug da onda de choque (abaixo) e a restauração do
teto da pedra para 3. A tabela publicada originalmente foi medida com o bug
**ativo** — o teto de pedra já estava em 2 como paliativo, mas o resto da
economia rodava sem o estouro creditar cobertura nenhuma. A linha que mais
muda é a 1000 ("limpe todo stone", janela 5-8, o pior caso do bug): saltou de
16% para 56% só com a correção do motor, e continua acima mesmo depois de o
teto voltar a 3 (mais uma pedra para quebrar). As fases "quebre N" também
mudam de enunciado (3 pedras em vez de 2, refletindo o teto restaurado) e
custam mais movimentos (`kObstacleMovesPerUnit` escala com a contagem pedida).
As linhas de dígito e de "limpe todo glass" ficam essencialmente onde estavam
— o bug e o teto da pedra não as tocam.

As de cobertura seguem abaixo da faixa, **e é esperado, não é defeito**: o
jogador automático é guloso por fusão e nunca mira a cobertura de propósito,
então o número que sai dali é um **piso**, a mesma leitura que a Fase 13 já
registrou. Um jogador de verdade, mirando a cobertura, bate acima disso.

**A amostra anterior era cega, e isso mascarou os dois defeitos abaixo.** As
sete fases medidas (11, 25, 50, 100, 250, 500, 1000) tinham cinco caindo na
posição 9 do bloco — o fecho "limpe tudo". Cinco das sete linhas mediam o mesmo
arquétipo, nenhuma media "quebre N coberturas", e as fases de dígito apareciam
só nos dois blocos mais baixos. Quem escolhe o arquétipo é a **posição dentro do
bloco**, não o número da fase; amostrar por "números redondos" amostra a posição
9 quase toda vez. A amostra nova é escolhida por posição.

**O aperto por bloco não tinha teto, e um percentual aplicado para sempre não
converge — cruza zero.** `1 - 0.02 * bloco` fica negativo por volta do bloco 50
(fase ~510): as fases 500 e 1000 saíam com **um** movimento e 0% de vitória. Uma
campanha infinita cujas fases distantes são matematicamente invencíveis é pior
do que a tela "Em Breve" que este trabalho veio eliminar. O aperto passou a ter
piso (`kTighteningFloor = 0.75`): ele **assintota** em um quarto a menos e nunca
colapsa. Um quarto porque, do bloco 12 em diante, a dificuldade já tem outros
eixos para crescer — a contagem do objetivo sobe até `kMaxObjectiveCount`, a
cobertura endurece até a pedra, e a janela cicla. O limite de movimentos é o
eixo que para; os outros continuam.

**Deformar a fórmula até a métrica ceder não é calibrar.** A entrega anterior
levou `reachDigit` de `15 * count` para `1.45 * count` e derrubou
`kMinMoveLimit` de 8 para **1**, e com isso a tabela "passou": "crie um 7" com
um movimento marcava 80%. O número era verdadeiro — e a fase, inexistente. Com
um movimento o primeiro tabuleiro decide tudo e o jogador não chega a jogar.
Repostos: `kDigitMovesPerPiece = 2.2` e `kMinMoveLimit = 10`, que é um piso de
**projeto** e não uma válvula aritmética (quem impede o zero agora é o teto do
aperto). Dez é a ordem das primeiras fases artesanais (6, 10, 10), as mais
curtas que o jogo já se permitiu.

**A medição estava certa, e foi preciso prová-lo antes de mexer em constante.**
"Crie um 7 em 1 movimento = 80%" parecia erro de régua. Não era: em 27 de 30
tabuleiros o guloso já forma o 7 na **primeira** troca. A causa é estrutural e
vale registrar, porque governa toda a calibragem das fases de dígito — o gerador
prende o alvo em `spawnMax + 1`, ou seja, sempre a **uma** fusão da janela, e a
janela tem só quatro dígitos distintos, então uma combinação do topo quase
sempre existe. É o oposto da campanha artesanal, em que a fase 8 pede um 7 sobre
uma janela 1-4 (três fusões acima) e gasta 45 movimentos para chegar a 90%. A
mesma frase de objetivo, dois jogos diferentes.

**O `+2` das posições ímpares é o arquétipo fora de faixa, e é dívida de
fórmula.** `digit = position.isOdd ? spawnMax + 2 : spawnMax + 1` faz o custo
saltar cerca de 5x, e nenhum multiplicador linear em `count` cobre os dois: as
fases `+1` saturam em 100% a partir de 12 movimentos, e as `+2` de contagem alta
precisam de 40+ para sair de 2%. A fase 22 na tabela é essa metade dura (40%, o
piso da regra); as fases `+2` de contagem 6 continuam abaixo dela. Consertar
isso é mexer na **fórmula do objetivo**, que esta task não podia tocar — fica
registrado como o próximo eixo a mexer, e não como calibragem pendente.

**As fases de dígito `+1` com contagem baixa são 100% em qualquer limite
jogável, e por isso não estão na amostra.** A fase 11 ("crie um 7", uma peça, uma
fusão acima da janela) marca 87% com um movimento e 100% a partir de três.
Nenhum limite defensável a tira de 100%. Ela é o degrau de entrada do bloco, o
análogo das fases 1 e 2 artesanais — que também marcam 100% na tabela da
campanha. Está fora da amostra porque uma linha em 100% não informa nada sobre
o limite; está registrada aqui porque fingir que não existe informaria menos.

**A calibragem achou um bug de regra que nenhum teste tinha pego: a onda de
choque do dígito máximo destruía cobertura sem creditar o objetivo.**
`Resolution.countCleared` conta `ObstacleHit`, e `ObstacleHit` só nascia de
`_damageObstacles`, o dano por fusão **adjacente**. O estouro do 9 varre a
célula coberta por inteiro (é o que a Fase 13 registrou como efeito colateral
desejado), mas não emitia hit nenhum: a pedra sumia da tela e o contador do
objetivo não andava. O sintoma foi a janela 5-8, onde toda fusão de topo vira um
9 e estoura — "limpe todas as pedras" com três pedras mediu **0%** de vitória em
qualquer limite de movimentos, inclusive 90. Como a fórmula do objetivo estava
fora de escopo desta task, o remédio imediato foi baixar o teto da pedra de 3
para 2 (`_obstaclesFor`), o que tirou a fase de 0% e a pôs em 16% — um paliativo
sobre uma constante, não o conserto.

**O conserto de verdade veio logo em seguida**, numa task própria:
`MatchEngine._detonate` passou a ler o `ObstacleType` de cada célula do raio
antes de esvaziá-la, e `_mergeObstacleHits` funde esse resultado com os
impactos que a fusão adjacente já tinha registrado no mesmo passo, sem
duplicar hit numa cobertura que as duas fontes tocaram. Remedido depois da
correção, o teto da pedra voltou a 3: a fase 1000 ("limpe todo stone", janela
5-8) passou a marcar 56% (ver tabela acima), contra 16% com o bug ativo. O teto
2 mede alguns pontos acima disso, e a diferença não paga a variedade perdida no
fecho de bloco — os dois números são piso, porque o bot nunca mira a cobertura. A lição fica registrada porque é o tipo de bug que teste
unitário não pega sozinho: cada teste de obstáculo olhava `_damageObstacles`
isolado, e cada teste de explosão olhava `clearedByExplosion`/`clearedDigits`,
nunca os dois num objetivo de cobertura ao mesmo tempo. Foi medir a economia de
verdade — vitória por limite de movimentos, na fase que o jogo entrega — que
expôs a lacuna.

**Ainda não implementado, e é uma dívida real, não uma decisão:** a "janela
deslizante" do mapa não desliza. `_visibleCount` é `progress + kLookahead`, um
prefixo que só cresce — na fase 500 o `build` monta 508 pins, todos os
anteriores incluídos. É consequência direta de `_currentIndex` depender de a
janela **começar** na fase 1 (`progress.clamp(0, _visibleCount(progress) - 1)`
soma sobre o mesmo início); fazer a janela deslizar de verdade exige mudar essa
conta para um início móvel, o que ficou fora do escopo desta task porque não é
um número de calibragem — é uma mudança de fórmula, e cada pin nunca renderizado
some da lista. Prefixo sem teto é aceitável hoje (centenas de pins ainda
renderizam); deixa de ser aceitável na casa dos milhares.

**Outra dívida registrada, fora da UI ainda:** `Wallet.claimChapterChest` paga
200 moedas por capítulo reclamado e guarda os capítulos já pagos num `Set`
persistido. Com capítulos infinitos isso é uma torneira sem fim (moeda por
capítulo, para sempre) sobre um `Set` que também não tem teto. Hoje o método
não está ligado a nenhuma tela — não é bug em produção —, mas precisa ganhar
um teto ou um valor decrescente por capítulo antes de a Fase B do baú (ainda
não construída) o conectar a um botão.


### Fluxo de ganho de moedas e UI explicativa ✅

**O vídeo que paga moeda tem provider e unidade próprios.** `coinAdProvider`
nasce ao lado de `hammerAdProvider`, com o mesmo padrão que **paga o jogador
sem rede nenhuma** — é o que mantém a suíte de widget rodando sem canal de
plataforma —, e `AdIds.coinsRewarded` é a terceira unidade. Reaproveitar a
unidade do martelo apontaria o mesmo ID hoje e impediria para sempre de saber
qual dos três funis paga, que é a única coisa que a separação compra. Entrou
também no `preloadRewardedAds`: o botão vive dentro de um modal aberto no meio
de uma decisão, e pedir a rede ali é exatamente a espera que o preload existe
para evitar.

**A caixa não fecha ao creditar.** O jogador veio comprar um martelo; mandá-lo
de volta ao tabuleiro com o saldo maior o obrigaria a mirar outra vez para
gastar. Como `walletProvider` é observado no `build`, o crédito reacende o botão
de compra no mesmo quadro — há teste para isso, montado com o saldo faltando
exatamente `kCoinsPerRewardedAd`. `creditCoins` já persiste, então o teste
afirma contra o **disco** (`InMemoryGameStorage.coins`), não contra o estado em
memória: era o saldo sobreviver à sessão que o pedido exigia.

**`kCoinsPerRewardedAd = 25` é um quarto do martelo, de propósito.** Quatro
vídeos compram o item que um vídeo já daria direto — o funil do martelo continua
sendo o caminho curto, e este é a torneira de quem prefere juntar. Alto demais
esvaziaria o funil principal; baixo demais faria o botão parecer enfeite.

**A lista de fontes de moeda não diz valores.** `kCoinsPerStar` e
`kChapterChestReward` vão ser recalibrados, e um número escrito na tela viraria
promessa desatualizada no primeiro ajuste. Ela fica no rodapé do convite, e não
numa tela de ajuda: é ali que o jogador descobre que o saldo não cobre o preço, e
é ali que a pergunta "como eu consigo mais?" nasce — respondê-la em outra tela é
responder tarde. O texto de saldo insuficiente passou a trazer **quanto** o
jogador tem: sem isso ele sabe que falta, mas não a distância, e é a distância
que decide entre assistir a um vídeo e desistir.

**O selo de moedas do cartão de vitória só aparece com estrela nova.** Ele lê
`starsGained * kCoinsPerStar`, a mesma conta que o `game_screen` credita — não um
campo novo atravessando a tela, que poderia divergir do que a carteira recebeu.
Rejogar fase dominada rende zero (regra que `CampaignRecords.record()` já
garantia), e um selo "+0 🪙" anunciaria que o jogo esqueceu de pagar.

**O convite passou a precisar de rolagem no teste.** Na tela do jogo ele sempre
viveu dentro do `SingleChildScrollView` do `_OutcomeOverlay`; `hammer_purchase_test`
o montava cru, e o cartão informativo o fez estourar a janela padrão. O teste
passou a reproduzir a montagem de produção em vez de encolher a UI. O golden
`level_outcome.png` foi regerado com a caixa 80pt mais alta, pelo mesmo motivo.

**Não validado em aparelho:** o ganho via anúncio de teste do AdMob roda pelo
`RewardedAdService` já existente, mas só foi exercitado com a porta dublada. O
caminho nativo continua sem teste, pela razão de sempre — testá-lo mediria o SDK.

### Ajustes de HUD, geometria e copywriting ✅

**O contador de estrelas do capítulo já estava certo, e agora tem teste.** O
pedido era `total = fases_do_capítulo * 3`, e é exatamente o que
`CampaignChapter.starTotal` calcula: `chapterOf(21)` devolve o capítulo 4,
fases 21-30, 30 estrelas, e o `CampaignHeader` divide
`records.starsInChapter(chapter)` por esse total. Nada foi corrigido porque não
havia divergência — o que faltava era a **invariante travada**
(`campaign_chapter_test`): a conta vale para os capítulos artesanais (6 e 4
fases) e para os gerados (`kBlockSize` fases), toda fase do bloco devolve o
mesmo capítulo, e o degrau seguinte é outro número. Sem o teste, a próxima
mudança em `chapterOf` mexeria no denominador da barra sem ninguém notar.

**A folga do martelo veio de cima, não é altura nova — e isso não é
economia de pixel.** O disco projeta brilho com `blurRadius` 14 para fora de
uma caixa que só reserva 5pt abaixo dele, então os 12pt de folga deixavam o
brilho encostar na primeira linha de células, onde ele lê como célula acesa. A
primeira tentativa somou 10pt à coluna e **quebrou a suíte do martelo na hora**:
o tabuleiro saiu da área visível da janela de teste e o toque na célula-alvo
não chegou a ninguém. O remédio foi mover a folga (padding de topo da faixa de
10 para 2, `SizedBox` de 12 para 22): a altura total é a mesma, o card de
métricas já separa a faixa visualmente por conta própria, e o tabuleiro não
desce. Vale nas duas telas, porque a faixa é a mesma.

**A Top Bar já estava dentro de área segura, e o teste é o que prova.** O
`AppBar` do `Scaffold` reserva o entalhe sozinho e o `body` das duas telas já
abre com `SafeArea` — não havia nada a envolver. `hud_layout_test` monta a fase
21 com `FakeViewPadding(top: 88)` e afirma as duas geometrias que o pedido
pede: o texto "Fase 21" nasce abaixo do entalhe, e o botão do martelo termina
acima do tabuleiro com folga maior que o raio do brilho. **Não há banner de
anúncio no projeto** (só recompensado, e ele é tela cheia), então "não
sobrepor o banner" não tinha o que medir — quando o banner entrar, é este
arquivo que ganha o caso.

**"Fim da corrida" virou "Sem Movimentos!".** Título e subtítulo do cartão de
fim de partida do Modo Recorde, nos dois idiomas: `endlessOverTitle` →
"Sem Movimentos!" / "Out of Moves!", `endlessOverMessage` → "Suas jogadas
acabaram. Deseja continuar?" / "You've run out of moves. Keep going?". "Nova
corrida" (o botão) continua dizendo corrida de propósito: ali a palavra nomeia
o modo, não o desfecho. Fica registrado o atrito: o Endless **não tem limite de
movimentos** — o que acaba ali são as trocas possíveis, não um saldo —, então o
texto novo descreve a causa com menos precisão que o antigo
("Não havia mais nenhuma troca possível"). Foi pedido explicitamente, e a
pergunta "Deseja continuar?" combina com os dois botões que o cartão já
oferece.

### AppIcon: peça 3D com o `9`, e o encolhimento duplo do adaptativo ✅

**O ícone anterior era um anel de energia com o dígito no meio; agora é uma
peça do próprio jogo.** Um quebra-cabeça de números tem um objeto óbvio para
pôr no ícone — o bloco que o jogador toca —, e o anel virou arco de energia por
trás dele. O que não mudou foi o problema: **o glifo do `9` já falhou duas
vezes seguidas, de dois jeitos diferentes**, e as duas vezes o defeito só
apareceu renderizado.

- A primeira versão tinha a perna varrendo para a **esquerda** por baixo da
  barriga: a cauda de um `g` cursivo.
- A segunda parou a haste em `y=312` com a barriga descendo até `320` — sem
  descendente nenhum, lia como um **`a` minúsculo**. Pior que a primeira, porque
  `a` não é sequer um dígito.

A régua que ficou, e que vale para a próxima tentativa: **barriga compacta,
haste reta descendo pela borda direita, e descendente longo o bastante para a
barriga não passar de ~60% da altura**. Hoje: barriga r=56 em (256,216),
contra-forma r=23, haste de 40 de largura em x 272..312 até y=352 — caixa em
(256,256), barriga em 58%. Bowl grande com descendente curto lê `q`; descendente
flexionado para a esquerda no pé lê `g`; haste que não passa da barriga lê `a`.
Três becos sem saída já mapeados.

**O glifo é definido uma vez e reusado três vezes.** As três camadas (aura
ciano, entalhe deslocado, forma branca nítida) usavam o mesmo path **copiado**,
e foi assim que o defeito do `a` passou: corrigir o dígito exigia editar três
lugares idênticos, e bastava esquecer um para as camadas desalinharem. Virou
`<g id="nine">` em `defs` com três `<use>`. A forma branca é a última e é a
única **sem desfoque** — é ela que o olho usa para ler o dígito.

**Barriga e haste continuam sendo dois `<path>` irmãos.** Fundidos num só com
`fill-rule="evenodd"`, a área em que a haste encosta na barriga viraria buraco.

**A frente do ícone adaptativo sai sem o fundo, e isso exigiu um grupo no
SVG.** Tudo menos o retângulo de fundo vive dentro de `<g id="mark">`, e o
`prepare_icons` deriva a frente recortando esse grupo. Encolher o logo inteiro
— com o fundo escuro arredondado junto — é o que produzia a marca minúscula
numa ilha preta dentro da máscara; o escuro tem de vir do
`adaptive_icon_background`, não da arte. A derivação é feita pela ferramenta, e
**não** à mão num segundo SVG: dois arquivos divergiriam no primeiro ajuste.
`rsvg-convert -i mark` faria isso numa linha e **não serve** — esta versão do
librsvg recorta pela bounding box do elemento, deforma a proporção e perde o
arco de energia. Foi tentado, e está registrado no cabeçalho da ferramenta para
não ser tentado de novo.

**O encolhimento duplo tinha uma segunda metade, do lado da ferramenta.**
`_insetForAdaptive` escalava o **canvas inteiro** para 66%, então a margem
transparente que a arte já tinha encolhia junto: 66% de uma arte que ocupava
55% do quadro dá 36% da máscara. Agora ele **recorta pela caixa do conteúdo
antes de escalar** — o que tem de medir 66% é o desenho, não o quadro em volta.

**E a escala é medida pelo raio, não pelo lado da caixa.** A máscara é redonda:
arte que preenche um quadrado de 66% tem os cantos fora do círculo de 66%, e o
recorte os come. Ajustar pelo lado deixou as duas pontas do arco decepadas —
visível no render, invisível na aritmética. Como a arte é aproximadamente
circular, ajustar pelo raio cabe inteira e ainda preenche mais.

**O `rsvg-convert` foi absorvido pela ferramenta.** O pipeline caiu de três
comandos para dois, e `logo.png` deixou de ser um passo manual: ele sai do mesmo
render que alimenta os mestres, então não tem como ficar velho em relação ao
SVG. A ferramenta agora **exige** o `rsvg-convert` no PATH (`brew install
librsvg`) e falha explicitamente sem ele.

```bash
dart run tool/prepare_icons.dart   # SVG -> logo.png, mestres e fichas de loja
dart run flutter_launcher_icons    # mestres -> Android, iOS e web
```

**A configuração de ícone estava duplicada, e a cópia morta era a errada.**
`flutter_launcher_icons.yaml` é o arquivo padrão do pacote e vence sobre o bloco
do `pubspec` quando os dois existem (`main.dart:23`,
`Config.loadConfigFromPath(defaultConfigFile)` antes do fallback). O bloco do
`pubspec` apontava `adaptive_icon_foreground` para o logo inteiro, com o fundo
dentro — exatamente o defeito acima. Não estava em vigor, mas configuração morta
e **contraditória** é pior do que configuração ausente: quem a lesse debugaria o
sintoma no arquivo errado. Foi removida, com um comentário apontando para o
arquivo que manda.

**A cor de fundo é escolhida, não detectada.** `_dominantOpaqueColor` sugere
`#080818` (a cor mais frequente do campo), mas a configuração usa `#090514` — o
*stop* externo do gradiente, que é o que encosta na borda do ícone. São o mesmo
quase-preto; a diferença importa no dia em que o gradiente mudar, e por isso o
`flutter_launcher_icons.yaml` registra que esse valor tem de acompanhar o stop.

**A verificação é visual e é obrigatória — "regerei os ícones" não é
verificação.** Os três pontos, conferidos nesta rodada: o glifo lê como `9`; sob
a máscara circular de 66% nada é decepado, arco incluído, e a peça preenche o
círculo; e o ícone se separa tanto sobre fundo claro quanto escuro. O 1024 do
iOS sai **RGB sem canal alfa** (`color_type=2`), senão a App Store recusa o
envio.

**Não há teste automatizado, e é decisão.** `logo.svg` não é renderizado em
lugar nenhum do app — nenhum widget em `lib/` o carrega —, e ele é
exclusivamente a origem do ícone. Nenhum golden depende dele, e um teste de
imagem de ícone mediria o `rsvg-convert`, não o jogo. A verificação é o render
sob máscara, feita à mão a cada mudança de arte.


### Badge global de moedas e martelos (`CoinsHeaderBadge`) ✅

**O saldo só existia dentro do convite do martelo, e isso é tarde demais.** O
jogador descobria quanto tinha no instante em que precisava gastar — a moeda
nunca chegava a influenciar uma decisão anterior à compra. Um recurso que não é
visível não é recurso: é surpresa. A pílula agora vive na `AppBar` do mapa, do
Modo Recorde e da fase, e no topo do cartão de início — os quatro lugares em que
o jogador ainda pode decidir algo com o número na mão.

**Saldo zero aparece, e não some.** Uma pílula que se esconde no zero apaga
justamente o estado em que o `+` importa, e ensina que a moeda é um detalhe
intermitente.

**O martelo é opcional na pílula, e fica fora das telas de partida.** Dentro de
uma fase a autoridade do estoque é o `GameState`, relido a cada `startLevel`; o
campo `Wallet.hammers` é o espelho que existe para as telas de **fora** de uma
partida, onde não há `GameState` de onde ler. Mostrar o espelho durante a fase
poria dois números do mesmo item na mesma tela — o do header e o da `HammerBar`,
que é o certo — e eles divergiriam no primeiro golpe. Por isso só o mapa passa
`hammers:`.

**A loja é `showDialog`, contra a regra do resto do jogo, e é deliberado.** Todas
as outras caixas são camadas do `Stack` da própria tela, porque ali havia um
tabuleiro a não tirar da árvore de foco. Aqui o ponto de entrada nasce na
`AppBar` de quatro telas: pedir a cada uma que hospede a camada e guarde o
estado de aberto/fechado espalharia a mesma máquina por todas elas, para uma
caixa puramente informativa aberta com o jogo parado.

**A caixa não fecha ao creditar**, pela mesma razão já registrada no convite do
martelo: quem veio buscar moeda costuma querer mais de uma. Como o saldo é
observado com `walletProvider.select`, o crédito aparece no mesmo quadro — é o
que faz o botão parecer ter funcionado.

**A lista de fontes de moeda saiu para arquivo próprio** (`CoinSourcesCard`, em
`coin_sources_card.dart`), com `export` de volta pelo `hammer_offer_dialog` para
`coinSourcesKey` continuar endereçável de onde já era importada. Duas cópias
divergiriam na primeira torneira nova, e o jogador leria fontes diferentes
dependendo de qual caixa abriu. Ela segue **sem valores escritos**, pelo motivo
de sempre: `kCoinsPerStar` e `kChapterChestReward` vão ser recalibrados.

**A loja não vende pacote por dinheiro real, e isso não é lacuna de UI.** Não há
compra in-app no projeto; o que a caixa entrega hoje é a resposta à pergunta que
o `+` provoca, e o vídeo premiado (`coinAdProvider`, mesma unidade do funil de
moedas já existente) é a única torneira acionável dali. É o ponto a trocar
quando houver billing.

**Armadilhas desta rodada:**
- **O golden do mapa muda quando a `AppBar` ganha conteúdo.** `saga_map.png` foi
  regerado; um badge no header é mudança de pixel, não só de árvore.
- **Widget que lê provider quebra teste que monta o widget cru.**
  `english_screens_test` montava `LevelStartDialog` sem `ProviderScope` e passou
  a estourar `Bad state: No ProviderScope found`. O escopo entrou no teste **sem
  overrides** — em produção a tela sempre nasce sob um, e o padrão da carteira é
  saldo zero. Envolver o helper `localizedApp` num escopo teria sido o remédio
  errado: os testes que já montam o próprio `ProviderScope` com overrides
  ganhariam um escopo aninhado que os sombreia.

**Não validado em aparelho:** o crédito por vídeo continua exercitado só com a
porta dublada, pela razão de sempre — o caminho nativo mediria o SDK.


### Polimento visual do HUD da fase: cards 3D e dock de boosters ✅

**O aro dos cards é um degradê, e por isso é uma caixa por fora e não um
`Border.all`.** `BoxBorder` só aceita cor chapada; o contorno claro em cima
descendo para escuro embaixo é o que faz o cartão parecer iluminado de cima,
como as peças do tabuleiro. Um contorno de cor única lê como contorno de
formulário. A sombra da base é o outro meio da mesma frase: ela dá ao cartão um
lado de baixo, em vez de deixá-lo colado no fundo.

**MOVES sai do empate visual, e o critério não é estético.** Três caixas do
mesmo tamanho e do mesmo peso dizem que as três informações valem o mesmo — e
não valem: pontos são placar, objetivo é consulta, e o saldo de movimentos é o
relógio que **decide** a fase. `GameMetricCard.hero` dá a ele aro dourado/laranja,
fundo quente e número em 30, legível de canto de olho entre uma jogada e outra.

**O alvo ganhou vitrine porque estava lido como enfeite do número.** Solto ao
lado do contador, com o mesmo peso do resto da pílula, a peça que a fase inteira
pede parecia decoração do "1 de 3". A caixinha com fundo da própria cor e
contorno neon diz "isto aqui é o objeto" — e usa a cor que a peça tem no
tabuleiro, para o reconhecimento ser imediato quando ela aparecer na grade.

**As estrelas entraram no card de pontos, e ganharam trilho.** Nota parcial e
pontos respondem à mesma pergunta ("como estou indo?"), e a linha separada
abaixo do cabeçalho obrigava o olho a juntar duas coisas que o jogo já tratava
como uma. O preenchimento proporcional existe porque três ícones sozinhos são um
**estado**, não um progresso: a estrela apagada diz que ela se perdeu, e a barra
atrás delas diz quanto do caminho ainda está de pé. A estrela acesa perdeu a
sombra dourada — sobre o trilho preenchido, halo dourado em fundo dourado borra
a silhueta em vez de destacá-la.

**O disco roxo flutuante virou slot de um dock, e o problema nunca foi a cor.**
Um controle sem chão não pertence a lugar nenhum da interface, então o olho o
lia como sobreposição do sistema — algo que caiu por cima do jogo. Na prateleira
ele é equipamento do jogador; ganhou o formato das peças (quadrado arredondado
do tamanho de uma célula), o halo encolheu (dentro do dock ele já tem contraste,
e o brilho de antes só sangraria para fora da barra) e o respingo passou a ser
recortado no mesmo raio. O ganho estrutural é o que importa: **o segundo booster
entra ao lado sem redesenhar nada.** O rótulo discreto "BOOSTERS" existe porque
um dock com um item só e nenhuma legenda volta a ser lido como botão avulso com
moldura — e ele sai de cena quando a mira começa e a dica assume o espaço.

**O dock continua fora do card de métricas, pela regra de sempre:** o card
informa, o dock age. E continua sumindo com a fase encerrada.

**Armadilhas desta rodada:**
- **`find.byType(Container)` com `single` quebra na primeira camada nova.** A
  pílula passou a ser duas caixas encaixadas (a de fora desenha aro e base, a de
  dentro o fundo) e `game_metric_card_test` estourou com "Too many elements".
  Passou a pedir `widgetList(...).first`, que é o que a asserção sempre quis
  dizer.
- **O teste do alerta media `border.top.color`, que não existe mais.** Segue
  medindo a mesma coisa — a cor com que o aro começa —, agora no primeiro stop
  do degrau. Trocar a asserção foi acompanhar uma mudança deliberada de
  desenho, não afrouxar o teste: a contagem de sombras (o neon só na urgência)
  ficou intacta.
- **Os dois goldens do HUD foram regerados** (`game_hud`, `game_hud_urgent`).
  Nenhum outro golden mudou, o que confirma que o polimento ficou contido no
  cabeçalho e no dock.


### Dynamic Extra Moves (DEM) ✅

**O prêmio do anúncio deixou de ser fixo porque um número fixo estava errado
nas duas pontas.** +5 numa fase a um alvo do fim é esmola confortável; +5 numa
fase de "limpe todas as pedras" com três coberturas de pé não compra a vitória —
o jogador assiste ao anúncio, perde mesmo assim, e aprende a não assistir ao
próximo. `GameBalanceEngine.calculateRewardedMoves` escala a
`kMovesPerTarget = 3.0` por alvo restante, entre `kRewardedMinMoves = 4` e
`kRewardedMaxMoves = 10`.

**`totalInitialTargets` foi removido da assinatura pedida no spec.** O corpo
nunca o lia. Parâmetro exigido e ignorado é mentira de contrato: o próximo
leitor suporia que a proporção "restante sobre total" pesa no cálculo. Se um
dia pesar, ele volta junto com a fórmula que o usa.

**`GameState.rewardedMoves` existe porque o cartão anuncia o número antes de o
anúncio rodar.** UI e crédito lendo lugares diferentes divergiriam no primeiro
refactor, e a divergência apareceria como o jogo prometendo dez movimentos e
pagando quatro. Um getter, dois consumidores. `grantBonusMoves()` lê o mesmo
getter — sem parâmetro, porque nenhum chamador precisava fixar um valor à
parte da calibragem vigente, e um parâmetro que ninguém usa é contrato
mentindo sobre o que o método aceita.

**`remainingTargets` é `objectiveTarget - objectiveProgress`, sem caso
especial.** Os três `ObjectiveType` já significam a mesma coisa nessa conta:
peças de dígito a formar, coberturas a quebrar, coberturas restantes na limpeza
total.

**Um alvo restante paga o piso (4), e não 3.** `3.0 * 1` fica abaixo do piso, ou
seja o multiplicador só manda de dois alvos em diante. É consequência dos
números calibrados, não descuido — há teste travando o degrau para que trocá-lo
seja decisão.

**O número não é congelado quando o cartão sobe, e isso hoje não morde por
sorte, não por desenho.** `rewardedMoves` é recalculado a cada leitura — a UI
lê o getter para desenhar o cartão, o crédito lê o mesmo getter para pagar —, e
nada impede as duas leituras de caírem em momentos diferentes. O que hoje
garante que elas sempre concordam é uma combinação de dois fatos que não têm
relação nenhuma com o DEM em si: enquanto o convite está aberto o
`_OutcomeOverlay` é um `Positioned.fill(ColoredBox(...))` que barra o hit-test
da tela inteira, então nenhuma troca, cascata ou golpe de martelo consegue
correr por baixo dele; e `objectiveProgress` — o único insumo que
`rewardedMoves` lê da fase — só muda dentro de `_finishMove`, o mesmo
`copyWith` que zera `isResolving`, condição que o próprio convite exige para
abrir. Ou seja: o convite só fica no ar quando nada mais pode mexer no
objetivo, e é essa coincidência de guardas alheias ao DEM que mantém anunciado
e pago iguais — não uma trava do próprio recurso. Qualquer mudança futura que
abra uma fresta — uma cascata automática correndo com o modal aberto, um
martelo utilizável por cima dele, um overlay que deixe de ser opaco ao toque —
faz o prêmio prometido divergir do prêmio pago **em silêncio**, e nenhum teste
hoje pegaria essa divergência, porque nenhum teste hoje consegue produzir o
cenário que a quebraria. Se esse dia chegar, o remédio é parar de reler o
getter no crédito: snapshotar `rewardedMoves` no instante em que o convite
abre, num campo de estado ao lado de `movesOfferShown`, e creditar o valor
guardado — não o recalculado.

**Isto é mudança de economia, não refactor.** O pior caso ficou **menos**
generoso que o +5 de antes (fase a um alvo do fim: 4). As fases de cobertura com
três unidades de pé saltaram para 9-10. Se a conversão do funil de movimentos
mudar, a causa está aqui. `kPreChurnReward` foi removido para não deixar um 5
morto competindo com o piso de 4; `kPreChurnMovesLeft` (o limiar que **abre** o
convite) não foi tocado — é ortogonal ao tamanho do prêmio.

**Nada do funil de anúncio mudou, e é o que atende a política do AdMob:**
opt-in por clique (`_watch` no `onPressed`), uma vez por tentativa
(`movesOfferShown`), crédito só quando o `Future<bool>` volta `true`, IDs de
teste em `core/ads/ad_ids.dart`. Continuam fora de escopo, por decisão: pagar
os movimentos com moedas e reabrir o cartão com o botão de anúncio desativado
numa segunda derrota.


### Balanceamento de fases geradas: fórmula de movimentos, anti-repetição e pacing ✅

**A fórmula de dígito trocou de multiplicador fixo para distância até a
janela, exatamente como pedido.** `_digitMoves` agora é
`count * (digit - averageBoardTileLevel) + 8`, com `averageBoardTileLevel` lido
como o centro da própria janela de sorteio da fase (`(spawnMin + spawnMax) /
2`) — a mesma régua que toda a dificuldade da campanha gerada já usa (ver
"invariância da janela de spawn" em `game_level.dart`: o jogo nunca olha o
valor absoluto de uma peça, só a distância dela até o que cai do topo).
`kDigitMovesPerPiece` (o multiplicador fixo de 2,2) foi removido — ele não
sobrevive à troca de fórmula, e uma constante morta ao lado da nova só
confundiria quem lesse o arquivo depois.

**O piso de 16 movimentos é condicional, e o de 10 continua sendo o piso
geral.** `kHeavyDigitMoveFloor = 16` só entra quando o objetivo é
`reachDigit`, `count > 2` **e** `digit >= 7` (`kHeavyDigitCountThreshold`,
`kHeavyDigitThreshold`) — a leitura de "mais de 2 alvos de nível 7+" do pedido
original. Fora dessa combinação, `kMinMoveLimit` (10) continua valendo, pelo
mesmo motivo já registrado na Fase 15: abaixo disso a fase deixa de ser um
plano e vira sorteio do primeiro tabuleiro.

**O histórico de objetivos não é uma lista com poda de 10 posições — é um
cache indexado por número de fase, e a comparação em si olha só N-1 e N-2,
como o pedido pediu.** `generateLevel` é, por decisão da Fase 15, uma função
pura de `number`: não recebe (nem guarda) estado de fases jogadas. Um
histórico literal — uma lista mutável dos últimos 10 objetivos — quebraria essa
pureza e faria o resultado depender da **ordem** das chamadas, não só do
número da fase; `generateLevel(500)` chamado antes ou depois de
`generateLevel(499)` teria de devolver o mesmo objetivo, e uma lista de
histórico populada por efeito colateral não garante isso. `_objectiveCache`
resolve o mesmo problema sem abrir mão da pureza: guarda o objetivo **final**
de cada fase já computada, indexado por número (não por posição relativa), e
`_finalObjectiveFor` o preenche recursivamente conforme é consultado — o
"histórico de 10" do pedido não existe como estrutura porque a regra em si só
precisa de duas leituras (N-1 e N-2), e um cache completo custa o mesmo que um
cache podado, sem o risco de podar justo a fase que a próxima comparação
precisava.

**A primeira colisão muda o valor do alvo; a segunda muda a natureza do
objetivo — nessa ordem, e não por acaso.** Uma cadeia de três fases seguidas
com a mesma contagem (comum nos blocos avançados, onde `count` já satura em
`kMaxObjectiveCount`) só tem dois dígitos possíveis por posição
(`spawnMax+1`/`spawnMax+2`), e a terceira da cadeia colide com as **duas**
anteriores ao mesmo tempo. A primeira tentativa de correção resolve isso
empilhando dígito (`digit + 1`) — é o eixo que o pedido cita primeiro
("mudar o valor do número alvo") e o que o jogador mais nota —, mas continuar
empilhando dígito para escapar da segunda colisão **cria a fase impossível que
o objetivo 1 deste mesmo pedido pede para evitar**: a calibragem
(`--mode=generated`) mediu "crie 6 peças 9" numa janela 3-6 em **0% de
vitória**, mesmo com o piso de 16 já valendo — o dígito máximo com contagem
alta é caro demais para qualquer piso de movimentos linear cobrir. A partir da
segunda colisão a fase muda de tipo em vez de dígito: vira
`Objective.clearObstacles` sobre a cobertura mais dura que o bloco já
espalha, com seu próprio limite calibrado (`kObstacleMovesPerUnit`) — a leitura
de "quebrar bloqueios" que o próprio pedido oferece como alternativa. Depois
da correção, a mesma fase virou "quebre 2 stone" a 50% (piso normal de fase de
cobertura, pelo motivo de sempre: o bot guloso nunca mira a cobertura de
propósito).

**Não existe objetivo de "pontuação acumulada" — a terceira alternativa do
pedido —, e criar um só para este ajuste não foi feito.** `ObjectiveType` tem
três valores (`reachDigit`, `clearObstacles`, `clearAllObstacles`), nenhum
deles pontuação; adicionar um quarto tipo só para a fuga de repetição
tocaria em `GameState.objectiveTarget`, no HUD do objetivo e em todo teste que
enumera `ObjectiveType` — mudança de escopo bem maior que "ajustar
balanceamento". A troca de tipo usa `clearObstacles`, que já existe e já é
compatível com qualquer bloco (todo bloco gerado espalha ao menos gelo).

**A curva de pacing é cosseno, não seno — e é a mesma família de curva.**
`sin(n·π)` é zero para todo `n` inteiro (fase é sempre um número inteiro), o
que apagaria o efeito por completo; `cos(n·π)` vale `+1` para `n` par e `-1`
para `n` ímpar, dando exatamente a alternância pedida — fase difícil sempre
seguida da relaxante — porque o sinal inverte a cada fase consecutiva. Cosseno
é seno deslocado de π/2: continua sendo uma curva senoidal, só a fase certa
para não colapsar em zero num domínio de inteiros. `kPacingAmplitude = 0.12`
entra **depois** do aperto por bloco (`kTighteningPerBlock`/`kTighteningFloor`)
e multiplica o resultado já apertado: o aperto por bloco decide a tendência de
longo prazo, o pacing decide qual das duas fases vizinhas é a mais folgada.

**A calibragem foi remedida com `--mode=generated`, e as duas linhas que
antes zeravam continuam de pé, só que em outro formato.** As fases 253 e 1003
(as amostras de contagem alta que o pedido pretendia proteger) deixaram de ser
"crie 6 peças 9"/"crie 6 peças 8" e viraram "quebre 2 stone" pela troca de
natureza acima — 50% e 47%, dentro do piso já documentado das fases de
cobertura. As demais linhas da tabela não mudaram de arquétipo, só de número,
puxadas pela nova fórmula de dígito: nenhuma ficou abaixo do que a Fase 15 já
considerava aceitável, e a suíte inteira (721 testes) segue verde.

**Testado com invariante de faixa, não com números fixos.** Os três testes
novos em `level_generator_test.dart` cobrem 11 a 1000 fases inteiras: nenhuma
repete tipo/dígito/cobertura/contagem da fase anterior ou da retrasada (com uma
exceção documentada — os dois eixos de um objetivo de dígito no teto ao mesmo
tempo, caso em que não sobra para onde variar), nenhuma fase pesada de dígito
7+ com mais de duas peças fica abaixo de 16 movimentos, e o limite nunca chega
a zero ou negativo em toda a faixa.
