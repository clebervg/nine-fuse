# Ajustes de UX: paleta, modal do 9 e campanha de 30 fases

Data: 2026-08-08

Origem: três pontos de atrito relatados em teste com jogadores — confusão
visual entre dígitos, ausência de celebração explícita ao criar o `9`, e
campanha curta que termina sem horizonte.

## Correções ao pedido original

O pedido chegou com três premissas que a exploração do código desmentiu. Elas
ficam registradas porque mudaram o desenho:

1. **`game_colors.dart` não existe.** A paleta mora em
   `lib/core/constants/app_colors.dart`.
2. **`0 = #E53935` e `6 = #D81B60` já são o estado atual.** O pedido literal
   preservaria exatamente o par relatado como confuso. Além disso, medindo em
   Lab, `0`×`6` (ΔE 32,4) **não** é o pior par da paleta: `3`×`9` está em 9,0 e
   `1`×`8` em 29,5. A confusão relatada é de nome de matiz, não de
   discriminabilidade — e há dois pares piores que ninguém relatou ainda.
3. **A celebração do `9` já existe** (`ApexCelebration`) e é não-bloqueante de
   propósito. Os nós travados com cadeado no fim do mapa também já existem
   (`SagaGeometry.futureNodes = 3`), e `kChapters` já tem um "Capítulo 2".

## Decomposição

Três subprojetos, cada um com plano e implementação próprios, nesta ordem:

1. **Paleta redistribuída** — isolado, sem dependências.
2. **Modal de fusão máxima** — depende de expor o bônus de pontos do ápice.
3. **Peças congeladas + 30 fases + capítulos/portal** — dividido em **3a**
   (mecânica, motor, simulador) e **3b** (catálogo calibrado, mapa). A
   calibragem de 3b só existe depois que 3a roda.

---

## 1. Paleta redistribuída

### Método

Busca com três pisos simultâneos, `9` fixo em dourado (é a identidade do ápice
e trava dois goldens):

- distância de matiz ≥ 30°;
- ΔE (CIE76) entre todos os 45 pares;
- ΔE dos mesmos pares **simulado em deuteranopia** (Viénot) — separar por matiz
  sozinho não ajuda quem não distingue vermelho de verde.

### Resultado

| | atual | proposta |
|---|---|---|
| menor ΔE | **9,0** (`3`×`9`) | **28,7** |
| menor ΔE em deuteranopia | **7,3** (`3`×`9`) | **26,0** |
| menor distância de matiz | **3°** (`3`×`9`) | **30°** |

| dígito | cor | matiz | família |
|---|---|---|---|
| 0 | `#CC3914` | 12° | vermelho |
| 1 | `#77E03E` | 99° | verde-lima |
| 2 | `#28F684` | 147° | verde-menta |
| 3 | `#28F6F6` | 180° | ciano |
| 4 | `#338FEB` | 210° | azul |
| 5 | `#0A0AF5` | 240° | azul-cobalto |
| 6 | `#7014CC` | 270° | roxo |
| 7 | `#C11FB1` | 306° | magenta |
| 8 | `#E03E7F` | 336° | rosa |
| 9 | `#FFD700` | 51° | dourado (ápice) |

Sob deuteranopia a paleta atual tem três pares em situação ruim, nenhum deles o
relatado: `3`×`9` (7,3), `5`×`8` (13,2) e `0`×`2` (16,1).

O teste do invariante precisa das fórmulas de Lab, ΔE e da simulação de
deuteranopia **em Dart** — hoje elas só existem no script de exploração. Vão
para um utilitário de teste, não para `lib/`: são instrumento de verificação,
não código de jogo.

A atribuição é uma **rampa**: a cor codifica magnitude, e o dourado quebra a
rampa justamente por ser o ápice. `0`×`6` passa a 258° de distância e ΔE 60.

### Invariante executável

Um teste percorre os 45 pares e reprova qualquer um abaixo dos pisos, em visão
normal e em deuteranopia. Hoje não existe barreira desse tipo — é por isso que
`3`×`9` a 3° passou despercebido por toda a vida do projeto.

A regra do contorno permanece: **ou o branco ou o contorno** passa 3:1 em cada
peça. Verificado para os dez dígitos da proposta.

### Custo aceito

- Contraria o CLAUDE.md em dois pontos, que serão reescritos: a tabela de cores
  e o pedido literal `6 = #D81B60`. O `0` continua vermelho (tom mais quente);
  o `6` deixa de ser rosa e vira roxo.
- Regrava `goldens/board.png` e `goldens/juice_fusion.png`. A autorização para
  regravar vem do `isolatedDiff` mostrar só as peças — nada mais.
- `4` e `5` ficam na família do azul (210° e 240°), `1` e `2` na do verde. É o
  preço do piso de 30° com nove matizes fora do dourado.

---

## 2. Modal de fusão máxima

### Sequência

A explosão roda inteira (clarão, faíscas, `heavyImpact`, `+3 Movimentos`) e só
então o modal abre. Ele entra como mais um quadro da linha do tempo de
`_playResolution`, depois do passo que contém `explosionCentres`.

**Nada de `Future.delayed`** — temporizador solto não respeita o relógio do
teste nem para quando o widget sai de tela. O relógio é o da encenação.

A resolução da cascata **não** é interrompida no meio; ela termina, e o modal
abre sobre o tabuleiro assentado. Interromper no meio deixaria o motor a meio
caminho e é a fonte de bug mais provável deste subprojeto.

### Micro-pausa

Enquanto o modal está aberto, o tabuleiro fica sob `IgnorePointer` e o relógio
da dica não corre — o mesmo mecanismo do `LevelStartDialog`.

### Não é `showDialog`

É mais uma camada do `Stack` da tela. Uma rota por cima tira o tabuleiro da
árvore de foco, complica o teste de widget e obriga a coordenar duas navegações
a cada reinício de fase.

### Conteúdo

- Título: **"SENSACIONAL! FUSÃO MÁXIMA 🏆"**
- Confetes em `CustomPainter` com semente fixa.
- O bônus de pontos do ápice e os `+3 Movimentos`.
- Botão único: **"Continuar Jogando"**.

O botão é único de propósito. "Próxima Fase" só faz sentido quando a fase foi
vencida, e o `9` só é objetivo na fase 10 — vitória continua sendo assunto do
cartão de fim de fase, que já tem estrelas e o atalho para a próxima.

### Campo novo no motor

O motor já pontua o ápice (`kMaxDigit * 100` pela criação, `50` por célula
limpa na explosão), mas soma tudo em `stepScore`. Entra `FusionStep.apexScore`,
derivado em `Resolution` como todo o resto — sem isso não há como exibir "o
bônus gerado pela criação do 9".

### Uma vez por partida

Reusa `apexCelebrated`, com a chave amarrada ao `runId` na campanha (recomeçar
a fase é `playing → playing`). A pílula `ApexCelebration` atual **sai**: os dois
juntos seriam duas celebrações do mesmo evento. O widget é reaproveitado como
corpo do modal (pílula → cartão), mantendo o pintor de confetes.

### Testes

- O modal aparece depois do passo de explosão, não durante.
- O toque no tabuleiro fica bloqueado enquanto ele está aberto, e volta depois.
- Abre nos dois modos (campanha e recorde).
- Não reabre no segundo `9` da mesma partida.
- Reabre ao recomeçar a fase (`runId`).
- O valor exibido bate com `apexScore`.

---

## 3a. Peças congeladas

### A mecânica

A peça congelada é uma peça normal que o jogador **não pode mover**. Ela cai com
a gravidade, conta para combinações e ocupa célula como qualquer outra. O que
muda: a troca com ela é recusada, e ela **descongela ao participar de uma
combinação** em vez de ser consumida. Só na combinação seguinte funde de fato.

Este desenho **não toca em gravidade nem em reposição** — as duas partes do
motor cuja quebra custou mais caro nas fases 3 e 8. Um bloqueador imóvel de
verdade seria um buraco no tabuleiro e obrigaria a reescrever as duas.

### Modelo

- `Tile.frozen` (bool).
- `GameLevel.initialFrozen` (quantas nascem congeladas) e
  `GameLevel.frozenRate` (chance de uma peça nova chegar congelada).
- Nas fases 1-10 os dois são zero: o catálogo atual não muda em nada.

### O risco real é travar o tabuleiro

`findHint` passa a ignorar trocas que envolvam peça congelada — e é ele que
responde `hasValidMoves`. Com densidade alta, a fase morre por
`LossReason.boardStuck` sem o jogador ter errado.

Duas defesas: um teto de densidade imposto por `assert` no `GameLevel`, e o
simulador medindo travamento por fase. Fase que travar acima do aceitável tem o
**número** errado; não se corrige isso no widget.

### Descongelar tem de pagar

Uma combinação que só descongela não evolui nada e gastaria movimento sem
render. Ela pontua (valor menor que uma fusão) e há teste fixando isso — do
contrário o gelo vira imposto puro e a fase fica frustrante em vez de difícil.

---

## 3b. Catálogo de 30 fases, capítulos e portal

### Calibragem

`--mode=campaign` estendido, 40 partidas por fase, meta de **70-90%** de
aprovação por bot guloso — a mesma régua das fases existentes. Os limites saem
da medição, não de escolha a olho. Se uma fase sair fora da faixa, o limite muda
até entrar. A tabela final vai para o CLAUDE.md, como as anteriores.

A janela de spawn das fases 11-30 **recicla os degraus 0-3 a 3-6**: o teto
`spawnMax < kMaxDigit` é inviolável, senão o `9` cairia pronto do sorteio. Quem
cria a progressão dentro do Capítulo 3 é o gelo — `frozenRate` subindo, com
objetivos repetindo dificuldades já calibradas um dígito acima.

### Capítulos

| nº | título | fases |
|---|---|---|
| 1 | Fusões Primárias | 1-6 |
| 2 | Rumo ao Nove | 7-10 |
| 3 | Camada de Gelo | 11-30 |

Os cortes continuam caindo onde o jogo muda de natureza: em 6 a janela de spawn
começa a subir, em 10 entra a mecânica nova.

### Portal

Ao fim da fase 30, um nó de tipo próprio anuncia **"Capítulo 4: Novos Desafios
em Breve!"**. Ele é distinto dos `futureNodes` que já existem — os três círculos
pontilhados com cadeado continuam, **depois** do portal.

`SagaGeometry.lastIndex` passa a contar o portal, senão ele nasce fora da área
rolável (foi exatamente o que aconteceu quando os nós projetados entraram).

Dois cuidados que o histórico do arquivo já registra:

- O portal é `ExcludeSemantics`, como os nós projetados — anunciar fase
  inexistente a leitor de tela dá a entender que há algo para abrir.
- O portal não pode ser filho não-posicionado do `Stack` que mede o pin. É a
  lição da aura e do rótulo: decoração não mede layout.

`goldens/saga_map.png` é regravado.

### Consequência da campanha longa

Com 30 fases a rolagem do mapa fica três vezes mais longa, e a centralização na
fase atual passa a ser o único jeito de o jogador se achar. Ela já existe e já
reage a mudança de progresso — não é trabalho novo, mas passa a ser crítica, e
ganha teste com progresso alto (fase 25+), não só com progresso baixo.

---

## Validação

`flutter analyze` e `flutter test` limpos ao fim de cada subprojeto. Os goldens
regravados só com `isolatedDiff` inspecionado — regravar sem olhar o diff é o
que transforma regressão em "atualização de golden".
