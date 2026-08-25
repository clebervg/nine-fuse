# Peças Especiais: Decaimento Anti-Hoarding e Hard Cap de Cascatas

## Contexto

Pedido do Lead Game Architect para reforçar a economia de recompensa do
`MatchEngine` contra dois riscos: (1) peças especiais nunca implementadas
poderiam, no futuro, ser guardadas indefinidamente pelo jogador em vez de
usadas (anti-hoarding); (2) uma cascata automática longa pode rodar sem
limite prático, já que `_maxCascades = 64` hoje é apenas uma rede de
segurança contra loop infinito, não uma regra de jogo.

Este é o primeiro de quatro sub-projetos decompostos a partir de um pedido
maior (reward system, pity timer/solvabilidade, performance/acessibilidade,
bot solver). Os outros três têm specs próprios, futuros.

**Escopo greenfield:** hoje não existe nenhuma peça especial (curinga,
multiplicador) no código. Este spec entrega a **infraestrutura genérica**
(campo no `Tile`, decaimento, cap de cascata, geração ponderada). O efeito
de jogo concreto de uma peça especial (o que o curinga faz ao fundir) fica
fora de escopo, para um sub-projeto futuro — decisão explícita do usuário.

## Modelo de dados

`Tile` (`lib/features/game/domain/tile.dart`) ganha dois campos opcionais,
seguindo o mesmo padrão já usado para `obstacle`/`obstacleHp`:

```dart
final SpecialTileType? specialType;   // null = peça normal
final int? specialTurnsLeft;          // contador de decaimento, 3 -> 0
```

Novo arquivo `lib/features/game/domain/special_tile.dart`:

```dart
enum SpecialTileType { wildcard }

const kSpecialTileLifespan = 3;
```

`wildcard` é reservado como marcador de extensibilidade — sem efeito de
fusão implementado. Nenhum teste deste spec exercita o que o wildcard faz
ao ser fundido, só o ciclo de vida genérico (nasce → decai → reverte, ou
nasce → funde → some).

Um construtor nomeado `Tile.withSpecial(...)` (análogo a `withObstacle`) é
o único caminho de criação, com `assert` amarrando `specialType` e
`specialTurnsLeft`: os dois são nulos juntos, ou não-nulos juntos, e
`specialTurnsLeft` nasce sempre em `kSpecialTileLifespan`.

## Decaimento (anti-hoarding)

O contador decrementa **uma vez por jogada do jogador**, não por cascata —
uma cascata de 5 passos consumiria os 3 turnos de vida numa jogada só, o
que não corresponde a "3 jogadas do jogador" pedido.

Mecanismo: `MatchEngine` ganha um método `decaySpecials(Board board)`,
chamado uma vez ao final de `tryMove` bem-sucedido (depois de `resolve()`),
que:
1. Para cada `Tile` com `specialType != null`, decrementa `specialTurnsLeft`.
2. Se o resultado é `0`, converte a peça para `Tile` normal do mesmo
   `value` (mesmo nível), via `Tile.withSpecial` removido (volta ao
   construtor padrão).

A conversão emite um `ResolutionStep` próprio (`kind: degrade`, análogo ao
passo de `smash`), contendo as posições degradadas nesse turno — para a UI
poder animar a transição em vez de a peça mudar de aparência sem aviso
entre um frame e outro. Este passo não conta como cascata para o cap da
seção seguinte (não é gerado por match).

**Peça especial nascida de fusão/cascata dentro do próprio turno** decai
normalmente a partir da jogada seguinte — nasceu neste turno, com 3 de
vida; `decaySpecials` só roda depois de `resolve()`, então uma peça que
nasce e já é imediatamente fundida na mesma cascata nunca chega a decair.

## Hard cap de cascatas (regra real, não mais rede de segurança)

`kMaxCascadesPerTurn = 5` substitui o papel de `_maxCascades = 64` como
regra de jogo dentro de `resolve()`. `_maxCascades` permanece como está,
bem mais alto, unicamente como rede de segurança contra bug de loop
infinito — as duas constantes coexistem com papéis diferentes.

Comportamento ao atingir 5 passos com match ainda pendente no tabuleiro:
o loop de `resolve()` para ali. O `Resolution` retornado tem exatamente 5
`steps`. O match remanescente **não é limpo nem perdido** — fica
fisicamente no tabuleiro, congelado, até a jogada seguinte do jogador. A
próxima chamada de `tryMove` (que internamente chama `resolve()` de novo)
processa esse match pendente como o(s) primeiro(s) passo(s) da nova
resolução, antes de qualquer efeito do novo swap ter sido computado —
preservando a invariante "todo match no tabuleiro eventualmente resolve",
apenas adiando para o próximo turno em vez de resolver tudo de uma vez.

Isso é uma mudança de comportamento observável: uma cascata que hoje leva
6+ passos para estabilizar numa única jogada passa a estabilizar em duas
jogadas visíveis, com o tabuleiro "pausando" com peças combinadas visíveis
entre elas. É a leitura literal do pedido ("force o congelamento da
gravidade/estabilização e passe o turno").

**Fora de escopo:** recalibrar a economia de fases/campanha por causa
desse cap. `dart run tool/simulate_economy.dart` deve ser rodado depois da
implementação para confirmar que nenhuma fase existente depende de uma
cascata de mais de 5 passos resolver na mesma jogada; se alguma taxa de
vitória cair fora da faixa aceitável, isso vira um achado a registrar,
não um bloqueio deste spec.

## Geração ponderada

Dentro de uma única chamada de `resolve()` (que pode ter até 5 passos),
`MatchEngine` rastreia o conjunto de `SpecialTileType` já sorteados nesse
turno (um `Set<SpecialTileType>` local à chamada). `refill` exclui esses
tipos do sorteio de peças especiais nos passos seguintes da mesma cascata.
Entre turnos diferentes (chamadas separadas de `resolve()`), a exclusão
não persiste — o conjunto é recriado a cada `tryMove`.

Como hoje só existe um `SpecialTileType` (`wildcard`), esta regra fica
sem efeito observável até um segundo tipo existir — mas a infraestrutura
(o `Set` por chamada, o filtro em `refill`) é o que este spec entrega, e
há teste unitário forçando dois tipos fictícios via um hook de teste para
validar a exclusão, já que o enum de produção tem só um valor.

## Testes

- `Tile.withSpecial`: assert dispara com só um dos dois campos preenchido.
- Decaimento: peça especial em turno 3→2→1→0 vira `Tile` normal mesmo
  `value`; peça fundida antes de chegar a 0 não gera passo de degradação.
- Cascata: cenário construído com `debugSetBoard` que produz 6+ cascatas
  automáticas para forçar o cap; `Resolution.steps.length == 5` e o
  tabuleiro final ainda contém um match detectável por `detectMatches`.
- Continuidade entre turnos: a partir do tabuleiro congelado acima, uma
  nova jogada resolve o match pendente como parte da nova `Resolution`.
- Geração ponderada: com um segundo tipo injetado via hook de teste,
  nenhum passo dentro da mesma `resolve()` sorteia duas vezes o mesmo
  tipo já presente no turno.

## Não implementado, e é decisão explícita

O efeito de jogo do `wildcard` (o que ele faz ao entrar numa combinação)
não é implementado neste spec. A infraestrutura de decaimento, cap e
geração ponderada é genérica e vale para qualquer `SpecialTileType` futuro
sem mudança de código nas três regras acima.
