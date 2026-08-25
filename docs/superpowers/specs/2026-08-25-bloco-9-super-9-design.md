# Bloco 9, Super 9 e Cascade Budget

## Contexto

Pedido do Lead Game Architect para redesenhar o clímax do jogo em torno da
filosofia: "o 9 resolve problemas, o Super 9 cria oportunidades, nenhum dos
dois joga a partida pelo jogador". Este spec **substitui** o mecanismo de
explosão do dígito máximo já existente (`ExplosionShape`, `_detonate`,
`kExplosionBonusMoves`) por dois efeitos novos e distintos, e formaliza o
teto de cascatas por turno como `CascadeBudget` — assumindo o papel que o
spec `2026-08-24-pecas-especiais-cascade-cap-design.md` já havia desenhado
para `kMaxCascadesPerTurn`, com valor ajustado de 5 para 4. Esse spec de
ontem (peças especiais + cap de cascata) ainda não tinha sido implementado;
este trabalho o implementa como pré-requisito do Super 9, que depende da
infraestrutura de `SpecialTileType`/decaimento ali desenhada.

## Módulo 1 — Bloco 9 (fusão de 3× e 4× peças de valor 8)

**O que muda:** hoje, uma fusão que produz valor 9 (`kMaxDigit`) dispara
`_detonate`: remove peças num raio (`ExplosionShape.area`/`cross`) e paga
`kExplosionBonusMoves` (+3 movimentos). Isso é removido por completo —
`ExplosionShape`, `_detonate`, `_blastRadius`, `kExplosionBonusMoves` saem
do `MatchEngine`. `clearedByExplosion`/`clearedDigits` em `ResolutionStep`
também deixam de ter para onde apontar e são removidos (nenhuma peça é mais
varrida pelo dígito máximo).

**Trigger — só a fusão do jogador conta:** a limpeza de bloqueadores do
Bloco 9 só roda no passo cujo `cascade == 1` (o match resolvido diretamente
pela troca do jogador). Peças de valor 8 que se combinam numa cascata
subsequente (`cascade > 1`) e produzem um 9 não disparam limpeza nenhuma —
é a leitura literal de "peças 8 de cascata automática não contam", sem
precisar rastrear a proveniência peça a peça: já existe a distinção entre
passo 1 e os seguintes em `resolve()`.

**Efeito (3×8, Bloco 9 padrão):** para cada posição onde nasceu um 9 no
passo `cascade == 1`, as 8 casas 3x3 ao redor (a própria célula do 9 não
é bloqueadora e fica de fora) recebem um `damageObstacle()` — mesma rotina
que `_damageObstacles` já usa, uma vez por cobertura, gerando `ObstacleHit`
normalmente. **Não remove peças, não altera valores.** Não dispara cascata
própria: depois da limpeza, gravidade/refill correm como parte do mesmo
`ResolutionStep`, sem passo extra.

**Efeito (4×8, Bloco 9 aprimorado):** mesma limpeza acima (nenhuma mudança
de mecânica), mais um bônus de score estático — `kBigNineScoreBonus`
(constante nova) somado ao `stepScore` do passo. `FusionEvent.isBig` (já
existente, `matchLength >= kBigMatch`) é o sinal que distingue os dois
casos; não é preciso campo novo em `FusionEvent`.

## Módulo 2 — Super 9 (5+ peças de valor 8)

**Modelo de dados:** reaproveita `SpecialTileType` do spec de ontem
(`lib/features/game/domain/special_tile.dart`), acrescentando
`SpecialTileType.superNine` ao enum. Uma peça Super 9 é
`Tile.withSpecial(specialType: SpecialTileType.superNine, ...)` com
`value: 9` — sujeita ao mesmo decaimento genérico de `kSpecialTileLifespan`
(3 turnos) já especificado: se não for usada, reverte para um 9 comum.

**Geração:** quando uma fusão do jogador (`cascade == 1`, mesma regra do
Módulo 1) produz um match de `length >= 5` peças de valor 8, `_applyFusions`
cria a peça sobrevivente como Super 9 em vez de Bloco 9 comum — a limpeza
de bloqueadores 3x3 do Módulo 1 **ainda se aplica** (Super 9 também é um
Bloco 9 na criação; ele só ganha a capacidade extra de conversão).

**Limite de 1 no tabuleiro:** antes de marcar a peça nascente como
`superNine`, o motor verifica se já existe uma no board (`getAllTiles`
filtrando `specialType == superNine`). Se sim, o match de 5+ produz um
Bloco 9 comum com o bônus de score do 4x (Módulo 1) em vez de um segundo
Super 9. Cobre tanto "5+ peças gerando outro Super 9" quanto encadeamentos
dentro da mesma resolução.

**Ativação — troca com peça vizinha elegível:** `tryMove(board, a, b)`
ganha um desvio antes do fluxo padrão de swap: se `a` ou `b` é uma peça
`superNine` e a outra posição tem um tile elegível (valor `0..8`, não
bloqueado, não outro Super 9 — sempre verdade dado o limite de 1), a jogada
segue como **conversão** em vez de swap+match:

1. Todo tile do tabuleiro com `value == x` vira `value: x + 1`, in-place
   (mesmo `id`, `copyWith`), preservando posição.
2. A peça Super 9 é consumida (removida do tabuleiro).
3. Gravidade preenche o buraco deixado pelo Super 9; `refill` completa o
   topo.
4. **`resolve()` não é chamado.** Nenhuma detecção de match, nenhuma
   fusão, nenhuma cascata — mesmo que a conversão alinhe 3+ peças iguais
   em algum lugar do tabuleiro, elas ficam ali, congeladas, até a jogada
   seguinte do jogador as resolver normalmente. É a mesma semântica que o
   cap de cascata (Módulo 2.3) já usa para "match pendente": o motor nunca
   descarta um match formado, só adia a resolução.

A troca com o Super 9 é o `PLAYER_MOVE`: consome 1 do saldo de `movesLeft`
da fase, como qualquer swap.

**Super 9 não pode gerar outro Super 9 na mesma ação:** coberto pelo limite
de 1 ativo acima (a checagem antes de marcar uma peça nascente) — vale
tanto para uma fusão de 5+ que ocorra like enquanto o Super 9 atual ainda
está no tabuleiro quanto para qualquer efeito futuro que o valor do Super 9
(9) viesse a produzir via conversão (conversão nunca cria valor > 9, então
não há caminho para uma conversão "criar" um Super 9 por acidente).

## Módulo 2.3 — CascadeBudget

Implementa o cap de cascata do spec de ontem, com o valor deste pedido:

```dart
class CascadeBudget {
  CascadeBudget([this.remaining = kCascadeBudgetPerTurn]);
  int remaining;
  bool get isExhausted => remaining <= 0;
  void consume() => remaining--;
}

const int kCascadeBudgetPerTurn = 4;
```

`resolve()` troca a condição de parada `while (steps.length < _maxCascades)`
por um `CascadeBudget` criado no início da chamada, consumido uma unidade
por `ResolutionStep` adicionado, parando quando `isExhausted`.
`_maxCascades = 64` permanece intacto como rede de segurança contra loop
infinito — papel inalterado, só não é mais o limite prático.

Ao atingir o budget com match ainda pendente: `resolve()` para ali, o
`Resolution` tem exatamente 4 `steps`, e o match remanescente fica no
tabuleiro até a jogada seguinte (mesmo comportamento já especificado
ontem, só o número mudou de 5 para 4).

## Módulo 3 — Juice hierarchy e evento Supernova

**Hierarquia:** novo enum em `lib/features/game/presentation/juice/juice_priority.dart`:

```dart
enum JuicePriority { normal, good, great, epic, legendary, supernova }
```

Ordem é a ordem de declaração do enum (`index` crescente = prioridade
maior), o que já dá comparação por `<`/`>` de graça.

**JuiceDirector:** classe nova, pura (recebe uma `Resolution` e devolve o
evento de maior prioridade a apresentar; não conhece widget nem
`AnimationController`):

- Fusão comum (`length == 3`): `good`. `length == 4` (Bloco 9 padrão
  também): `great`. Bloco 9 aprimorado (`isBig` com valor 9): `epic`.
  Super 9 criado ou ativado nesta jogada: `supernova`.
- Se o evento de maior prioridade encontrado é `supernova`, todos os
  outros candidatos da mesma jogada são descartados — só o Supernova é
  apresentado.
- `Resolution`/`MoveResolved` precisam expor o suficiente para o
  `JuiceDirector` identificar "Super 9 envolvido nesta jogada": uma
  conversão marca isso diretamente (é o próprio `MoveResult` da ativação,
  não uma `Resolution` de `resolve()`); a criação de um Super 9 é
  detectável via `fusions` com `specialType == superNine` no evento —
  campo novo em `FusionEvent` (`specialType`), análogo a `isBig`.

**Apresentação do evento Supernova (fora do domínio, plano de
implementação):** hitstop de 250ms (`timeScale = 0.0` num
`AnimationController` dedicado, nunca `Future.delayed`), focus-fade do
grid para 30% de opacidade via alfa de cor (nunca `Opacity`/
`FadeTransition`, mesma armadilha já registrada para obstáculos e martelo),
uma única vinheta sonora (sem sobrepor os SFX de fusão normais — o
`JuiceDirector` já garante isso ao suprimir os outros eventos), banner
"SUPERNOVA" seguido do payoff consolidado ao final da jogada.

## Testes

- **Trigger só do jogador:** fusão de 3×8 numa cascata (`cascade > 1`) não
  gera `ObstacleHit` nenhum ao redor; a mesma fusão como resultado direto
  do swap do jogador (`cascade == 1`) gera até 8 hits.
- **Bloco 9 não remove peças nem dispara cascata própria:** tabuleiro com
  match de 3×8 cercado de peças que não formam match — depois do passo,
  as 9 casas ao redor mantêm seus valores (só a cobertura, se houver, é
  afetada), e `Resolution.steps.length == 1`.
- **4×8 aplica o bônus de score, sem mudar a limpeza:** mesmo cenário do
  3×8, comparando `stepScore` com e sem o quarto ladrilho.
- **Limite de 1 Super 9:** tabuleiro com um Super 9 já presente; uma nova
  fusão de 5×8 produz Bloco 9 comum (com bônus 4x), não um segundo Super 9.
- **Conversão board-wide:** Super 9 trocado com um vizinho de valor `x`
  promove todos os tiles de valor `x` para `x+1`, preserva `id`s, remove o
  Super 9, e `resolve()` **não roda** — um match de 3+ deliberadamente
  alinhado pela conversão permanece no tabuleiro até a jogada seguinte.
- **Custo de movimento:** ativar o Super 9 decrementa `movesLeft` como
  qualquer swap.
- **Decaimento do Super 9:** reaproveita o teste do spec de ontem — Super
  9 não usado em 3 turnos vira 9 comum.
- **CascadeBudget:** cenário de 5+ cascatas automáticas para forçar o
  budget de 4; `Resolution.steps.length == 4`, match remanescente
  detectável, e a jogada seguinte o resolve.
- **JuiceDirector:** dado um conjunto de eventos candidatos incluindo um
  `supernova`, só ele é devolvido; sem `supernova`, o de maior prioridade
  entre os demais.

## Não implementado, e é decisão explícita

- Nenhum efeito de jogo do `wildcard` (já era fora de escopo do spec de
  ontem, continua sendo).
- Calibragem de economia: remover `kExplosionBonusMoves` e o antigo raio
  de explosão muda o valor de alcançar o dígito máximo. `dart run
  tool/simulate_economy.dart` deve ser rodado depois da implementação; uma
  queda de taxa de vitória fora da faixa vira achado a registrar, não
  bloqueio deste spec.
- Widgets/animações do Módulo 3 (hitstop, focus-fade, banner) — o
  `JuiceDirector` e a hierarquia de prioridade são o contrato de domínio;
  a implementação visual fica para o plano de execução.
