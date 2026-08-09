# CLAUDE.md - Contexto & Regras do Projeto (NineFuse)

## Visão Geral do Projeto
Jogo de quebra-cabeça estilo Match-3 Lógico (inspirado em Candy Crush + 2048) utilizando números de 0 a 9.
- **Nome do App:** NineFuse
- **Linguagem/Framework:** Dart / Flutter
- **Gerenciamento de Estado:** Riverpod (`flutter_riverpod`)
- **Foco de UX:** Sem trava de vidas, gameplay contínuo, animações fluídas de fusão e visual minimalista/clean (Dark Mode por padrão).

## Core Gameplay & Diferenciais
1. **Mecânica de Fusão (Evolução dos Números):** 
   - Ao alinhar 3 ou mais números iguais (ex: três blocos `4`), eles não apenas somem.
   - O bloco central da combinação **evolui para o próximo número** (ex: vira um `5` energizado), e os outros blocos somem liberando espaço para a queda do topo.
   - Alcançar o número `9` cria uma explosão especial na área ou elimina a linha/coluna.
2. **Sem Vidas / Instant Restart:** 
   - Foco em partidas rápidas baseadas em High Score. Sem tempo de espera por vidas para jogar novamente.

## Diretrizes de Arquitetura & Código

### Estrutura de Pastas
Organize a pasta `lib/` da seguinte forma:
- `lib/core/` -> Temas, constantes (paleta de cores dos dígitos) e utilitários.
- `lib/features/game/domain/` -> Modelos de dados (`Tile`, `Board`, `Position`, `MatchResult`).
- `lib/features/game/presentation/` -> Telas, componentes do Grid, animações de fusão e score.
- `lib/features/game/providers/` -> Notifiers do Riverpod e lógica de estado do tabuleiro/jogo.

### Padrões de Desenvolvimento
- Use **immutability** para o estado do tabuleiro (`Tile` e `Board` imutáveis).
- Prefira `ConsumerWidget` ou `ConsumerStatefulWidget` para consumir o Riverpod.
- Mantenha a lógica do algoritmo do Match-3 e da Fusão estritamente na camada de `domain` e `providers`.
- Mantenha o código limpo, testável e comentado nas etapas de detecção de combinações e gravidade (queda dos blocos).

## Regras de Execução & Comandos Úteis

- **Rodar o projeto:** `flutter run`
- **Análise estática:** `flutter analyze`
- **Executar testes:** `flutter test`
- **Limpar build:** `flutter clean && flutter pub get`

## Mapeamento Inicial dos Números & Cores
Cada dígito possui uma cor vibrante e bem definida em `lib/core/constants/app_colors.dart`:
- `0`: Vermelho vibrante (`0xFFE53935`)
- `1`: Azul neon (`0xFF1E88E5`)
- `2`: Verde lima (`0xFF43A047`)
- `3`: Amarelo/Dourado (`0xFFFDD835`)
- `4`: Laranja (`0xFFFB8C00`)
- `5`: Roxo (`0xFF8E24AA`)
- `6`: Rosa neon (`0xFFFF3DA5`) — substituiu o rosa choque `0xFFD81B60`, que
  ficava a ΔE 32 do vermelho do `0` e se confundia com ele em aparelho. O novo
  tom sobe para ΔE 57 do `0` sem invadir o roxo do `5` (ΔE 47). Ver "O rosa que
  virava vermelho".
- `7`: Ciano (`0xFF00ACC1`)
- `8`: Violeta/Índigo (`0xFF3949AB`)
- `9`: Dourado místico — degradê `0xFFFFD700` → `0xFFFF8C00`, com brilho neon
  dourado (`AppColors.apexGlow`) em qualquer lugar em que a peça for desenhada.
  Substituiu o branco/prata: chapado e branco, a peça mais rara do jogo era a
  que mais se apagava no fundo escuro, e o número branco sobre ela dava 1,15:1
  de contraste, o pior da paleta. Ver "A peça ápice".

## Roadmap de Desenvolvimento

### Fase 1: Arquitetura & Lógica Base (MVP) ✅ Completa
**Objetivo:** Implementar a estrutura core, modelos de dados e lógica do jogo.

**Tarefas:**
- ✅ Setup de pasta e estrutura (lib/core, lib/features/game/*)
- ✅ `app_colors.dart` - Paleta de cores dos 10 dígitos
- ✅ Models imutáveis: `Position`, `Tile`, `Board`
- ✅ `GameState` e `GameNotifier` - Estado e lógica do jogo
- ✅ Algoritmos: detecção de matches, gravidade, evolução de tiles
- ✅ 15 testes unitários - 100% passando

**Saída:** Lógica pura 100% testável, sem dependências de UI.

---

### Fase 2: Presentation & UI (Grid & Interação) ✅ Completa
**Objetivo:** Criar interface visual do jogo com tabuleiro interativo.

**Tarefas:**
- ✅ Componente `TileWidget` - Renderiza bloco com AnimatedContainer, cores dinâmicas, feedback de seleção
- ✅ Componente `BoardGridWidget` - Grid 8x8 responsivo com layout adaptativo
- ✅ Componente `GameScreen` - Tela principal
  - ✅ Display de score em tempo real (via Riverpod)
  - ✅ Board integrado com tap handling
  - ✅ Status indicator (game over, movimentos)
  - ✅ Botões "New Game" / "Restart"
- ✅ Integração Riverpod:
  - ✅ ConsumerStatefulWidget para GameScreen
  - ✅ ref.watch() para observar estado
  - ✅ ref.read() para chamar métodos
- ✅ App root (main.dart):
  - ✅ ProviderScope envolvendo app
  - ✅ Tema Dark Mode
  - ✅ GameScreen como home

**Saída:** Jogo jogável com lógica e UI integradas.

---

### Fase 3: Motor de Jogo Correto ✅ Completa
**Objetivo:** Fazer o ciclo de jogo funcionar como um Match-3 de verdade.

Bugs encontrados ao jogar o protótipo (todos com teste de regressão):
- ✅ **Sorteio periódico.** O gerador pseudoaleatório caseiro usava `seed % 4`,
  e os bits baixos de um LCG têm período 2^k — o tabuleiro saía
  `01230123` idêntico em todas as linhas. Trocado por `Random` do `dart:math`.
- ✅ **Tabuleiro nascia resolvido.** O sorteio agora recusa valores que
  fechariam trio, e regenera até haver pelo menos uma jogada possível.
- ✅ **Sem reposição no topo.** A gravidade empurrava as peças para baixo e
  nada preenchia os vazios: o tabuleiro drenava até esvaziar.
- ✅ **Cascatas não aconteciam.** A detecção rodava em loop antes da
  gravidade, então combinações formadas pela queda nunca eram vistas.
  Agora o ciclo é `combinação → fusão → queda → reposição → repete`.
- ✅ **Troca inválida era aceita.** Qualquer troca adjacente contava
  movimento mesmo sem formar combinação. Agora é recusada e sinalizada em
  `GameState.rejectedSwap` para a UI animar a volta.
- ✅ **Combinações podiam se sobrepor.** Uma peça podia ser evoluída por um
  match e removida por outro no mesmo passo. As combinações são disjuntas.

**Refactor:** a lógica pura saiu do notifier para
`domain/match_engine.dart`. O `MatchEngine` recebe um `Board` e devolve
outro, o que permite testar cascata e reposição com tabuleiros montados à
mão em vez de depender do sorteio — foi justamente um teste frágil que
deixou o bug do LCG passar.

**Saída:** 48 testes, motor testável isoladamente.

---

### Fase 4: Sistema de Fases (em definição)
**Objetivo:** Dar metas alcançáveis ao jogador.

**Diagnóstico:** a fusão é exponencial de base 3 — 3 peças de V geram 1 de
V+1, o que é *neutro em valor*, não um ganho. Formar um único `9` partindo
de zeros exige 3⁹ = 19.683 peças; partindo de `3`, ainda 3⁶ = 729. Num
tabuleiro de 64 células o objetivo temático é inatingível. Além disso, como
só uma peça sobrevive por combinação, um match de 5 rende o mesmo que um de
3 — hoje o design **pune** combinações grandes.

**Direção escolhida** (consulta a especialistas em game design):
- Modelo de fase: **alvo de fusão + limite de movimentos**
  ("crie um 6 em 22 movimentos"). Sessões de 1-3 min.
- High score vira **modo Endless separado**, desbloqueado após a fase 5.
- Bloqueadores (peças congeladas) só a partir da fase 8.

**Simulação:** `tool/simulate_economy.dart` roda o `MatchEngine` de verdade
(não uma reimplementação) com um jogador automático — aleatório e guloso —
e mede em quantos movimentos cada dígito aparece. `dart run
tool/simulate_economy.dart --mode=both --games=10 --moves=1200`.

**Multiplicadores de valor** (uma peça de V+1 custa três de V, então
match-3 → V+1 é *neutro*; ver `domain/fusion_rule.dart` e seus testes):

| regra | match-3 | match-4 | match-5 |
|---|---|---|---|
| neutra (atual) | 1,00x | **0,75x** | **0,60x** |
| graduada (4 → V+1 e V; 5 → V+2) | 1,00x | 1,00x | 1,80x |
| agressiva (4 → V+2; 5 → 2×V+2) | 1,00x | 2,25x | 3,60x |

Duas correções que a simulação impôs sobre as estimativas iniciais:
1. A regra atual não deixa de premiar combinações grandes — ela **destrói
   valor** acima de 3 (0,75x e 0,60x). Um match-5 rende menos que um match-3.
2. Os números que eu havia estimado à mão para a regra graduada (1,33x no
   match-4, 2,25x no match-5) estavam errados: são 1,00x e 1,80x. Os
   denominadores tinham sido trocados.

**Achado principal — o gargalo não é a economia da fusão.** Em 1200
movimentos, com 10 partidas por configuração, o dígito 9 **nunca** foi
alcançado, nem com a regra agressiva. E 60/60 partidas terminaram por
falta de jogada possível, nenhuma bateu o teto de movimentos. O que trava
o jogo é o tabuleiro entupir: uma peça alta é única, e com spawn fixo em
0-3 ela nunca encontra as outras duas para fundir, ocupando célula até não
haver mais troca válida. A regra agressiva só acelera a subida (dígito 6 em
26 movimentos contra 36 da neutra); não muda o teto.

Custo mediano por dígito (regra graduada, jogador guloso, spawn 0-3):

| dígito | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|
| movimentos | 1 | 8 | 32 | 118 | 366 | — |
| partidas que alcançam | 100% | 100% | 100% | 90% | 30% | 0% |

**Segundo achado — a janela de spawn é uma renomeação, não profundidade.**
Ao varrer as janelas 0-3, 1-4, 2-5, 3-6 e 4-7, as medianas saem *idênticas*,
apenas deslocadas um dígito (sempre 1, 8, 32, 118, 366, com os mesmos
mín/máx). O motivo, provado em teste (`invariância da janela de spawn`):
nenhuma regra do jogo olha o valor absoluto de uma peça — só se dois valores
são iguais e quanto é `value + 1`. Então o jogo com janela 1-4 **é** o jogo
com janela 0-3 com todos os rótulos somados de 1, até alguém encostar no 9.

Subir o piso não aprofunda nada: apenas aproxima o jogador da única saída.

**Terceiro achado — a explosão do 9 e a janela de spawn só funcionam
juntas.** A explosão foi implementada e medida (`--mode=explosion`). Nenhuma
das duas resolve o assoreamento sozinha:

| configuração | partidas que travam | partida mediana |
|---|---|---|
| spawn 0-3, sem explosão | 10/10 | 274 mov |
| spawn 0-3, **com** explosão em área | 10/10 | 274 mov |
| spawn 3-6, sem explosão | 7/10 | 830 mov |
| spawn 3-6, **com** explosão em área | **0/10** | 1200+ mov |

Com spawn 0-3 a explosão é **inerte**: o dígito 9 nunca é alcançado (0% das
partidas), então a válvula fica numa porta que ninguém abre — o tabuleiro
assoreia em 6/7/8, muito antes do topo. Só quando a janela sobe o bastante
para o 9 virar alcançável é que a explosão passa a dar vazão.

Na janela 2-5, onde o 9 é alcançado em 90% das partidas, o formato importa:
travamento cai de 9/10 (sem explosão) para 8/10 (área) e 6/10 (cruz). A cruz
limpa 15 células contra 9 da área. Na janela 3-6 as duas zeram o travamento,
então **área** ficou como padrão: é o formato menos destrutivo que resolve.

**Consequências para o design de fases:**
- Para sessões de 1-3 min (~15-30 movimentos), os alvos viáveis são 5 e 6.
- Os limites de movimento sugeridos pelos especialistas são apertados demais:
  "crie um 6 em 22 movimentos" contra uma mediana de 32 falharia na maioria
  das tentativas. Precisam subir ~30-50%.
- Subir o piso do spawn por fase continua servindo — mas como **encurtar a
  distância até a saída**, não como aumento de dificuldade ou profundidade.
- **O assoreamento não afeta a campanha.** Com fases de 15-30 movimentos, a
  partida acaba muito antes dos ~274 movimentos em que o tabuleiro trava.
  Spawn 0-3 serve bem para as fases iniciais.
- **O assoreamento afeta o Endless.** É lá que a dupla janela-alta +
  explosão passa a ser necessária: sem ela a sessão morre por travamento em
  poucos minutos. A janela precisa subir ao longo da partida.

**Configuração padrão atual** (fixada em teste, `grupo configuração padrão`):
`TieredFusion`, explosão em área, spawn 0-3.

**Tarefas:**
- ✅ Simular custo em movimentos por dígito
- ✅ `FusionRule` plugável (`NeutralFusion`, `TieredFusion`, `AggressiveFusion`)
- ✅ Janela de spawn parametrizável (`spawnMin`/`spawnMax` no `MatchEngine`)
- ✅ Varredura da janela de spawn (resultado: é renomeação, não profundidade)
- ✅ **Explosão do dígito 9** (`ExplosionShape.none/area/cross`), com o
  travamento medido antes e depois
- ✅ `TieredFusion` como regra padrão (a neutra destrói valor acima de 3; a
  agressiva não resolve o gargalo real)
- ✅ `Objective` + `moveLimit` + janela de spawn por fase (`domain/game_level.dart`)
- ✅ Campanha de 10 fases com limites **calibrados por simulação**
  (`--mode=phases`), não escolhidos a olho
- ✅ `GameStatus.won/lost`, cartão de fim de fase, tela de seleção de fases
- ✅ **Modo Endless** com recorde persistido (`shared_preferences`) e janela de
  spawn progressiva (`domain/endless_progression.dart`)
- ✅ Persistência de progresso da campanha e recorde do Endless, num único
  `GameStorage` (`providers/game_storage.dart`)
- ✅ **Animações de base**: queda das peças, pulo na fusão, entrada de peça nova,
  saída das eliminadas e volta da troca recusada
- ✅ **Dica**: depois de 6 s parado, as duas peças de uma jogada possível
  acendem
- ✅ **Arrastar o dedo** para trocar peças, além do toque duplo
- ✅ **Combinações cruzadas** (L, T, +) contam como uma só e pagam pelo total
- ✅ **Efeito diferenciado** para combinação de 4+: pulo maior e clarão branco
- ✅ **Acabamento visual**: peças com volume, moldura do tabuleiro, tipografia
  própria (Nunito empacotada)
- ~~Peças maiores~~ — descartado: exigiria reduzir o tabuleiro para 7x7, e a
  decisão foi manter 8x8
- ✅ **Cascata passo a passo**, com combo, pontuação flutuante, anel de impacto
  e clarão da explosão
- ✅ **Cartão de início de fase**, **estrelas no fim** e **recompensa do 9**
  (faíscas, batida tátil e movimentos-bônus) — ver Fase 10
- Peças congeladas (exige campo novo em `Tile`)
- Estender a campanha além da fase 10

---

### Fase 8: Animações ✅ Parcial

O tabuleiro deixou de ser um `GridView` de células e passou a ser um `Stack` de
peças em coordenadas absolutas. A diferença que importa: a chave de cada peça é
o **id dela**, não a posição. Com a chave na posição, uma peça "caindo" era duas
células trocando de conteúdo, e não havia nada para o Flutter interpolar.

**Toque e desenho ficaram separados de propósito:** as áreas tocáveis são uma
camada por cima, endereçada por posição (`tileKey`), enquanto o desenho é
endereçado por identidade (`tileVisualKey`). Uma peça em queda muda de posição
no meio da animação; o toque tem de continuar valendo pela célula.

**Duas camadas de movimento, também de propósito:** o `AnimatedPositioned` cuida
da célula ocupada (a queda) e um `Transform.translate` interno cuida do empurrão
da troca recusada. A primeira tentativa somava o empurrão ao `left` do
`AnimatedPositioned` — e a animação de queda ficava perseguindo um alvo em
movimento, amortizando o gesto até ele desaparecer da tela.

**Saída das eliminadas:** a peça consumida pela fusão sai do tabuleiro no mesmo
instante em que o estado muda, então o widget precisa segurá-la por alguns
frames. `_leaving` guarda quem partiu, comparando o tabuleiro antigo com o novo
por id. Curiosamente, esse corte seco ficou **mais** visível depois das outras
animações, não menos: enquanto tudo era instantâneo o olho não separava as
coisas; com as vizinhas deslizando, a que sumia de um frame para o outro passou
a chamar atenção.

**Nada de `Future.delayed` dentro de widget.** A primeira versão da saída usava
um, e o framework de teste reprovou por temporizador pendente — com razão:
temporizador solto não respeita o relógio do teste nem para quando o widget sai
de tela. O relógio da saída é um `AnimationController`, acionado pelo `pump`.

**Dica após ociosidade.** `MatchEngine.findHint` devolve uma troca que funciona,
ou `null`. Não é busca extra: `hasValidMoves` passou a ser `findHint(board) !=
null`, então a mesma varredura responde "ainda dá para jogar" e "qual é a
jogada". O estado guarda a dica a cada movimento; a UI decide *quando* revelar.

O relógio de ociosidade é um `AnimationController` de 6 s, reiniciado a cada
sinal de atividade (tabuleiro muda, seleção muda, troca recusada). O brilho
**não pisca** de propósito: uma animação repetitiva faria `pumpAndSettle` nunca
terminar e derrubaria toda a suíte de widget. Se um dia quisermos pulso, ele
precisa ser finito (N ciclos e para).

`BoardGridWidget.debugHintDelayOverride`, ligado em `test/flutter_test_config.dart`,
encurta a espera nos testes — sem isso todo `pumpAndSettle` avança 6 s de relógio
e a suíte fica seis vezes mais lenta sem ganho de cobertura.

### Combinações cruzadas

Sequências que se cruzam formam **uma** combinação: um L, um T ou um `+` valem
pelo total de peças, não pelo braço mais longo. Antes o braço que sobrava era
descartado — um L de 5 rendia V+1 em vez de V+2, ou seja, o jogador era punido
por fazer a jogada mais difícil.

A detecção agora coleta todas as sequências maximais e **une as que
compartilham casa** (só podem se cruzar se tiverem o mesmo valor, já que a casa
comum tem um valor só). Isso também deixou a disjunção mais limpa: antes era um
"pula se já foi reivindicado", agora sai naturalmente do agrupamento.

A peça evoluída nasce no **cruzamento** quando não há âncora — é onde o olho
espera, e é o único ponto que pertence aos dois braços.

**A cruz recalibrou a campanha.** Combinações maiores pagam mais, então tudo
ficou mais fácil: fase 6 foi de 73% para 85%, fase 5 de 85% para 98%. Os limites
das fases 3, 4, 5 e 7 foram apertados (12→10, 18→15, 26→21, 20→14) e a campanha
voltou para a faixa de 70-90%.

### Fase 9: Recompensa visual ("game juice") ✅ Completa

**A resolução deixou de ser atômica.** `resolve()` devolve `steps`: cada ciclo
de (combinação → fusão → queda → reposição) com o tabuleiro em dois momentos —
`boardAfterFusion` (peças absorvidas já removidas, casas ainda vazias) e
`boardAfterSettle`. Sem isso a UI só via o antes e o depois, e não havia como
mostrar combo por cascata, pontuação no lugar certo, nem a fusão acontecendo.

`FusionEvent` carrega o que a animação precisa: quais peças foram consumidas,
onde nasceu a nova (`at`), o id dela e o tamanho da combinação. Tudo em
`Resolution` (score, cascades, producedDigits...) passou a ser **derivado** dos
passos, para não haver duas versões da mesma verdade.

**O notifier encena** em `_playResolution`, avançando quadro a quadro com
`JuiceTimings`. Durante a encenação `isResolving` bloqueia toque e seleção:
jogar por cima da animação embaralharia o que o jogador vê com o que já
aconteceu. A pontuação sobe **a cada cascata**, não no fim — assim o número não
salta depois de a animação acabar.

**Testes:** `JuiceTimings.instantResolution`, ligado em
`test/flutter_test_config.dart`, resolve a jogada de uma vez. Sem isso os ~230
testes de regra de jogo teriam de virar assíncronos e a suíte levaria minutos.
`resolution_playback_test.dart` desliga a chave e verifica a encenação em si,
com uma espera de mentira injetada.

**Armadilhas que custaram tempo:**
- `late final AnimationController` **é perigoso em widget de efeito**: se o
  widget nunca chega a construir (o aviso de combo não desenha nada quando não
  há o que anunciar), quem inicializa o campo é o próprio `dispose()`, criando
  um controlador no meio do desmonte da árvore. Criar no `initState`.
- **`Stack` passa restrições frouxas** aos filhos não posicionados, e um
  `DecoratedBox` sem filho colapsa para zero. Ao agrupar os dois anéis de
  impacto num Stack, eles viraram um ponto invisível. `StackFit.expand` resolve.
- **A geometria do tabuleiro é compartilhada** (`BoardGeometry`) entre o
  tabuleiro e a camada de efeitos. Duplicar a fórmula faria a pontuação
  flutuante desalinhar em silêncio ao primeiro ajuste de espaçamento.

**Como inspecionar:** os efeitos duram menos de um segundo e só existem depois
de uma jogada, que uma captura de simulador não consegue disparar.
`juice_golden_test.dart` congela um quadro perto do pico e grava
`goldens/juice_fusion.png` e `goldens/combo_banner.png`. Amostrar na metade da
animação não serve — nessa altura os efeitos já estão quase apagados e o golden
não mostra o que o jogador vê.

### Fase 10: Ritual de fase e recompensa do 9 ✅ Completa

Três momentos que existiam como mecânica mas não como **experiência**: abrir uma
fase, criar o dígito máximo, e terminar.

**Cartão de início (`LevelStartDialog`).** O jogador caía direto num tabuleiro
cheio, com o objetivo escrito num canto que ninguém lê antes da primeira jogada
— e descobria o que a fase pedia depois de já ter gastado movimentos. Agora a
fase abre com o alvo desenhado grande, o orçamento de movimentos e um "JOGAR".
Enquanto ele está aberto, `IgnorePointer` bloqueia o tabuleiro e o relógio da
dica não corre.

Duas decisões que economizaram complicação:
- **Não é `showDialog`.** Uma rota por cima tira o tabuleiro da árvore de foco,
  complica o teste de widget e obriga a coordenar duas navegações a cada
  reinício de fase. É só mais uma camada do `Stack` da tela.
- **`_ready` mora na tela, não no `GameState`.** É estado de apresentação: o
  motor não tem nada a decidir enquanto o cartão está aberto, e um
  `GameStatus.ready` obrigaria toda regra que pergunta "está jogando?" a
  considerar mais um caso.

**`runId` foi necessário.** A primeira versão reabria o cartão observando a
transição de status para `playing`. Funciona ao avançar e ao tentar de novo
depois de perder — mas **recomeçar uma fase em andamento é `playing → playing`**,
com o mesmo número de fase, indistinguível de nada ter acontecido. `startLevel`
passou a incrementar `GameState.runId`, que é o sinal exato de "uma partida
começou". Foi um teste que pegou isso, não o app.

**Recompensa do 9.** A explosão já existia e já tinha clarão; faltava ela
**pagar**. Três acréscimos:
- `kExplosionBonusMoves = 3` movimentos devolvidos por dígito máximo criado,
  em `GameState.bonusMoves`. Somam ao limite em vez de descontar do gasto, para
  `moves` continuar sendo "quantas jogadas o jogador fez".
- Faíscas brancas e prateadas (`CustomPainter`, 22 partículas, semente fixa) e
  a pílula "+3 Movimentos!" no topo do tabuleiro — longe do centro de
  propósito, porque sobre o clarão ninguém leria o texto.
- `HapticFeedback.heavyImpact()`, disparado na **encenação** e não no fim da
  jogada: a batida tem de coincidir com o clarão, não com o fim da cascata.

O bônus entra em `_outcomeAfterMove` **antes** da conferência de saldo — um 9
criado na jogada que zeraria o contador salva a fase em vez de chegar tarde
demais. Há teste para exatamente isso.

**Estrelas (`domain/star_rating.dart`).** A nota mede folga, não velocidade:
30% do saldo intacto valem 3, 10% valem 2, vencer no limite vale 1. Vencer é
sempre pelo menos uma estrela. O denominador é `movesAvailable` (limite **mais**
bônus), senão a explosão viraria estrela de graça — ela engorda o saldo restante
e inflaria a nota sem o jogador ter jogado melhor.

**Os títulos de derrota passaram a vir de `lossReason`,** não do saldo. O cartão
ainda deduzia pelo `movesLeft == 0` mesmo com `lossReason` já existindo no
estado — exatamente o padrão que causou o relato de falso fim de jogo descrito
adiante. Agora são "MOVIMENTOS ESGOTADOS" e "TABULEIRO TRAVADO", com frases
distintas e um teste que exige que uma nunca apareça no lugar da outra.

**Armadilhas desta rodada:**
- **A fonte de teste mede diferente.** "500 Movimentos" estourou o cartão em
  23px num iPhone SE porque em `flutter_test` cada glifo ocupa um `em` inteiro.
  O bug é real mesmo assim — o rótulo cresce com o limite da fase — e a correção
  (`Flexible` + elipse) vale nos dois mundos. Não trate overflow de teste como
  artefato de fonte sem olhar.
- **Tabuleiro de teste em L, nunca em fila.** Montar os três iguais já alinhados
  faz o tabuleiro nascer com a combinação pronta, e a troca é recusada por não
  criar nada. As peças ficam em L e a jogada fecha a fila.
- **O golden do juice muda quando a camada de efeitos muda.** As faíscas e a
  pílula deram 3,16% de diferença. O `isolatedDiff` mostrou só os dois
  acréscimos esperados — é assim que se decide entre regravar e investigar.

**Não implementado: som.** O projeto não tem nenhuma infraestrutura de áudio, e
escolher um pacote é decisão de projeto, não detalhe de implementação. O retorno
tátil e o visual estão no lugar.

### Fase 11: Mapa da campanha (Saga Map) ✅ Completa

A lista vertical de cartões cinzas virou uma trilha sinuosa de pins. A troca não
é de enfeite: a lista mostrava dez linhas iguais e não dizia **onde o jogador
estava**, nem dava motivo para voltar a uma fase já vencida.

**As estrelas não existiam.** O cartão de fim de fase calculava a nota e a
jogava fora — só `campaignProgress` (o número da última fase vencida) era
persistido. O mapa exige guardar o resultado de cada fase, então entraram
`LevelRecord` (estrelas + melhor placar), `CampaignRecords` e duas operações
novas no `GameStorage`. Fica **separado** de `CampaignProgress` de propósito:
aquele responde "até onde cheguei" e é o que destrava fase; este responde "quão
bem fui" e é o que alimenta o mapa. Juntá-los faria a regra de destravamento
depender do formato do histórico.

O merge guarda **o melhor de cada grandeza em separado**: uma partida pode
render mais pontos e menos estrelas que a anterior (sobrar movimento não é a
mesma coisa que pontuar), e rejogar para tentar a terceira estrela não pode
custar a que já se tinha.

**`SagaGeometry` é compartilhada por três coisas** — o traçado do caminho, a
posição dos pins e a rolagem que centraliza a fase atual. É a mesma lição do
`BoardGeometry`: duplicar a fórmula faria o caminho descolar dos pins ao
primeiro ajuste de espaçamento.

A ondulação é uma **senoide**, não um zigue-zague de segmentos: a curva contínua
é o que faz o traçado parecer caminho em vez de gráfico. E a amplitude tem
**teto** — proporcional à largura, num tablet os pins iriam para as bordas e a
trilha viraria um vai-e-vem de canto a canto.

**Um bug real que o teste pegou.** A rolagem centralizava no `postFrameCallback`
do `initState`, quando `campaignProgress` ainda vale zero — a leitura do disco é
assíncrona. Resultado: quem já tinha campanha adiantada abria o mapa no pé da
trilha, com o pin que pulsa fora da tela. A centralização passou a reagir a
**toda** mudança de progresso, e distingue os dois motivos: vitória toca a
animação de liberação, chegada da leitura só reposiciona.

**O Endless saiu da fila.** Ele não é fase e não podia continuar parecendo uma —
fase tem objetivo, limite e um fim. Virou ilha própria, com formato, cor e
posição deliberadamente diferentes de tudo no mapa, exibindo o recorde. Isso
exigiu `endlessHighScoreProvider`: o `EndlessNotifier` só carrega o recorde ao
iniciar uma sessão, e pedir o recorde a ele obrigaria a criar uma partida para
desenhar um banner. Ele relê ao voltar do Endless, porque quem grava é o outro
notifier.

**Só um elemento anima.** O pin da fase atual pulsa; nenhum outro. Se o mapa
inteiro piscasse, nada se destacaria. E o pulso fica desligado na suíte
(`debugDisableMapPulse`, em `flutter_test_config.dart`) — animação repetitiva
deixa `pumpAndSettle` sem fim, mesma regra do brilho da dica.

**Som, enfim: `SystemSound.play(SystemSoundType.click)`.** O clique de toque do
próprio sistema, sem pacote de áudio, sem arquivo no bundle, e respeitando o
ajuste de som do aparelho sem código nosso. Não serve para música nem para
efeitos de jogo — para isso ainda falta decidir um pacote —, mas resolve o "som
leve de toque" pedido para os pins.

**As chaves antigas ficaram.** `levelCardKey` e `endlessCardKey` mantêm os nomes
(`level_N`, `endless_card`) porque são a porta pela qual os testes verificam
acesso a fase. Trocá-los faria uma mudança de layout parecer mudança de regra —
e de fato, dos testes existentes só três falharam, todos por texto ou ícone que
o novo layout mudou de propósito; a lógica de acesso passou inteira.

**`goldens/saga_map.png`** trava o acabamento. Nele foi preciso carregar também
a **MaterialIcons**: sem ela estrela, cadeado e coroa viram quadrados, e o mapa é
feito justamente desses símbolos. O carregamento é tolerante a falha — o caminho
da fonte vem do pacote do Flutter e pode mudar entre versões; perder nitidez no
golden é melhor que derrubar a suíte.

### Fase 12: Diegese visual — HUD com peso, modais com personalidade ✅ Completa

Diagnóstico externo: o jogo lia como aplicativo utilitário. O cabeçalho era um
retângulo preto com texto cinza — uma `AppBar` de app de finanças — e os modais
eram caixas planas com botões retangulares, indistinguíveis de `AlertDialog`.

**Cada métrica virou um objeto (`GameMetricCard`).** Antes eram textos soltos
sobre um fundo chapado. A moldura individual é o que faz o olho ler três
informações **com função** em vez de uma linha de legenda: ícone, rótulo e
valor, com degradê escuro, aro na cor da métrica e sombra projetada. Vale para
os dois modos — campanha (Objetivo / Pontos / Jogadas) e Modo Recorde (Pontos /
Recorde / Maior Bloco) —, porque os dois precisam parecer o mesmo jogo.

**O título saiu de dentro do modal (`GameDialog`).** É a mudança que o jogador
percebe: um retângulo com texto dentro lê como aviso; um selo curvo pregado no
alto, projetado para fora da caixa, lê como prêmio. O fundo virou degradê
radial (luz batendo na caixa) com borda reluzente e halo na cor da ocasião.

**O botão principal afunda sob o dedo (`GameButton`).** Deixou de ser
`ElevatedButton` justamente porque o Material evita o que se quer aqui —
compressão física. A espessura é um `BoxShadow` de **blur zero**: uma aresta
sólida, não uma sombra. Ao pressionar, o botão desce exatamente a altura que a
aresta perde, então o conjunto não muda de tamanho.

**Armadilhas desta rodada:**
- **`CrossAxisAlignment.stretch` numa `Row` dentro de `Column` sem altura**
  pede altura infinita e derruba o layout inteiro (48 testes de uma vez). As
  pílulas precisam de `IntrinsicHeight` para se igualarem em altura.
- **`margin` de `Container` entra na caixa que a chave endereça.** O teste do
  selo media o cartão começando onde estava o selo, e a asserção ficava
  verdadeira por acidente. O recuo virou um `Padding` por fora.
- **`FractionallySizedBox` com `DecoratedBox` sem filho precisa de
  `heightFactor: 1`.** Sem ele a barra do objetivo colapsa para altura zero e
  some — mesma armadilha dos anéis de impacto no `Stack`, e foi o golden que a
  pegou, não a suíte: nenhum teste afirmava que a barra tem altura.
- **`Semantics(label:)` por cima de um `Text` duplica o rótulo.** O leitor de
  tela anunciava "CONTINUAR CONTINUAR". O `Text` de dentro já basta.
- **Teste que apanha "o primeiro `Container` sob a chave" quebra a cada
  mudança de layout.** O selo do maior bloco ganhou chave própria
  (`endlessBiggestTileKey`); a pílula do HUD também é um `Container` com
  decoração.

**Sombra de texto, com limite.** `kGameTextShadow` existe e é usada no selo do
título, que é estático. **Não** foi aplicada aos números do HUD que vivem dentro
do pulso: o Impeller rasteriza sombra de texto fora das transformações, e foi
exatamente assim que os dígitos das peças viraram fantasmas no canto do
tabuleiro. A regra está escrita na própria constante.

**Fredoka não entrou.** O brief sugeria; o projeto não baixa fonte em runtime
(o `google_fonts` foi removido de propósito) e não há arquivo dela empacotado.
Adotá-la é decisão de projeto — acrescentar `assets/fonts/Fredoka-*.ttf` e a
licença. A Nunito em `w900` já é arredondada e encorpada, e é o que o HUD usa.

**Três defeitos que só o simulador mostrou** (iPhone 16 Pro, 393pt) — todos de
largura real, nenhum visível em golden nem na suíte:
- **A chamada do Modo Recorde não cabia na mesma linha do título.** Dividindo a
  linha com ícone, título e legenda sobravam ~140pt para o texto: "Modo Recorde
  🏆" quebrava em duas linhas e "Sua melhor pontuação" saía truncada. A chamada
  ganhou linha própria, como `GameButton`.
- **"Maior Bloco" virava "Maior Blo…"** na pílula do HUD — justamente o rótulo
  que existe para dizer de que "maior" se trata. O rótulo da `GameMetricCard`
  passou a encolher (`FittedBox`) em vez de cortar: nessa pílula reticência é
  pior que letra menor.
- Nada de **fantasma de sombra de texto** em Impeller, que era o risco de trazer
  `shadows:` de volta ao HUD. A regra de não usá-la dentro de transformação se
  confirmou suficiente.

Como inspecionar sem toque: `simctl` não injeta gestos e o clique via AppleScript
depende de permissão de automação. O caminho foi apontar `main.dart` para a tela
em questão e usar **hot restart por sinal** (`flutter run --pid-file=…`, depois
`kill -USR2` para reiniciar e `-USR1` para recarregar), revertendo o `main.dart`
ao fim. Sem `--pid-file` o Flutter não registra os manipuladores de sinal, e a
única saída é reconstruir a cada mudança.

**Goldens novos:** `game_hud.png`, `game_hud_urgent.png` e `level_outcome.png`
(`hud_golden_test.dart`). O do alerta existe separado porque o aro vermelho e o
neon **só** aparecem na reta final — um golden do estado calmo não mostraria
nada disso. Como no mapa, a MaterialIcons precisa ser carregada à mão, senão
alvo, raio, troféu e estrelas viram quadrados; e o tema do teste fixa a Nunito
como fonte ambiente, porque os rótulos das pílulas não pedem família própria.

### HUD: o que muda a cada jogada fica na tela, o resto sai

O cabeçalho das duas telas de jogo carregava texto fixo — a dica escrita da
fase, "Crie um X para subir a faixa" — enquanto o placar morava sozinho num
rodapé **abaixo** do tabuleiro, fora do campo de visão de quem está jogando.
A troca é essa: espaço permanente vai para o que muda.

**A dica escrita sobrevive só na fase 1.** O `LevelStartDialog` já mostra o
`teaches` de toda fase que tem um, antes do primeiro toque — repeti-lo no HUD
custava espaço permanente para dizer algo que o jogador acabou de ler. Na fase
1 ele fica, porque ali o jogador ainda não sabe nem qual é o gesto, e some no
primeiro movimento. Quem anima é um `AnimatedSize`: sem ele o tabuleiro saltaria
para cima de um quadro para o outro.

**A barra de estrelas usa `starRating`, a mesma do cartão de fim de fase.**
Duplicar a fórmula faria o HUD prometer três estrelas e a vitória entregar
duas. Ela mede folga de movimentos, então cai sozinha conforme o jogador gasta
— que é justamente o aviso que faltava: hoje a perda de estrela só aparecia
depois, no cartão, quando não havia mais o que fazer.

**O pulso da reta final é finito, e isso não é detalhe.** Uma animação em
repetição faz `pumpAndSettle` nunca terminar e derruba a suíte de widget
inteira — a mesma armadilha que já tinha decidido que o brilho da dica não
pisca. A solução é um `TweenAnimationBuilder` com `ValueKey(movesLeft)`: cada
movimento gasto monta um controlador novo, que anima meio ciclo de seno e para.
Dá batida por jogada, e assenta.

**No Endless, "Maior" virou "Maior Bloco" com a peça desenhada.** "Maior"
sozinho podia ser pontuação, faixa ou combo, e o número solto não se parecia
com o que descreve. Zero ali não é um bloco: nenhuma fusão devolve zero (a
menor peça que ela cria é um 1), então zero significa "ainda não fundiu nada" e
aparece como travessão.

**A barra da faixa mede distância, não acúmulo.** A promoção é um evento — ela
dispara ao criar o dígito que promove —, então não existe fração de progresso
para exibir. O que dá para medir honestamente é o maior bloco já criado contra
o alvo: fundir o dígito logo acima do teto da faixa é meio caminho, o seguinte
promove.

### O estouro que a suíte não podia ver: aura medindo layout

Relato do console durante a partida: `RenderFlex overflowed` numa `Column` de
`_LevelPin`, no mapa da campanha. Caixa de 119px, conteúdo maior.

**A causa era a aura do pin da fase atual dando o tamanho do conjunto.** Ela era
filho comum de um `Stack`, e `Stack` se dimensiona pelo maior filho não
posicionado — então o diâmetro da aura, que **cresce durante o pulso**, virava a
altura do pin e empurrava o rótulo "JOGAR" para fora da caixa. Em repouso a
aura mede 1,35 do pin e cabe; no auge mede 1,70 e não cabe.

**Por isso nenhum teste pegou.** `debugDisableMapPulse` desliga o pulso na suíte
inteira — regra necessária, porque animação em repetição faz `pumpAndSettle`
nunca terminar. O efeito colateral é que a suíte só via a aura no menor
diâmetro, exatamente o único tamanho em que não há estouro. O teste de
regressão (`saga_map_pulse_test.dart`) liga o pulso de propósito e avança o
relógio à mão, em passos de 100ms por um ciclo inteiro, sem `pumpAndSettle` —
amostrar só o começo e o fim não veria nada.

**A correção é de responsabilidade, não de tamanho.** Aumentar a caixa até
caber esconderia a inversão: decoração não deve medir layout. A aura foi para
`Positioned.fill` + `OverflowBox` — fora do cálculo de tamanho do `Stack`, livre
para passar da borda — com `clipBehavior: Clip.none` para o recorte padrão não
comer justamente o auge do pulso. O `Transform.scale` do pin passou a ser o
único filho que mede.

De quebra o pin ficou **melhor** centrado na trilha: antes a aura o empurrava
~6px abaixo do nó do caminho. O golden `saga_map.png` foi regravado; o
`isolatedDiff` mostrou só o pin atual e o "JOGAR" subindo, nada mais.

### Acabamento da rolagem do mapa: fade, continuidade e âncora

Três detalhes de renderização que só aparecem com o mapa em movimento.

**Fade nas bordas da rolagem.** O cabeçalho e a ilha do Endless são fixos, então
a trilha desliza por baixo deles e morria num corte seco na borda. A máscara é
um `ShaderMask` com `BlendMode.dstIn`: o que recorta é **o alfa** do degradê, e
por isso as cores são branco opaco → transparente e não a cor de fundo. Um fade
pintado por cima só funcionaria sobre fundo chapado, e a tela tem degradê. O
fade de baixo veio junto — é o mesmo corte, na outra ponta.

**A trilha não termina na última fase.** `SagaGeometry.futureNodes` acrescenta
três nós projetados acima da fase 10, ligados por linha **pontilhada**, com
círculo menor, translúcido e cadeado. É geometria e não enfeite: `height` conta
com eles (`lastIndex`), senão nasceriam fora da área rolável. Como `centerOf` já
aceitava qualquer índice e a rolagem usa a mesma `SagaGeometry`, a centralização
da fase da vez continuou batendo sem nenhuma mudança na tela.

Eles são `ExcludeSemantics` de propósito: anunciar um nó projetado a um leitor
de tela como fase daria a entender que existe algo para abrir.

Efeito colateral nos testes: dois deles contavam `Icons.lock_outline` **na tela
inteira** para afirmar quantas fases estavam travadas. Com os nós projetados o
total subiu em três, e a contagem passou a somar `SagaGeometry.futureNodes` —
a asserção continua sobre o mesmo fato, mas agora diz de onde vem cada cadeado.

**O rótulo do pin virou `Positioned`, não irmão de `Column`.** Estrelas e
"JOGAR" ficavam empilhados abaixo do círculo numa `Column`, então a distância
até o círculo dependia de quanto o pin media — e o pin da fase atual é maior.
Agora o rótulo sai do cálculo de tamanho (`kPinBadgeOffset = -18`, ancorado à
borda de baixo do círculo) e o `Stack` é medido **só pelo pin**. É a mesma
lição da aura: decoração não deve medir layout.

Para isso a caixa de cada nó passou a ser quadrada e **centrada no ponto da
trilha**, com o conteúdo num `Center` — restrição frouxa é o que deixa o pin se
medir sozinho. De quebra o pin ficou exatamente sobre o nó do caminho, em vez
de pendurado a partir do topo de uma caixa alta.

Cuidado ao testar: `bottom: -18` posiciona a **borda de baixo** do rótulo, não o
topo. E medir `find.byIcon(Icons.star_rounded).first` mede *uma* estrela, não a
fileira — para o centro da fileira é preciso ir da primeira à última.

### A peça ápice: o 9 deixou de ser um bloco branco

Relato de UI: o dígito máximo, que é o clímax do motor de jogo, era o que menos
se destacava — um retângulo branco chapado, num tabuleiro escuro, com o número
por cima em 1,15:1 de contraste (o pior da paleta).

Agora o 9 é o único dígito com **degradê próprio** (`AppColors.apexGradient`,
dourado → laranja reluzente) e com **brilho declarado uma vez**
(`AppColors.apexGlow`). O brilho mora em `AppColors`, e não em cada widget,
porque a regra é "em qualquer lugar em que a peça 9 for desenhada" — tabuleiro,
selo do maior bloco no HUD, pílula de movimentos-bônus. Duplicar a fórmula faria
o brilho descolar entre as telas ao primeiro ajuste.

O degradê é **diagonal**, e não vertical como o das outras peças: a inclinação é
o que dá ar de metal polido em vez de plástico. E o contorno do número engrossa
de 0,07 para 0,095 do lado da célula — o dourado é a cor mais clara da paleta, o
branco chega a ele em 1,4:1, e quem sustenta a leitura é o traço. Continua
valendo a proibição de `shadows:` no `Text` da peça (ver o episódio dos dígitos
fantasma do Impeller): o contraste vem do traço, nunca de sombra de texto.

**Custo conhecido:** o dourado fica perto do amarelo do `3` em matiz (51° contra
48°). O que separa os dois na tela é o degradê diagonal, o halo neon e o
contorno mais grosso — não a matiz. Se em aparelho a confusão aparecer, a
alternativa já discutida é o roxo místico → rosa neon, que troca a vizinhança do
`3` pela do `5`/`6`.

**Goldens regravados:** `board.png` e `juice_fusion.png`. O `isolatedDiff`
mostrou exatamente as seis peças `9` e a borda da pílula "+3 Movimentos" (que
usa `AppColors.digit9`), nada mais — foi o que autorizou regravar em vez de
investigar.

### Comemoração de fusão máxima: uma vez por partida

A explosão do 9 já tinha clarão, faíscas, batida tátil e movimentos-bônus, mas
nada **dizia** ao jogador o que ele tinha acabado de fazer. Entrou o
`ApexCelebration`: pílula flutuante ("FUSÃO MÁXIMA ALCANÇADA! 🎉") com confetes
num `CustomPainter`.

Três decisões:
- **Uma vez por partida.** Repetir a cada 9 transformaria a conquista em ruído —
  as vezes seguintes já têm o clarão. O sinal é `apexCelebrated`, no estado dos
  dois modos, e mora lá porque quem sabe que a explosão aconteceu é o notifier;
  a UI só vê o tabuleiro antes e depois.
- **Não é `SnackBar`.** Ele rouba o foco e empurra o tabuleiro justamente no
  quadro em que o jogador está olhando para a explosão. É mais uma camada do
  `Stack` da tela, dentro de `IgnorePointer` — há teste que exige que o toque
  atravesse para o tabuleiro.
- **A chave amarra ao `runId`** na campanha: recomeçar a fase é
  `playing → playing`, e sem isso a segunda partida não comemoraria.

De quebra, **o Endless passou a vibrar**. A batida da explosão só existia na
campanha (`GameNotifier.explosionFeedback`); no modo em que o dígito máximo é
ainda mais raro, o clímax passava em silêncio. `EndlessNotifier` ganhou o mesmo
gancho injetável, e um teste que o exercita.

**O selo do maior bloco anima com `TweenAnimationBuilder` + `ValueKey(digit)`,**
não com controlador: a chave amarrada ao dígito faz o tween renascer a cada
promoção, e a animação é finita por construção. Animação em repetição faria
`pumpAndSettle` nunca terminar — mesma regra do brilho da dica e do pulso do
mapa. O ápice ganha pulso maior e um giro leve; os demais dígitos, só o pulso.

### Brilho da peça mais alta: quem decide é o tabuleiro

`TileWidget.isPeak` acende um halo na peça que carrega o maior valor em jogo —
mas quem calcula isso é o `BoardGridWidget`, porque só ele enxerga as outras
63. E com uma condição de raridade (`kPeakGlowMaxTiles`): num tabuleiro
recém-sorteado o topo é o teto da janela de spawn e aparece numa peça em cada
quatro. Acender dezesseis células de uma vez não destacaria nada. O brilho só
liga quando a peça alta é rara — que é exatamente quando ela importa, por ser a
que precisa de par e a que assoreia o tabuleiro se não achar.

O halo do pico usa `spreadRadius` zero de propósito. `BoxShadow` com spread
positivo desenha **fora** da célula e invade as vizinhas; só o dígito máximo,
que é o clímax do jogo, paga esse preço. Há teste que reprova spread positivo
nas demais peças.

Os dois goldens do tabuleiro (`board.png` e `juice_fusion.png`) foram
regravados: a sombra projetada passou de 4/0,35 para 6/0,45 para descolar a
peça do fundo escuro. O `isolatedDiff` mostrou o contorno inferior de cada
peça e nada mais — foi o que autorizou regravar em vez de investigar.

### A largura da janela virou invariante executável

A regra "sempre 4 dígitos ativos" estava só na prosa e nos catálogos. Agora é
`kSpawnWidth` e um `assert` no construtor do `MatchEngine`, no
`setSpawnWindow` e no `GameLevel` — uma fase com janela de 3 ou de 7 valores
não compila em modo debug.

**Com uma exceção nomeada.** `MatchEngine(allowWideSpawn: true)` existe para o
simulador poder medir a janela larga — foi essa medição (`--mode=endless`,
estratégia C) que fixou a regra, e apagar o instrumento apagaria a prova. É o
único ponto do projeto que liga a chave; nenhum caminho do jogo passa por ela.

O `assert` de piso/teto no `GameLevel` também fixa outra regra que só existia
como teste: `spawnMax < kMaxDigit`, senão o dígito máximo cairia pronto do
sorteio e explodiria sem mérito nenhum.

### Eficiência de fase: o número sozinho não decide nada

`--mode=efficiency` calcula `objetivo ÷ movimentos` para cada fase da campanha.
Sozinha essa razão não diz se a fase é justa — 3 peças em 21 movimentos é
confortável para um alvo 5 e impossível para um alvo 8. O relatório por isso
imprime **duas** eficiências e compara:

- **exigida**: `count / moveLimit`, o que a fase pede;
- **alcançável**: `count / movimentos medidos`, jogando a fase com teto de
  `6 × moveLimit` para descobrir o custo real do objetivo naquela janela.

Exigida acima de alcançável é uma fase que a taxa de spawn e a probabilidade de
cascata daquela janela não sustentam. O diagnóstico distingue dois casos que
pedem correções diferentes: **INVIÁVEL** (menos de 70% das partidas alcançam o
objetivo mesmo sem limite apertado — o alvo está errado, mais movimentos não
resolvem) e **APERTADA** (o objetivo é alcançável, só falta orçamento — sai o
limite mínimo que aprovaria 70%).

O catálogo atual passa inteiro. As fases 1 e 2 saem como "frouxa" — é o
tutorial, e está descrito acima.

### "23/30" ao lado de "Capítulo 2": o número certo, na moldura errada

Relato de jogador: *"de onde vem esse 23/30?"*. O contador do cabeçalho do mapa
é a soma das estrelas da **campanha inteira** (`CampaignRecords.totalStars`
sobre `kCampaignStarTotal` = 10 fases × 3). Mas ele fica lado a lado com o nome
de um **capítulo** — e o capítulo 2 tem 4 fases e 12 estrelas, não 30. O olho lê
os dois como se falassem da mesma coisa.

**O número não estava errado.** A regra do projeto pede o progresso total *da
conta* em destaque no cabeçalho. O que faltava era o contador dizer que é total.
Trocá-lo para estrelas do capítulo contrariaria a regra e perderia a régua que
continua subindo depois da campanha concluída.

Entrou a legenda `starsCaption` ("CAMPANHA" / "CAMPAIGN") sob o número. A
palavra é escolhida por contraste: é exatamente a que se opõe a "Capítulo" ao
lado. Fica **abaixo** e não ao lado porque a linha já divide espaço com o nome
do capítulo — numa tela de 375pt qualquer palavra a mais na horizontal come o
título, que já é o elemento que elipsa primeiro.

Veio junto `starsSemantics`: "23/30" lido em voz alta não diz de que é a fração,
que é a mesma ambiguidade, para quem não enxerga. O `Semantics` usa
`excludeSemantics: true`, senão o leitor anunciaria a frase **e** depois "23/30"
e "CAMPANHA" soltos.

**A contagem por capítulo passou a ser usada.** `CampaignChapter.starTotal` e
`CampaignRecords.starsInChapter` ficaram um bom tempo escritos sem nenhum
consumidor — foram feitos para esta leitura e pararam no meio do caminho.
Agora alimentam a barra de estrelas do capítulo no cartão de vitória
(`presentation/widgets/victory_dialog.dart`). O denominador do **cabeçalho do
mapa** continua sendo o da campanha inteira, e há teste que exige isso: as duas
leituras convivem de propósito, e uma "correção" futura não pode trocar uma
pela outra.

O golden `saga_map.png` foi regravado: o cabeçalho ficou ~11px mais alto e a
trilha desceu junto. O `isolatedDiff` mostrou um deslocamento vertical uniforme
e mais nada — sem sobreposição nem corte —, e foi o que autorizou regravar.

### Dois idiomas: o domínio parou de carregar frase

O jogo passou a suportar **português e inglês**, com o inglês como fallback e o
idioma vindo do sistema — sem seletor manual. O mecanismo é o
`flutter_localizations` + `gen-l10n` do próprio SDK: as chaves viram getters
tipados, então chave inexistente é erro de compilação em vez de texto sumido na
tela do jogador. Foi o critério que descartou `easy_localization`, onde a chave
é string solta e o erro só aparece em runtime.

**O achado que decidiu a arquitetura: texto de jogador morava no `domain`.**
`Objective.description`, `GameLevel.teaches`, `CampaignChapter.title` e o
rótulo de faixa do `EndlessProgression` eram frases prontas na camada de
regras. `AppLocalizations` exige `BuildContext`, e o `domain` é testado sem
árvore de widgets — importar l10n ali obrigaria todo teste de regra de jogo a
montar um `MaterialApp`.

Então o domínio passou a expor **dado estruturado** e a apresentação formata:

| antes (domain) | depois |
|---|---|
| `Objective.description` | `digit`/`count`; a frase sai do plural ICU |
| `GameLevel.teaches` (frase) | `LevelTip` (enum) |
| `CampaignChapter.title`/`label` | `ChapterName` (enum); `label` saiu |
| `EndlessProgression.labelFor` | removido — só os testes o usavam |

Sobrou `Objective.debugLabel`, marcado como dev-facing: o `toString()` e o
relatório de `tool/simulate_economy.dart` precisam dele, e o simulador roda em
`dart run`, fora de qualquer árvore de widgets.

As três conversões vivem num lugar só (`presentation/l10n_labels.dart`, extensão
de `AppLocalizations`) porque o objetivo aparece em três telas — cartão de
início, HUD e rótulo semântico do pin. Duplicar o `switch` faria o cartão
prometer uma coisa e o HUD outra ao primeiro ajuste de texto.

**O template ARB é o inglês, não o português.** Sendo o fallback, uma chave que
exista só no template ainda tem valor para exibir em qualquer locale. Com o
template em `pt`, uma chave nova sem tradução apareceria em português para um
jogador de qualquer país.

**Plural em ICU, nunca concatenação.** "1 Movimento"/"N Movimentos" e "Crie 3
peças 5" resolvem no ARB. Um `count == 1` em Dart fixaria a regra do português
— e há teste que exercita exatamente o ramo singular ("1 Move", não "1 Moves").

**A suíte fixa o locale, e isso não é detalhe.** Sem `locale: kTestLocale`, as
asserções em português passariam a afirmar algo sobre o **locale da máquina**:
a mesma suíte passaria neste Mac e quebraria numa CI configurada em inglês, sem
que nada do jogo tivesse mudado. Os testes montam o `MaterialApp` com os
delegates à mão ou usam `localizedApp` (`test/support/localized.dart`).

**O que nenhum teste de widget veria, e por isso existe
`test/l10n/arb_consistency_test.dart`:** uma chave que falte em `app_pt.arb`
compila, roda e simplesmente entrega a frase em inglês ao jogador brasileiro —
sem erro, sem aviso. E a suíte, rodando em português com o texto vindo da mesma
fonte, não acusaria nada. O teste lê os dois `.arb` **como arquivos** e exige
conjunto de chaves idêntico e nenhum valor vazio.

`test/l10n/english_screens_test.dart` cobre a outra metade: as asserções vêm em
par — o texto inglês aparece **e** o português não. Só a primeira metade
deixaria passar um widget que mostrasse os dois.

**"Endless" continua restrito ao código.** Em português o jogador lê "Modo
Recorde"; em inglês, "High Score Mode". Há teste que exige que a palavra nunca
apareça na tela em nenhum dos dois idiomas.

**Ficou de fora, de propósito:** `debugPrint` de falha de disco, `toString()`
de modelo e `tool/simulate_economy.dart`. São texto de desenvolvedor.

**Mudança de UI que veio junto.** `chapterComingSoon` ("Capítulo 2: Em Breve!")
não existia — os nós projetados do mapa eram só cadeados, e cadeado é o que o
pin de uma fase ainda fechada também mostra. O rótulo é o que transforma o fim
da trilha em promessa de continuação. Fica fora de `_FuturePin` porque aquele é
`ExcludeSemantics`: anunciar um nó projetado como fase daria a entender que há
algo para abrir, enquanto o rótulo é informação legítima para um leitor de tela.

Os goldens **não** precisaram ser regravados: o rótulo cai acima da região que
`saga_map.png` captura, e nenhum outro texto mudou de tamanho em português.

Para regerar após mexer num ARB: `flutter gen-l10n`.

### Ícones de loja

Tudo nasce de `assets/images/logo.png` (1024², com cantos arredondados e
transparentes). Dois passos:

```
dart run tool/prepare_icons.dart   # mestres a partir do logo
dart run flutter_launcher_icons    # recorta todos os tamanhos nativos
```

**Por que existe o passo intermediário.** O logo serve para a UI, mas não para
as lojas:

- **iOS não aceita transparência** em ícone de app — a Apple recusa o envio. O
  mestre `assets/icon/app_icon.png` é o logo achatado sobre a cor de fundo,
  num quadrado opaco. O arredondamento quem aplica é o sistema.
- **Android 8+ usa ícone adaptativo**, com frente e fundo separados, e recorta
  a frente em círculo, quadrado ou outras máscaras conforme o aparelho.
  `app_icon_foreground.png` traz a arte encolhida para a zona segura central
  (66%); mandar o logo inteiro faria o recorte comer as bordas.

A cor de fundo (`#080810`) **não é escolhida à mão**: a ferramenta acha a cor
opaca mais frequente do logo, agrupando em faixas para o degradê não virar
milhares de cores distintas. Adivinhar deixaria emenda visível entre o canto
preenchido e o fundo original.

**O que sai:** 21 PNG para iOS (20 a 1024, nenhum com alfa — há verificação),
5 densidades Android (48 a 192) mais as camadas adaptativas, e os ícones web.
Em `dist/store/` ficam os dois que **nenhuma ferramenta de build produz**,
porque são enviados à parte no console de cada loja: o 512² da ficha da Play
Store e o 1024² da App Store.

Os mestres em `assets/icon/` são derivados e não devem ser editados à mão.
Também **não** são declarados no `pubspec`: as ferramentas os leem do disco, e
declará-los só engordaria o app com imagens que ele nunca carrega.

### Falso fim de jogo: era a frase, não o algoritmo

Relato: na fase 6 o cartão dizia "Os movimentos acabaram" com o tabuleiro cheio
de combinações à vista. A suspeita levantada foi de `hasValidMoves` retornando
`false` indevidamente.

**Não era.** A fase 6 tem 45 movimentos e objetivo "crie um 6". Gastar os 45 sem
conseguir é derrota **por saldo**, e o tabuleiro naturalmente continua jogável.
O comportamento estava certo; a frase é que se lia como "não há mais jogadas".

O motor foi verificado, não presumido: um teste compara `hasValidMoves` com uma
**varredura exaustiva das 4 direções** em cada uma das 64 células, sobre 200
tabuleiros — recém-gerados e já jogados. Nunca divergiram. Isso também justifica
a otimização de percorrer só direita e abaixo: trocar `(a,b)` é a mesma jogada
que trocar `(b,a)`, então varrer duas direções por célula cobre todo par
adjacente exatamente uma vez.

**A causa real era de arquitetura:** o estado registrava apenas
`GameStatus.lost`, e a UI **deduzia** o motivo por `movesLeft == 0`. Agora existe
`LossReason` (`moveLimitReached` | `boardStuck`), preenchido pelo notifier, que é
quem sabe. As duas condições são apuradas separadamente e uma nunca substitui a
outra.

As mensagens deixaram de ser ambíguas:

| causa | título | frase |
|---|---|---|
| saldo | "Movimentos esgotados" | "Você usou os N movimentos da fase. Ainda havia jogadas no tabuleiro — faltou alcançar o objetivo." |
| travamento | "Tabuleiro travado" | "Sem jogadas válidas no tabuleiro: nenhuma troca formava combinação." |

Testes de regressão: derrota por saldo **exige** que o tabuleiro continue com
jogada válida e com dica disponível; e um teste compara os dois textos lado a
lado para garantir que "Sem jogadas válidas" nunca apareça na derrota por saldo.

### O rosa que virava vermelho

Relato de aparelho: o `0` (vermelho) e o `6` (rosa choque) se confundiam. Eles
estavam a 21° de matiz um do outro — mas matiz sozinha engana, porque o olho não
separa vermelho de rosa com a mesma régua com que separa azul de ciano. Medindo
em Lab (CIE76), o par saía a **ΔE 32**, o terceiro menor da paleta.

O `6` foi para **rosa neon** (`0xFFFF3DA5`): ΔE 57 do vermelho e ΔE 47 do roxo
do `5`, o vizinho do outro lado — afastar de um lado só teria trocado uma
colisão por outra. Ele fica mais claro e mais saturado que o vermelho, então a
separação não depende apenas da matiz.

**A régua virou teste** (`test/core/constants/palette_distance_test.dart`): a
distância perceptual dos dois pares é um piso executável, e uma volta à
vizinhança antiga reprova. O ΔE está calculado no próprio teste, sem
dependência nova.

Os dois menores ΔE da paleta continuam sendo conhecidos e aceitos: `3`/`9`
(ΔE 9, amarelo e dourado — separados pelo degradê diagonal, halo e contorno,
como descrito em "A peça ápice") e `1`/`8` (ΔE 30, azul e índigo), que ninguém
relatou.

**Goldens regravados:** `board.png`, `game_hud.png`, `game_hud_urgent.png` e
`level_outcome.png`. O `isolatedDiff` mostrou só as peças `6` (e os confetes que
usam `digit6` no cartão de vitória, 0,04%) — foi o que autorizou regravar.

### Contraste do número: por que o branco é uniforme

Revisão de UI/UX apontou que texto preto em umas peças e branco em outras
quebra a hierarquia visual. A correção pedida — branco em todos, com `Shadow`
— **quebraria a legibilidade**: sombra não altera razão de contraste.

Medições (WCAG, texto branco sobre a peça):

| dígito | 3 (amarelo) | 9 (prateado) | 4 (laranja) | 7 (ciano) |
|---|---|---|---|---|
| branco | **1,40:1** | **1,15:1** | **2,37:1** | **2,74:1** |

O mínimo para texto grande é 3:1. A revisão estava certa de que **havia** um
problema — mas o problema real era outro: o laranja e o ciano **já usavam
branco abaixo do mínimo**, porque a regra era `luminância > 0.5`, frouxa demais.

Descartada também a alternativa de escurecer a paleta até o branco passar
sozinho: custaria **32% da luz do amarelo** (virando um oliva sujo) e **48% da
do prateado**, apagando as duas cores mais distintivas de um jogo em que a cor
**é** o identificador.

**Solução adotada:** branco uniforme com **contorno escuro** (`kDigitOutline`),
duas camadas de `Text` — traço embaixo, preenchimento em cima. É a técnica de
legenda de vídeo e rótulo de mapa: texto claro sobre fundo imprevisível.

O invariante testado não é "o contorno contrasta com tudo" — num fundo escuro
ele não contrasta, e nem precisa, porque ali quem faz a leitura é o branco. É
**ou o branco ou o contorno** passar em 3:1. Há também um teste que fixa o
*motivo* do contorno existir: se o amarelo ou o prateado deixarem de precisar
dele, avisa para revisar.

Custo aceito: no `9` prateado o branco com contorno lê como numeral vazado —
legível e distintivo, porém mais leve que os demais. Escurecer o prateado
resolveria, ao preço do "branco/prata brilhante" que o design pede.

### Realce contido na célula

O destaque de seleção e de dica usava `BoxShadow` branco com `spreadRadius` —
e `BoxShadow` desenha **fora** da caixa. A mancha invadia as células vizinhas e
parecia defeito de renderização, não destaque.

Agora é contido: borda interna (`strokeAlignInside`) mais um salto de escala
(1,08 na seleção, 1,03 na dica). Há teste que reprova qualquer sombra com
`spreadRadius` positivo na peça.

### Acabamento visual

Motivado por um teste com outra pessoa: ela pegou o jogo e jogou **sem
perguntar nada** — a mecânica se explica sozinha —, mas o visual era de
protótipo.

**Peças com volume.** Degradê vertical (clara em cima, escura embaixo), reflexo
especular na metade superior, sombra projetada e relevo no número. São 64
objetos ocupando a tela inteira, então é onde o ganho aparece. Cor chapada é o
que mais denunciava o protótipo.

Cuidado ao mexer aqui: **não introduzir `Opacity` nem `FadeTransition` dentro
de `TileWidget`**. Os testes de saída de peça e de clarão de combinação grande
usam esses tipos como marcadores e passariam a encontrar mais de um. Use
degradês e cores com alfa.

**Nada de `shadows:` no `Text` da peça.** Custou um bug difícil: a peça vive
dentro de `AnimatedPositioned` + `Transform.translate` + `ScaleTransition`, e o
Impeller rasteriza a sombra de texto **fora** dessas transformações. As sombras
das 64 peças se acumulavam no canto superior esquerdo do tabuleiro como dígitos
escuros e borrados — parecia corrupção de memória.

Dois aprendizados desse episódio:
- **Nenhum teste pegaria.** O golden renderiza por outro caminho, sem Impeller;
  o artefato só aparece em aparelho ou simulador. Para bug de renderização, a
  captura de tela é o instrumento, não a suíte.
- **A primeira hipótese estava errada.** Culpei o rastro de saída de peça e
  "consertei" algo que não era a causa (a guarda de tabuleiro substituído em
  `_trackDepartures` é correta e ficou, mas não tinha relação). O que resolveu
  foi ampliar a captura: os fantasmas eram só os **dígitos**, sem o fundo
  colorido da peça — se fossem rastro, viriam com a peça inteira.

O relevo do número vem do peso da fonte (w900) e do contraste com o degradê.

**Referência visual em golden.** `board_golden_test.dart` renderiza o tabuleiro
com a paleta inteira e grava `goldens/board.png`. Serve para inspecionar o
acabamento sem aparelho e para travar regressão de sombra, degradê ou raio de
canto. Duas armadilhas: a fonte do `pubspec` **não** é carregada
automaticamente em teste (sem `FontLoader` cada glifo vira um retângulo cheio e
o golden fica inútil), e a comparação é pixel a pixel, então depende da versão
do Flutter e do renderizador de fontes da máquina — daí a tag `golden` em
`dart_test.yaml`, que permite `--exclude-tags golden` em outro ambiente.

**Tipografia empacotada.** Nunito vive em `assets/fonts/`, não é baixada em
runtime. O `google_fonts` estava no pubspec sem nenhum uso e foi removido: ele
busca a fonte da rede na primeira execução e, offline, cai em silêncio no padrão
do sistema — o jogo mudaria de cara sem aviso. A licença OFL acompanha os
arquivos e é registrada em `AppFonts.registerLicense()`, como a licença exige de
quem redistribui. Há teste para cada uma dessas condições, inclusive para o
`google_fonts` não voltar.

### Gesto e tamanho da célula (feedback de aparelho real)

**Arrastar é o gesto principal**, o toque duplo virou alternativa. O padrão do
gênero é deslizar o dedo, e exigir dois toques confunde quem já tem o movimento
na memória muscular. Um arraste vale **uma** troca só (`_dragResolved`): sem
isso, manter o dedo pressionado dispararia trocas em sequência. O eixo dominante
decide a direção, e o limiar é um terço da célula — curto para responder rápido,
longo para não ler tremor de dedo como intenção.

**O alvo de 44pt é inalcançável em tela pequena, e isso é geometria.** Oito
células de 44pt somam 352pt; numa tela de 375pt não sobra margem. Apertar
padding (4) e gap (3) e dar ao tabuleiro margem lateral menor que o resto da
tela recuperou ~3pt por célula:

| aparelho | antes | agora |
|---|---|---|
| iPhone SE (375) | 37,9pt | 41,2pt |
| iPhone 15/16 (393) | 40,1pt | 43,5pt |
| iPhone 16 Pro (402) | 41,2pt | 44,6pt |
| Pro Max (430) | 44,8pt | 48,1pt |

Os dois primeiros seguem abaixo do alvo. O arraste é a mitigação real: ele
derruba a exigência de precisão, porque o dedo pousa em qualquer ponto da peça
e o que importa é a direção. Reduzir o tabuleiro para 7x7 resolveria de vez,
mas invalidaria toda a calibragem das fases.

Os testes registram isso em vez de esconder: um exige que nenhuma largura
disponível seja desperdiçada (é o que o layout controla), outro fixa o alvo de
44pt onde ele cabe, e um terceiro **documenta que no SE fica abaixo** — se a
situação mudar, ele avisa.

**Nota para quem for testar animação aqui:** `getSize` e o `getTopLeft` do nó
externo não enxergam nada disso. Escala e translação são aplicadas na pintura,
então o `RenderTransform` continua no slot e só o filho se move. Medir posição
exige descer até o widget da peça (`tileCorner` no teste); medir escala exige ler
`ScaleTransition.scale.value`.

---

### Fase 6: Modo Endless ✅ Completa
**Objetivo:** dar continuação à campanha, valendo recorde.

A partida não tem objetivo nem limite de movimentos: dura até não haver mais
troca que forme combinação. Travar **não é derrota** — é o placar fechando, e é
o que dá sentido ao recorde. Destrava ao concluir a fase 5, e vencer a fase 10
passa a oferecer o Endless em vez de terminar em nada.

**A janela de sorteio sobe** conforme o jogador cria um dígito dois níveis acima
do topo da faixa atual (`EndlessProgression`): 0-3 → 1-4 → 2-5 → 3-6. O ritmo é
ditado por habilidade, não por tempo.

**Quatro estratégias de janela foram medidas** (`--mode=endless --games=12
--moves=1500`) antes de escolher:

| estratégia | trava | duração | maior dígito | pontos |
|---|---|---|---|---|
| fixa 0-3 | 12/12 | 274 mov | 7 | 15.070 |
| **deslizante 0-3→3-6** | 8/12 | **469 mov** | **9** | **57.630** |
| alargando 0-3→0-6 | 12/12 | **90 mov** | 8 | 5.300 |
| deslizante lenta 0-3→2-5 | 12/12 | 340 mov | 8 | 21.910 |

**Alargar a janela é três vezes pior que não fazer nada.** A intuição de que
"toda peça precisa de fornecimento" está errada: com 7 valores na janela, juntar
três iguais fica raro, há menos fusões, menos peças saem, e o tabuleiro entope
de variedade em 90 movimentos. A janela precisa ser **estreita** — quatro
valores é quase o limite. Isso está fixado no teste `a janela tem sempre quatro
valores`.

A janela para em 3-6 de propósito: com o topo em 7 ou mais, o dígito máximo
cairia pronto do sorteio e explodiria sem mérito do jogador.

**Robustez:** ler ou gravar o recorde nunca impede de jogar. Se o armazenamento
falhar, a partida começa com recorde zero — coberto pelo teste `falha de
armazenamento não trava a tela no carregamento`, que antes ficava preso num
indicador de carregamento infinito.

---

### Fase 7: Persistência ✅ Completa

`GameStorage` (`providers/game_storage.dart`) guarda as duas únicas coisas que
o app precisa lembrar entre aberturas: o avanço na campanha e o recorde do
Endless. Uma interface só, porque é uma preocupação só; `InMemoryGameStorage`
existe para os testes não dependerem de disco nem de plugin de plataforma.

Duas armadilhas que os testes fixam:
- **A leitura é assíncrona.** O menu abre com progresso zero e se atualiza
  quando o valor chega. Se o jogador concluir uma fase antes de o disco
  responder, o valor lido **não** pode sobrescrever o mais recente — daí o
  `if (saved > state)`, coberto por `a leitura tardia não apaga um avanço feito
  antes dela`.
- **Falha de disco nunca bloqueia.** Ler falhou? Vale como "nada salvo".
  Gravar falhou? Registra no log e segue. Perder progresso é ruim; impedir de
  jogar é pior.

**Calibragem das fases** (taxa de sucesso do jogador automático guloso, por
limite de movimentos — `--mode=phases --games=40`):

| objetivo | 10 mov | 15 mov | 20 mov | 25 mov | 30 mov | 40 mov | 60 mov |
|---|---|---|---|---|---|---|---|
| criar um 4 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| criar um 5 | 85% | 95% | 100% | 100% | 100% | 100% | 100% |
| criar 2x5 | 38% | 75% | 90% | 98% | 98% | 100% | 100% |
| criar 3x5 | 8% | 33% | 57% | 83% | 90% | 98% | 100% |
| criar um 6 | 0% | 3% | 8% | 18% | 43% | 65% | 100% |
| criar 2x6 | 0% | 0% | 0% | 0% | 3% | 13% | 70% |
| criar um 7 | 0% | 0% | 0% | 0% | 0% | 0% | 0% |

Alvo de 70-90% de aprovação. O `7` é inalcançável na janela 0-3 em qualquer
limite razoável — daí as fases 8+ subirem a janela em vez de dar mais
movimentos. Como `spawn 1-4 + alvo 7` tem a mesma dificuldade de
`spawn 0-3 + alvo 6` (invariância provada em teste), a campanha alcança o 9
reaproveitando dificuldades já calibradas.

**Validação da campanha como está no app** (`--mode=campaign --games=40`,
cada fase jogada com o seu objetivo, limite e janela):

| fase | objetivo | spawn | limite | vitórias | mov (mediana) |
|---|---|---|---|---|---|
| 1 | criar um 4 | 0-3 | 6 | 100% | 1 |
| 2 | criar 3x4 | 0-3 | 10 | 100% | 3 |
| 3 | criar um 5 | 0-3 | 12 | 88% | 7 |
| 4 | criar 2x5 | 0-3 | 18 | 85% | 12 |
| 5 | criar 3x5 | 0-3 | 26 | 85% | 18 |
| 6 | criar um 6 | 0-3 | 45 | 73% | 29 |
| 7 | criar 2x6 | 1-4 | 20 | 90% | 12 |
| 8 | criar um 7 | 1-4 | 45 | 73% | 29 |
| 9 | criar um 8 | 2-5 | 45 | 73% | 29 |
| 10 | criar um 9 | 3-6 | 45 | 73% | 29 |

As fases 6, 8, 9 e 10 saem com taxa e mediana **idênticas** — é a invariância
da janela de spawn se confirmando no catálogo real. As fases 1 e 2 têm limite
decorativo (mediana 1 e 3 contra 6 e 10): funcionam como tutorial, mas a
tensão só começa na fase 3.

A curva admite **um respiro**: a fase 7 é de propósito mais fácil que a 6
(90% contra 65%), porque vem depois da primeira fase longa e estreia a janela
subindo. O teste `a campanha sobe, admitindo respiro de no máximo um degrau`
permite isso mas impede a dificuldade desabar, e exige que o pico esteja no fim.

Nota sobre a janela: amarrá-la ao maior dígito **em tela**, como sugerido no
brief, tem efeito colateral — uma única peça alta cortaria o fornecimento
das peças baixas que a alimentam, e o corte desapareceria de repente quando
ela fundisse. Amarrar à **fase** dá a mesma progressão sem a oscilação.

---

### Fase 5: Polimento & UX
**Objetivo:** Melhorar feel e responsividade.

**Tarefas:**
- Animações: queda das peças, fade na eliminação, bounce na evolução,
  volta da troca recusada (`rejectedSwap` já está no estado), brilho no `9`
- Explosão do dígito 9 (hoje a combinação é apenas consumida)
- Feedback tátil e sons com toggle
- Tela inicial, pausa/resume, tela de fim de jogo
- Responsividade para telas variadas

---

## Mecânica do MVP (Fase 1)
1. Matriz de tamanho 8x8.
2. Inicialização do tabuleiro apenas com números de `0` a `3` para facilitar os primeiros movimentos.
3. Troca de blocos adjacentes (drag & drop ou tap consecutivo).
4. Processo do Match:
   - Detecção de 3+ em linha/coluna.
   - Fusão dos blocos no ponto de interação (origem da troca/centro).
   - Animação de eliminação dos demais blocos.
   - Gravidade: peças acima caem preenchendo os espaços vazios.
   - Novas peças geradas no topo (priorizando números menores).
5. Loop de game over quando não houverem mais movimentos possíveis.

### Regras Invioláveis de Gameplay & Condições de Vitória/Derrota

1. **Separação Rígida dos Condicionais de Fim de Jogo:**
   - **Saldo de Movimentos da Fase (`movesRemaining == 0`):** Aplica-se exclusivamente ao modo Campanha/Fases. Quando atinge zero sem cumprir o `Objective`, o status é `GameStatus.lost` com mensagem expressa sobre **limite de movimentos da fase esgotado**.
   - **Tabuleiro Sem Jogadas Válidas (`hasValidMoves == false`):** Aplica-se quando o `MatchEngine.findHint(board)` não encontra nenhuma troca possível que resulte em Match-3+.
   - **Navegação do Notifier:** NUNCA sobrescreva `hasValidMoves` com a contagem de `movesRemaining` e NUNCA dispare alerta de "sem jogadas possíveis" se o tabuleiro possuir combinações ativas.

2. **Integridade dos Algoritmos de Match (`MatchEngine`):**
   - O método `findHint` e `hasValidMoves` devem testar rigorosamente todas as 4 direções de troca (cima, baixo, esquerda, direita) em cada célula do grid 8x8 antes de declarar o tabuleiro travado.
   - Qualquer refatoração nas regras de fusão (`FusionRule`) ou detecção de match EXIGE a execução da suíte de testes de regressão do `MatchEngine`.


## Regras de UX, Recompensas e Fluxo de Partida

1. **Jornada do Nível (Pre-Game & Post-Game):**
   - Toda fase da campanha DEVE apresentar o `LevelStartDialog` com o objetivo e limite de movimentos claros antes do primeiro toque do jogador.
   - A vitória DEVE premiar o jogador com avaliação de 1 a 3 Estrelas e atalho direto para a "Próxima Fase".

2. **Recompensa Inviolável do Dígito 9:**
   - O dígito `9` é o ápice da fusão. A sua criação OBRIGATORIAMENTE deve disparar:
     * Explosão de limpeza de área no tabuleiro.
     * Feedback tátil forte (`heavyImpact`).
     * Recompensa de +3 movimentos de bônus na Campanha.
     * Efeito visual de destaque (partículas/glow).

3. **Clareza de Status no Fim de Jogo:**
   - NUNCA use a mesma mensagem para derrota por saldo de movimentos e derrota por travamento de tabuleiro. As telas e textos devem ser estritamente distintos para não confundir o jogador.
 - ## Arquitetura de Balanceamento (Inspirada em Match-3 Padrão)

1. **Largura Fixa da Janela de Spawn ($W = 4$):**
   - Para manter a taxa de cascata alta e evitar que o tabuleiro entupa, a janela de novos blocos que caem no topo DEVE ter sempre exatamente 4 valores possíveis (ex: `0..3`, `1..4`, `2..5`, `3..6`).
   - NUNCA alargue a janela para 5 ou mais valores simultâneos no mesmo nível, pois isso reduz drasticamente a probabilidade de fusão e destrói o ritmo do jogo.

2. **Métrica de Eficiência de Fase:**
   - Toda nova fase criada na Campanha deve respeitar a taxa de eficiência:
     $$\text{Eficiência} = \frac{\text{Objetivo}}{\text{Movimentos}}$$
   - Fases balanceadas exigem taxas de eficiência em que a criação do número alvo seja atingível em 70% a 90% das partidas simuladas por bot guloso.

## Arquitetura Visual e Metagame (Saga Pattern)

1. **Design de Mapa de Fases (Inviolável):**
   - A seleção de fases da campanha NUNCA deve ser exibida como uma lista vertical de cards planos ou checklist.
   - DEVE utilizar a representação visual de **Saga Map** (caminho conectando os pins de fase com status de 1 a 3 estrelas por nível).

2. **Hierarquia do Modo Endless:**
   - O modo Endless é o motor de retenção infinita. Ele NUNCA deve ser tratado como uma fase comum de número 0 ou 1.
   - Deve possuir destaque visual próprio no mapa com exibição persistente do Recorde Pessoal do jogador.

3. **Feedback de Progresso (Stars & Metagame):**
   - Todo nível concluído calcula e armazena o histórico de Estrelas (1 a 3). O progresso total de estrelas da conta DEVE ser exibido de forma proeminente no cabeçalho do mapa.

## Regras de Interface de Gameplay (HUD & Feedback)

1. **Economia de Espaço do HUD:**
   - Textos explicativos de tutorial NUNCA devem ocupar espaço permanente no HUD durante toda a partida. A área nobre do HUD é reservada para Objetivos, Movimentos e Progresso.

2. **Indicadores de Urgência e Metas no Endless:**
   - Quando restarem 3 ou menos movimentos na Campanha, o contador DEVE piscar/pulsar em vermelho.
   - No modo Endless, as métricas do topo devem usar termos inequívocos (`Pontos`, `Recorde` e `Maior Bloco`).

## Diretrizes de UI/UX para o Saga Map

1. **Continuidade Infinita do Mapa:**
   - O mapa de fases NUNCA deve terminar abruptamente no último nível jogável. Ele DEVE sempre exibir nós e caminhos futuros bloqueados/pontilhados para transmitir expansão contínua.
2. **Scroll Clean e Masking:**
   - Componentes que fluem por baixo de banners fixos do HUD DEVEM utilizar gradientes de fade-out para evitar cortes secos de renderização (clipping).

## Identidade Visual e Feedback de Peças Especiais (Diga Não a Blocos Invisíveis)

1. **Peça Apex (O Número 9):**
   - O número 9 é o objetivo máximo do motor de jogo. Ele NUNCA deve ser renderizado como um bloco plano ou branco que perca o contraste com o texto.
   - DEVE obrigatoriamente possuir estilo visual de "Recompensa Lendária" (gradiente especial, texto destacado e iluminação/glow sutil).

2. **Celebration Feedback:**
   - Eventos de conquista máxima no modo Endless (gerar o 9 ou atingir a faixa máxima de spawn) DEVEM acionar animações de feedback imediato (efeito de pulso no HUD, haptic e mensagem flutuante de celebração).

## Nomenclatura e Linguagem para o Jogador Casual

1. **Evitar Termos de Dev/Inglês Técnico:**
   - O modo sem limite de movimentos DEVE ser chamado de **"Modo Recorde"** na interface do jogador.
   - O termo "Endless" deve ser restrito internamente ao código/enum/domain (`EndlessModeEnum` / `endless_page.dart`), mas NUNCA exibido textualmente na UI em português.


## Regras de Internacionalização (i18n)

1. **Proibição de Strings Hardcoded:**
   - É estritamente proibido inserir textos de interface (UI) diretamente como `String` literais no código dos widgets.
   - Todo e qualquer texto visível para o usuário DEVE obrigatoriamente utilizar o sistema de internacionalização, fornecendo traduções em Português (`pt`) e Inglês (`en`).


## Diretrizes de Retenção e Psicologia do Jogador (Retention & Flow)

1. **Incentivo à Próxima Ação (Zero-Friction Replay):**
   - O modal de vitória NUNCA deve forçar o jogador a voltar ao menu principal; a ação principal DEVE ser carregar a próxima fase imediatamente.
   - O modal de derrota no Modo Recorde DEVE enfatizar o botão de "Tentar Novamente" para aproveitar o impulso de revanche do jogador.



## Sistema de Progresso por Capítulo (Estrelas & Maestria)

1. **Métrica Primária de Capítulo:**
   - O progresso intra-capítulo exibido em modais (`VictoryDialog`) DEVE focar na **maestria de estrelas** (`starsInChapter / starTotal`) para estimular o replay e engajamento com fases anteriores, enquanto o Saga Map assume o papel de mostrar o progresso linear de fases.