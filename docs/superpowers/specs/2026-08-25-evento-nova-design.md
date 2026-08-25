# Evento Nova (fusão de 3+ peças de valor 9)

## Contexto

Hoje, quando 3+ peças de valor `9` se alinham (troca do jogador ou acidente
de gravidade/cascata), `_applyFusions` (`match_engine.dart:819-831`) já
detecta o run — mas apenas consome as peças e soma `kMaxDigit * 100` ao
placar, silenciosamente. Nenhum evento estruturado é gerado, nenhum efeito
visual ou de jogo acontece: o jogador vê os `9`s sumirem sem entender por
quê. Este spec substitui esse branch por um terceiro clímax do jogo — a
**Nova** —, distinto e independente do Bloco 9 (`2026-08-25-bloco-9-super-9-design.md`)
e do Super 9. Bloco 9 nasce de 3-4 peças de valor 8 e não se consome; Super 9
nasce de 5+ peças de valor 8 e converte um valor no tabuleiro inteiro ao ser
trocado. A Nova nasce de peças de valor **9 já existentes no tabuleiro**
combinando entre si, e se consome como uma fusão normal.

## Gatilho

Ao contrário do Bloco 9 (que só dispara no passo `cascade == 1`, a fusão
direta do jogador), a Nova dispara **em qualquer passo** — troca do jogador
ou cascata automática. É a leitura literal de "sempre que alinhar": não há
distinção de proveniência, porque os `9`s que se alinham já existiam no
tabuleiro antes da jogada, não nasceram dela.

**Cap de 1 Nova por jogada:** apenas a primeira combinação de 3+ noves detectada
dentro de uma chamada de `resolve()` vira um evento Nova. Qualquer combinação
de 3+ noves subsequente na mesma jogada (outro passo de cascata) cai de volta
no comportamento atual — consumida silenciosamente, soma `kMaxDigit * 100`.
Isso evita uma "Nova em cadeia" (peças promovidas pelo anel externo de uma
Nova formando outra Nova na cascata seguinte), que transformaria o evento em
autoplay em vez de clímax da jogada. É implementado como variável **local**
dentro do escopo de `resolve()` — o mesmo padrão de `CascadeBudget`, que já é
instanciado do zero a cada chamada — e não como campo de estado do jogo:
não há flag persistente para resetar entre turnos, porque não há onde ela
vazaria.

## Zonas de efeito

A área escala com a quantidade de peças `9` no run:

| Tier | Peças 9 no run | Zona total | Núcleo (destrói) | Anel (promove) |
|------|-----------------|------------|-------------------|------------------|
| 1    | 3               | 5x5        | 3x3               | resto da 5x5     |
| 2    | 4               | 7x7        | 3x3               | resto da 7x7     |
| 3    | 5+              | tabuleiro inteiro | tabuleiro inteiro | — (sem anel) |

**Centro do evento:** reaproveita a mesma lógica de posição de sobrevivente
que `_applyFusions` já usa para escolher onde uma fusão normal "acontece" —
sem inventar geometria nova para runs lineares (ex: 5 peças em linha).

**Núcleo (tiers 1 e 2):** quadrado 3x3 centrado na posição do evento, mesmo
tamanho do Bloco 9. Cada célula recebe:
- `damageObstacle()` se houver cobertura (gera `ObstacleHit`, mesma rotina
  de `_damageObstacles`/Bloco 9).
- Remoção da peça, **exceto** peças especiais (`tile.specialType != null` —
  Super 9, Curinga). Peça especial fica intocada no lugar; não conta como
  destruída nem como promovida.

**Anel (tiers 1 e 2):** células da zona total fora do núcleo. Peça
sobrevivente ali (não removida) sobe +1 de valor, com teto em `kMaxDigit`
(uma peça já em 9 não sobe — vira/permanece 9 comum, não reaciona como Nova
neste mesmo passo, coberto pelo cap de 1 Nova por jogada acima). Peça
especial no anel também não é promovida — mantém seu valor e estado.

**Tier 3 (5+ peças no run):** sem distinção núcleo/anel — o tabuleiro
inteiro é tratado como núcleo. Toda peça normal (`specialType == null`) e
toda cobertura são destruídas; peças especiais ficam intocadas. Nenhuma
promoção de anel, porque não sobra "resto da zona" fora do núcleo.

## Pontuação

Bônus estático escalando por tier, constante nova por tier (calibrável
depois, mesmo espírito de `kBigNineScoreBonus`):

```dart
const int kNovaScoreTier1 = 500;  // 3 peças 9
const int kNovaScoreTier2 = 1000; // 4 peças 9
const int kNovaScoreTier3 = 2000; // 5+ peças 9
```

Somado ao `stepScore` do passo em que a Nova ocorre, junto do placar normal
das peças consumidas no run.

## Relação com Super 9

Totalmente independente. Sem checagem de exclusividade — Nova e Super 9
podem coexistir no tabuleiro e disparar em qualquer ordem, inclusive na
mesma cascata (um passo formando Super 9, outro formando Nova).

## Cascata

A Nova é um passo normal de `resolve()`: consome uma unidade de
`CascadeBudget` como qualquer match (não é "grátis" como a limpeza do Bloco
9). A destruição do núcleo abre espaço; gravidade e refill correm no mesmo
`ResolutionStep`, como o resto do motor já faz. Combinações formadas pela
promoção do anel (ex: três peças que viraram 9 ao mesmo tempo) são
detectadas na iteração seguinte de `resolve()`, sujeitas ao cap de 1 Nova por
jogada acima e ao `CascadeBudget` normal.

**Se o `CascadeBudget` esgotar com um match pendente gerado pela Nova:** nenhuma
garantia nova é necessária. É o comportamento já existente e documentado do
motor — `resolve()` para, o match fica congelado no tabuleiro, e a jogada
seguinte do jogador dispara um novo `resolve()` que roda `detectMatches` do
zero e processa o que ficou pendente. Não há cache incremental de match a
invalidar; um campo `isGridDirty` seria estado redundante.

## Estrutura de dados

Novo tipo `NovaEvent`, irmão de `ObstacleHit`/`FusionEvent`:

```dart
class NovaEvent {
  final Position at;           // centro do evento (survivor position)
  final int tier;               // 1, 2 ou 3
  final List<ObstacleHit> obstacleHits; // cobertura destruída no núcleo
  final Set<Position> clearedTiles;     // peças normais destruídas no núcleo
  final Map<Position, int> promoted;    // anel: posição -> novo valor
}
```

`ResolutionStep` ganha `novaEvents` (`List<NovaEvent>`, default `const []`),
mesmo padrão de `obstacleHits`.

## Testes

- **Gatilho por cascata:** 3 peças 9 alinhadas por queda de gravidade (não
  troca direta do jogador) disparam Nova normalmente — ao contrário do Bloco
  9, que exige `cascade == 1`.
- **Cap de 1 por jogada:** cenário com duas combinações de 3+ noves possíveis
  na mesma chamada de `resolve()` (uma no passo 1, outra formada por uma
  cascata posterior) — só a primeira vira `NovaEvent`; a segunda cai no
  comportamento antigo (consumida, sem evento).
- **Tiers e zonas:** 3, 4 e 5+ peças no run produzem `NovaEvent.tier`
  correto, com `obstacleHits`/`clearedTiles` restritos ao núcleo esperado
  (3x3, 3x3, tabuleiro inteiro) e `promoted` restrito ao anel esperado (resto
  da 5x5, resto da 7x7, vazio no tier 3).
- **Imunidade de especiais:** núcleo com um Super 9 dentro do raio — a peça
  não é destruída, não aparece em `clearedTiles`, e não é promovida se
  cair no anel de um evento vizinho.
- **Teto de promoção:** peça de valor 8 no anel vira 9; peça já em 9 no anel
  permanece 9 (não gera `promoted` para ela, ou gera mapeando para o mesmo
  valor — decisão de implementação, testada explicitamente).
- **Independência do Super 9:** cenário com Super 9 vivo no tabuleiro e uma
  Nova disparando na mesma ou em cascata diferente — ambos coexistem sem
  checagem de exclusividade.
- **CascadeBudget esgotado com match pendente da Nova:** força o budget a
  zerar com uma combinação formada por peças promovidas do anel ainda no
  tabuleiro; a jogada seguinte do jogador resolve esse match sem
  intervenção especial (reaproveita o teste já existente do spec de
  Bloco 9/Super 9 para esse comportamento, aplicado ao cenário da Nova).
- **Pontuação:** `stepScore` inclui `kNovaScoreTier{1,2,3}` conforme o tier.

## Não implementado, e é decisão explícita

- Widgets/animações da Nova (juice, hierarquia de prioridade visual,
  banner) — fora de escopo deste spec de domínio, fica para o plano de
  execução, reaproveitando o `JuiceDirector`/`JuicePriority` já desenhados
  no spec de Bloco 9/Super 9 (a Nova deveria ganhar uma prioridade própria
  nesse enum, mas a decisão de onde ela entra na hierarquia — acima ou
  abaixo de `supernova` — fica para quando a UI for desenhada).
- Calibragem de economia: `dart run tool/simulate_economy.dart` deve rodar
  depois da implementação para confirmar que os valores de
  `kNovaScoreTier{1,2,3}` e a frequência de Novas não distorcem a economia
  de pontos existente. Ajuste de constante é achado a registrar, não
  bloqueio deste spec.
- Relação com objetivos de fase (`LevelObjective`): a Nova hoje não altera
  `objectiveTarget`/`objectiveProgress` de nenhum tipo de objetivo — ela é
  puramente um evento de placar/tabuleiro. Se um objetivo futuro quiser
  contar Novas, fica para spec próprio.
