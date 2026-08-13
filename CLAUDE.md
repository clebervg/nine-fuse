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
3. **Pre-Churn Trigger:** Oferecer +5 movimentos via Rewarded Ad quando `movesLeft == 2` e a vitória não estiver garantida.
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
