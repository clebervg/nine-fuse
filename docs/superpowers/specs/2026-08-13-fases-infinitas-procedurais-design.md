# Fases Infinitas Procedurais (`LevelGenerator`)

**Data:** 2026-08-13
**Estado:** desenho aprovado, pronto para plano de implementação

## Problema

O mapa da campanha termina na fase 10 e exibe o cartão "Capítulo 3: Em Breve!".
Para o jogador, isso lê como "o jogo acabou" — é o ponto de churn mais caro de um
jogo de puzzle mobile, porque quem desinstala ali raramente volta quando o
conteúdo novo sai.

## Escopo

Apenas a geração procedural de fases (Pilar A do parecer de design). **Fora de
escopo, e deliberadamente:** leaderboard semanal com matchmaking, desafio diário
global e New Game+ / dificuldade Master. Os dois primeiros exigem backend, contas
de jogador e sincronização, o que contraria a diretriz de jogo 100% offline
registrada no `CLAUDE.md`. Cada um vira spec próprio se e quando houver servidor.

O Modo Recorde (Endless) **não é tocado**. Ele já é a corrida infinita do jogo;
o que este trabalho entrega é a *campanha* infinita, que é outra coisa: fases com
objetivo e limite de movimentos, na trilha.

## Decisões de design

### O que o `levelId` determina

O número da fase determina **o contrato da fase** — objetivo, limite de
movimentos, janela de spawn, quantidade e dureza das coberturas — e nada além
disso. Iguais para todo jogador, sempre.

O **tabuleiro inicial continua sorteado a cada tentativa**, como hoje. O parecer
original pedia `seed = levelId` semeando também o grid, mas isso reverteria uma
decisão já registrada na Fase 13 do `CLAUDE.md` ("guardar posições fixas tornaria
toda tentativa da fase idêntica, e a campanha do NineFuse é procedural"). Com
tabuleiro fixo, repetir uma fase perdida vira decorar a solução em vez de
resolver o problema de novo.

### Por que a dificuldade não escala pelo alvo

O parecer propunha `targetScore` crescendo para sempre. O NineFuse não tem fase
por pontuação: os objetivos são `reachDigit`, `clearObstacles` e
`clearAllObstacles`, e o dígito trava em `kMaxDigit` (9). A partir da fase ~10 o
alvo já é o máximo possível.

Criar um `ObjectiveType.reachScore` foi considerado e descartado nesta rodada:
adiciona superfície ao domínio, ao HUD e ao cartão de desfecho para resolver um
problema que os eixos existentes já resolvem.

A dificuldade infinita vem, então, de quatro eixos que **não** têm teto natural
ou cujo teto é alto: `count` (formar N vezes o dígito alvo), `moveLimit`,
quantidade/dureza de coberturas, e a janela de spawn.

### Como o infinito aparece ao jogador

Continuação transparente. As fases 11+ são pins numerados normais, na mesma
trilha, geradas conforme o jogador rola. O jogador nunca vê a costura entre
artesanal e procedural, e o cartão "Em Breve" deixa de existir.

## Arquitetura

### `domain/level_catalog.dart` — a costura

```dart
GameLevel levelAt(int number);   // 1..10 → kCampaign; 11+ → LevelGenerator.generate(number)
```

`kCampaign` continua existindo, intacto e calibrado, como as dez fases
artesanais. Tudo que hoje indexa a lista passa a chamar `levelAt`.

`GameLevel` **não muda**. O gerador produz o mesmo tipo que a lista produz, então
`MatchEngine`, `GameNotifier`, HUD, cartão de desfecho e mapa não sabem se a fase
que receberam foi escrita à mão ou calculada. A única coisa que sai do código é a
suposição de que a campanha tem fim.

### `domain/level_generator.dart` — o gerador

Classe pura, sem estado, sem I/O, sem `Random` de instância. Dado um `number`,
devolve sempre o mesmo `GameLevel`.

`GameLevel` impõe três invariantes que a fórmula respeita **por construção**, não
por sorte: janela de largura fixa (`kSpawnWidth`), `spawnMin >= 0`, `spawnMax <
kMaxDigit`. Logo `spawnMin` varia de 0 a 5 — seis degraus, e o topo é o degrau em
que o 9 é alvo. Some-se a invariante do catálogo (o dígito-alvo fica **acima** da
janela, senão cai pronto do topo e a fase vira sorte em vez de plano).

A progressão, portanto, não é uma reta: é um degrau que sobe até o teto e depois
cicla, com a dificuldade continuando a subir pelos outros eixos.

Quatro funções puras de `number`, cada uma testável sozinha:

- **`_spawnMinFor(n)`** — sobe um degrau a cada 10 fases, satura em 5 e volta a
  2. Nunca volta a 0: o `0` parar de cair é uma conquista da fase 7, e devolvê-lo
  regrediria a sensação de progresso.
- **`_objectiveFor(n)`** — cicla os três tipos por posição dentro do bloco de 10:
  sete fases de dígito, duas de `clearObstacles`, uma de `clearAllObstacles` como
  fecho de capítulo. O alvo é `spawnMax + 1` ou `+2`. O `count` cresce com o
  bloco, e é ele que carrega o infinito quando o dígito satura em 9.
- **`_movesFor(n)`** — base por arquétipo de objetivo (uma fase de `count: 3`
  precisa de cerca de 3× a de `count: 1`), com aperto percentual limitado por um
  **piso**: um limite que encolhe para sempre chega a zero.
- **`_obstaclesFor(n)`** — quantidade e dureza crescendo por bloco, com **teto**:
  mais pedra do que o tabuleiro comporta faz `placeObstacles` descartar em
  silêncio, e a fase pedida deixa de ser a fase jogada.

Todos os valores numéricos entram como constantes nomeadas no topo do arquivo, e
são fixados pela simulação (ver Calibragem), não escolhidos a olho.

### Capítulos

`chapterOf(int)` passa a **gerar** capítulos além do segundo, um a cada 10 fases,
com nome vindo de uma lista cíclica de `ChapterName`. Nomes se repetem lá na
frente, e isso é aceitável; o número do capítulo, não.

### Mapa: a lista vira janela

`SagaMap` recebe hoje `levels: kCampaign`, e `SagaGeometry` mede tudo por
`levelCount`. Uma lista infinita não existe em memória, e não precisa existir: o
mapa monta `List.generate(_visibleCount, (i) => levelAt(i + 1))`, com
`_visibleCount = max(progress + kLookahead, kCampaign.length)`, com `kLookahead =
8` (mais de uma tela de pins à frente, para a extensão nunca ser percebida como
carregamento). Ao rolar até o
topo do que existe, a contagem cresce e a trilha continua. O jogador nunca
alcança um fim, e nunca alocamos mil fases para mostrar oito.

O cartão `chapterComingSoon` sai do widget e as chaves órfãs saem dos dois ARB.

### Cabeçalho: o denominador vira o capítulo

`kCampaignStarTotal` é `kCampaign.length * kStarsPerLevel` — sem sentido sem
`length`, e uma barra de progresso não pode ter denominador infinito. O
`CampaignHeader` passa a medir o **capítulo atual**: estrelas do capítulo sobre
estrelas em jogo no capítulo. A barra volta a significar "quanto falta para
fechar este trecho" em vez de decair para zero para sempre. `starTotal` continua
sendo o parâmetro; muda quem o calcula.

## Persistência

`campaignProgress` é `int`, sem teto e sem lista para validar contra. Um jogador
na fase 4.000 grava `4000`. Nada a migrar.

**O que precisa de remédio é `levelRecords`.** `readLevelRecords` /
`writeLevelRecords` serializam o `Map<int, LevelRecord>` inteiro numa **única
string JSON** em `SharedPreferences`, reescrita a cada fase vencida. Com campanha
finita isso é irrelevante (dez entradas); com campanha infinita é uma escrita
O(n) por vitória sobre um blob que só cresce.

Remédio adotado: **poda por janela**. Guardar registros detalhados apenas das
últimas `kRecordWindow = 200` fases e, ao podar, somar as
estrelas das fases descartadas num agregado por capítulo. O jogador não perde
estrelas — perde o detalhe por fase de trechos que já ficaram muito para trás, e
que a UI não mostra sem rolar por minutos. O agregado é o que o cabeçalho lê.

Tudo segue offline: o gerador é aritmética pura, e nenhuma requisição de rede é
adicionada.

## Testes

**`level_generator_test.dart`** varre 1..1000 e trava, sobre cada fase gerada, as
invariantes do `GameLevel` e as do catálogo: janela de largura fixa, `spawnMin >=
0`, `spawnMax < kMaxDigit`, `moveLimit > 0` e acima do piso, dígito-alvo acima da
janela, `count >= 1`, coberturas dentro do que o tabuleiro comporta. Trava também
o **determinismo** (duas chamadas com o mesmo número devolvem fases iguais) e a
**continuidade** (a fase 11 não é salto de dificuldade em relação à 10
artesanal).

**`level_catalog_test.dart`** trava a costura: `levelAt(1..10)` idêntico a
`kCampaign`, `levelAt(11)` já gerado, e `chapterOf` numerando capítulos sem
buraco até bem longe.

**Testes de widget:** o mapa não mostra mais "Em Breve"; a trilha estende ao
rolar; vencer a fase 10 leva à 11 em vez de repetir a 10.

**Teste de persistência:** a poda mantém o total de estrelas do capítulo correto
depois de descartar o detalhe por fase.

## Calibragem

`--mode=generated` no `tool/simulate_economy.dart`, amostrando as fases 11, 25,
50, 100, 250, 500 e 1000, com o mesmo jogador automático guloso por fusão e a
mesma meta de 70-90% de vitória usada na campanha artesanal. As constantes do
gerador são ajustadas até a faixa bater.

Duas honestidades registradas desde já:

- O bot **nunca mira cobertura de propósito**, então nas fases de
  `clearObstacles` o número medido é um **piso**, não a taxa real — é a mesma
  limitação já documentada na Fase 14.
- Amostrar sete pontos não prova mil fases. Prova que a curva não descarrila onde
  ela muda de natureza (troca de degrau de spawn, saturação do dígito alvo,
  virada de bloco de objetivo), que são os pontos escolhidos.

## Critérios de aceite

1. `flutter analyze` limpo e `flutter test` verde.
2. O mapa nunca exibe "Em Breve" e permite rolar além da fase 10.
3. Vencer a fase 10 abre a fase 11.
4. `levelAt` é determinístico e válido para 1..1000.
5. `--mode=generated` reporta as sete amostras dentro da meta (com a ressalva do
   piso nas fases de cobertura).
6. Nenhuma requisição de rede foi adicionada.
