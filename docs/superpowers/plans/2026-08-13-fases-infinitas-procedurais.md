# Fases Infinitas Procedurais — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer a campanha do NineFuse nunca acabar, gerando as fases 11+ por aritmética pura a partir do número da fase, e removendo o cartão "Capítulo 3: Em Breve!" do mapa.

**Architecture:** Uma função `levelAt(int)` vira a única porta de acesso a fases: devolve `kCampaign[n-1]` até a fase 10 e `LevelGenerator.generate(n)` daí em diante. `GameLevel` não muda, então motor, HUD e cartões não sabem se a fase foi escrita à mão ou calculada. O mapa passa a renderizar uma janela deslizante de fases em vez da lista inteira.

**Tech Stack:** Dart / Flutter, Riverpod (`flutter_riverpod`), `shared_preferences`, `flutter_test`.

## Global Constraints

- **Offline absoluto.** Nenhuma requisição de rede pode ser adicionada. O gerador é aritmética pura: sem `Random` de instância, sem I/O, sem `DateTime.now()`.
- **`GameLevel` não muda de forma.** Nenhum campo novo, nenhum campo removido.
- **`kCampaign` permanece intacto.** As dez fases artesanais estão calibradas por simulação; nenhum de seus números pode ser alterado.
- **Invariantes que toda fase gerada respeita** (as três primeiras são `assert` do próprio `GameLevel`): `spawnMax - spawnMin == kSpawnWidth - 1`; `spawnMin >= 0`; `spawnMax < kMaxDigit`; `moveLimit > 0`; e a invariante do catálogo — o dígito-alvo é **estritamente maior** que `spawnMax`.
- **Constantes do jogo:** `kMaxDigit = 9`, `kSpawnMin = 0`, `kSpawnMax = 3`, `kSpawnWidth = 4`, `kStarsPerLevel = 3`. Todas já existem; não redefinir.
- **Comentários em português**, explicando o *porquê* e não o *quê*, no estilo do restante de `lib/`.
- **Verificação a cada tarefa:** `flutter analyze` sem nenhuma issue e `flutter test` verde antes de qualquer commit.
- Os valores numéricos do gerador (Task 1) são **provisórios** e são fixados pela Task 7. Não os trate como definitivos antes disso.

---

## Estrutura de arquivos

**Criados:**
- `lib/features/game/domain/level_generator.dart` — a aritmética que transforma um número de fase num `GameLevel`. Puro, sem dependências de Flutter.
- `lib/features/game/domain/level_catalog.dart` — a costura `levelAt(int)`. Único lugar que sabe onde termina o artesanal e começa o procedural.
- `test/features/game/domain/level_generator_test.dart`
- `test/features/game/domain/level_catalog_test.dart`

**Modificados:**
- `lib/features/game/domain/campaign_chapter.dart` — `chapterOf` passa a gerar capítulos além do segundo.
- `lib/features/game/providers/game_notifier.dart:190-196` — `nextLevel()` usa `levelAt`.
- `lib/features/game/presentation/widgets/level_outcome_card.dart:53` — some `_isLastLevel`.
- `lib/features/game/presentation/widgets/saga_map.dart` — some o rótulo "Em Breve".
- `lib/features/game/presentation/screens/level_select_screen.dart` — janela deslizante e denominador do capítulo.
- `lib/features/game/presentation/widgets/campaign_header.dart` — nada estrutural; só quem calcula `starTotal` muda (no chamador).
- `lib/features/game/providers/game_storage.dart` — `readArchivedStars` / `writeArchivedStars`.
- `lib/features/game/providers/campaign_records.dart` — poda por janela.
- `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` — remoção de `chapterComingSoon`.
- `tool/simulate_economy.dart` — `--mode=generated`.

---

### Task 1: `LevelGenerator`

**Files:**
- Create: `lib/features/game/domain/level_generator.dart`
- Test: `test/features/game/domain/level_generator_test.dart`

**Interfaces:**
- Consumes: `GameLevel`, `Objective`, `ObjectiveType` (de `domain/game_level.dart`); `ObstacleLayout`, `ObstacleType` (de `domain/obstacle.dart`); `kMaxDigit`, `kSpawnWidth` (de `domain/match_engine.dart`).
- Produces: `GameLevel generateLevel(int number)`; as constantes `kHandcraftedLevels`, `kBlockSize`.

- [ ] **Step 1: Write the failing test**

Crie `test/features/game/domain/level_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';

void main() {
  group('LevelGenerator', () {
    test('respeita as invariantes de GameLevel de 11 a 1000', () {
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        final level = generateLevel(n);

        expect(level.number, n, reason: 'fase $n');
        expect(level.spawnMax - level.spawnMin, kSpawnWidth - 1,
            reason: 'fase $n: janela de largura fixa');
        expect(level.spawnMin, greaterThanOrEqualTo(0), reason: 'fase $n');
        expect(level.spawnMax, lessThan(kMaxDigit), reason: 'fase $n');
        expect(level.moveLimit, greaterThan(0), reason: 'fase $n');
        expect(level.objective.count, greaterThanOrEqualTo(1), reason: 'fase $n');
      }
    });

    test('o dígito-alvo fica sempre acima da janela de sorteio', () {
      // Se o alvo cai pronto do topo, a fase vira sorte em vez de plano.
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        final level = generateLevel(n);
        if (level.objective.type != ObjectiveType.reachDigit) continue;

        expect(level.objective.digit, greaterThan(level.spawnMax),
            reason: 'fase $n');
        expect(level.objective.digit, lessThanOrEqualTo(kMaxDigit),
            reason: 'fase $n');
      }
    });

    test('objetivo de cobertura sempre pede uma cobertura que a fase espalha',
        () {
      // Pedir pedra numa fase sem pedra é fabricar uma fase impossível.
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        final level = generateLevel(n);
        if (!level.objective.isObstacleGoal) continue;

        expect(level.obstacles.countOf(level.objective.obstacle),
            greaterThanOrEqualTo(level.objective.count),
            reason: 'fase $n pede ${level.objective.debugLabel}');
      }
    });

    test('é determinístico', () {
      for (final n in [11, 47, 250, 999]) {
        final a = generateLevel(n);
        final b = generateLevel(n);
        expect(a.objective, b.objective, reason: 'fase $n');
        expect(a.moveLimit, b.moveLimit, reason: 'fase $n');
        expect(a.spawnMin, b.spawnMin, reason: 'fase $n');
        expect(a.obstacles.total, b.obstacles.total, reason: 'fase $n');
      }
    });

    test('a fase 11 é o arquétipo mais fácil, para não haver degrau na costura',
        () {
      // A 10 é o clímax do conteúdo artesanal. Se a 11 chegar mais dura que
      // ela, o jogador lê a continuação como parede.
      final first = generateLevel(kHandcraftedLevels + 1);

      expect(first.objective.type, ObjectiveType.reachDigit);
      expect(first.objective.count, 1);
      expect(first.objective.digit, first.spawnMax + 1);
    });

    test('nunca devolve o 0 à janela de sorteio', () {
      // O 0 parar de cair é conquista da fase 7; devolvê-lo regride a sensação
      // de progresso.
      for (int n = kHandcraftedLevels + 1; n <= 1000; n++) {
        expect(generateLevel(n).spawnMin, greaterThanOrEqualTo(2),
            reason: 'fase $n');
      }
    });

    test('recusa número de fase artesanal', () {
      expect(() => generateLevel(10), throwsA(isA<AssertionError>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/game/domain/level_generator_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/features/game/domain/level_generator.dart': No such file or directory`

- [ ] **Step 3: Write the implementation**

Crie `lib/features/game/domain/level_generator.dart`:

```dart
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/domain/obstacle.dart';

/// Quantas fases da campanha são escritas à mão.
///
/// Deliberadamente uma constante e não `kCampaign.length`: este arquivo é
/// aritmética pura e não precisa conhecer o catálogo. Quem casa os dois é
/// `level_catalog.dart`, com teste travando a igualdade.
const int kHandcraftedLevels = 10;

/// Fases por bloco de progressão.
///
/// É o mesmo tamanho do capítulo: o jogador vê o bloco terminar e o capítulo
/// virar no mesmo pin, e as duas coisas concordarem é o que faz o ritmo ser
/// legível em vez de aleatório.
const int kBlockSize = 10;

/// Teto de peças pedidas num objetivo de dígito.
///
/// Sem teto o `count` cresceria para sempre e a fase viraria expediente, não
/// desafio: a partir de certo ponto o jogador só repete a mesma fusão.
const int kMaxObjectiveCount = 6;

/// Teto de coberturas no tabuleiro.
///
/// `placeObstacles` descarta em silêncio a cobertura que não acha lugar — as
/// coberturas não podem nascer encostadas. Pedir mais do que cabe faria a fase
/// pedida deixar de ser a fase jogada.
const int kMaxObstacles = 7;

/// Piso do limite de movimentos.
///
/// O aperto por bloco é percentual, e percentual aplicado para sempre chega a
/// zero. O piso é onde a curva para de apertar e a dificuldade passa a vir
/// inteira dos outros eixos.
const int kMinMoveLimit = 8;

/// A fase de número [number], calculada.
///
/// Determinística por construção: só faz aritmética sobre [number]. O
/// **tabuleiro** continua sorteado a cada tentativa — o que esta função fixa é
/// o contrato da fase, não o grid. Fixar o grid faria repetir uma fase perdida
/// virar decorar a solução.
GameLevel generateLevel(int number) {
  assert(
    number > kHandcraftedLevels,
    'as $kHandcraftedLevels primeiras fases são artesanais',
  );

  final block = _blockOf(number);
  final position = _positionOf(number);

  final spawnMin = _spawnMinFor(block);
  final spawnMax = spawnMin + kSpawnWidth - 1;
  final obstacles = _obstaclesFor(block);
  final objective = _objectiveFor(
    position: position,
    block: block,
    spawnMax: spawnMax,
    obstacles: obstacles,
  );

  return GameLevel(
    number: number,
    objective: objective,
    moveLimit: _movesFor(objective: objective, block: block),
    spawnMin: spawnMin,
    spawnMax: spawnMax,
    obstacles: obstacles,
  );
}

/// Índice do bloco de progressão, contado a partir da primeira fase gerada.
int _blockOf(int number) => (number - kHandcraftedLevels - 1) ~/ kBlockSize;

/// Posição dentro do bloco, de 0 a [kBlockSize] - 1.
int _positionOf(int number) => (number - kHandcraftedLevels - 1) % kBlockSize;

/// O degrau da janela de sorteio.
///
/// Sobe um a cada bloco até o teto (`spawnMin` 5 é a janela em que o dígito
/// máximo é alvo) e depois **cicla** a partir de 2, porque o degrau tem topo
/// mas o jogo não tem. Nunca volta a 0 nem a 1: o `0` parar de cair é uma
/// conquista da fase 7, e devolvê-lo seria regredir a sensação de progresso.
int _spawnMinFor(int block) {
  const int first = 3; // continua de onde a fase 10 parou
  const int last = 5; // acima disso `spawnMax` alcançaria o dígito máximo
  const int cycleFrom = 2;

  final climb = first + block;
  if (climb <= last) return climb;

  final cycleLength = last - cycleFrom + 1;
  final ascent = last - first + 1;
  return cycleFrom + (block - ascent) % cycleLength;
}

/// O que a fase pede.
///
/// O ciclo dentro do bloco é sete fases de dígito, duas de quebra e uma de
/// limpeza total como fecho. A variedade não é enfeite: o dígito satura em
/// [kMaxDigit] por volta do terceiro bloco, e a partir dali é a **natureza** da
/// meta, não o alvo, que mantém as fases distintas umas das outras.
Objective _objectiveFor({
  required int position,
  required int block,
  required int spawnMax,
  required ObstacleLayout obstacles,
}) {
  // Fecho de bloco: limpar tudo do tipo mais duro que a fase espalha.
  if (position == kBlockSize - 1) {
    return Objective.clearAllObstacles(_hardestOf(obstacles));
  }

  // As duas antes do fecho: quebrar uma quantidade declarada.
  if (position >= kBlockSize - 3) {
    final obstacle = _hardestOf(obstacles);
    final asked = 2 + block ~/ 2;
    return Objective.clearObstacles(
      obstacle: obstacle,
      // Nunca mais do que a fase espalha: cobrar cobertura que não existe no
      // tabuleiro é fabricar uma fase impossível.
      count: asked.clamp(1, obstacles.countOf(obstacle)),
    );
  }

  // O corpo do bloco: formar o dígito acima da janela.
  //
  // O `+1` alternando com `+2` dá dois patamares de esforço dentro do mesmo
  // degrau de janela — uma fusão contra duas — sem precisar de outro eixo.
  final digit = position.isOdd ? spawnMax + 2 : spawnMax + 1;
  final count = (1 + position % 3 + block ~/ 2).clamp(1, kMaxObjectiveCount);

  return Objective(
    digit: digit > kMaxDigit ? kMaxDigit : digit,
    count: count,
  );
}

/// As coberturas que o bloco espalha.
///
/// Toda fase gerada tem pelo menos um gelo: as duas fases de cobertura do bloco
/// escolhem seu alvo daqui, e um bloco sem cobertura nenhuma não teria o que
/// pedir. A dureza entra por bloco, do mais macio para o mais duro, na mesma
/// ordem em que a campanha artesanal as apresentou.
ObstacleLayout _obstaclesFor(int block) {
  final ice = (2 + block % 3).clamp(1, 4);
  final glass = (1 + block ~/ 2).clamp(1, 3);
  final stone = (block ~/ 3).clamp(0, 3);

  // O teto é do tabuleiro, não do desenho: o excesso é aparado da cobertura
  // mais macia, que é a que menos muda o que a fase pede.
  var trimmedIce = ice;
  var total = ice + glass + stone;
  while (total > kMaxObstacles && trimmedIce > 1) {
    trimmedIce--;
    total--;
  }

  return ObstacleLayout(ice: trimmedIce, glass: glass, stone: stone);
}

/// A cobertura mais dura que [layout] espalha.
ObstacleType _hardestOf(ObstacleLayout layout) {
  if (layout.stone > 0) return ObstacleType.stone;
  if (layout.glass > 0) return ObstacleType.glass;
  return ObstacleType.ice;
}

/// O limite de movimentos.
///
/// A base sai do arquétipo do objetivo, porque as três metas se medem em
/// unidades diferentes: três peças custam cerca de três vezes uma peça, e uma
/// cobertura só cede a fusões encostadas nela — que o jogador não escolhe
/// diretamente, e por isso custam mais.
///
/// Os números são **provisórios** e serão fixados por
/// `tool/simulate_economy.dart --mode=generated`.
int _movesFor({required Objective objective, required int block}) {
  final base = switch (objective.type) {
    ObjectiveType.reachDigit => 15 * objective.count,
    ObjectiveType.clearObstacles => 12 * objective.count,
    ObjectiveType.clearAllObstacles => 30,
  };

  // Aperto de 2% por bloco: a fase encolhe devagar o bastante para o jogador
  // sentir que melhorou, e não que o jogo o traiu.
  final tightened = (base * (1 - 0.02 * block)).floor();
  return tightened < kMinMoveLimit ? kMinMoveLimit : tightened;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/game/domain/level_generator_test.dart`
Expected: PASS — `All tests passed!`

Se o teste `objetivo de cobertura sempre pede uma cobertura que a fase espalha` falhar, o defeito está no `clamp` de `_objectiveFor` — não relaxe o teste.

- [ ] **Step 5: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/features/game/domain/level_generator.dart test/features/game/domain/level_generator_test.dart
git commit -m "feat: gerador determinístico de fases procedurais"
```

Expected de `flutter analyze`: `No issues found!`

---

### Task 2: A costura `levelAt` e os capítulos infinitos

**Files:**
- Create: `lib/features/game/domain/level_catalog.dart`
- Modify: `lib/features/game/domain/campaign_chapter.dart:53-79`
- Test: `test/features/game/domain/level_catalog_test.dart`

**Interfaces:**
- Consumes: `generateLevel(int)`, `kHandcraftedLevels`, `kBlockSize` (Task 1); `kCampaign`, `kChapters`, `CampaignChapter`, `ChapterName`.
- Produces: `GameLevel levelAt(int number)`; `CampaignChapter chapterOf(int levelNumber)` com comportamento novo. `kCampaignStarTotal` é **removido**.

- [ ] **Step 1: Write the failing test**

Crie `test/features/game/domain/level_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';

void main() {
  group('levelAt', () {
    test('as fases artesanais saem intactas do catálogo', () {
      expect(kCampaign.length, kHandcraftedLevels);

      for (final level in kCampaign) {
        final fromCatalog = levelAt(level.number);
        expect(fromCatalog.objective, level.objective);
        expect(fromCatalog.moveLimit, level.moveLimit);
        expect(fromCatalog.spawnMin, level.spawnMin);
        expect(fromCatalog.teaches, level.teaches);
      }
    });

    test('a fase 11 em diante é gerada', () {
      expect(levelAt(11).moveLimit, generateLevel(11).moveLimit);
      expect(levelAt(11).objective, generateLevel(11).objective);
    });

    test('a numeração é contínua e sem buraco até bem longe', () {
      for (int n = 1; n <= 1000; n++) {
        expect(levelAt(n).number, n);
      }
    });

    test('recusa fase zero ou negativa', () {
      expect(() => levelAt(0), throwsA(isA<AssertionError>()));
    });
  });

  group('chapterOf', () {
    test('os capítulos artesanais não mudam', () {
      expect(chapterOf(1).number, 1);
      expect(chapterOf(6).number, 1);
      expect(chapterOf(7).number, 2);
      expect(chapterOf(10).number, 2);
    });

    test('gera capítulos além do segundo, de dez em dez', () {
      expect(chapterOf(11).number, 3);
      expect(chapterOf(20).number, 3);
      expect(chapterOf(21).number, 4);
      expect(chapterOf(1000).number, 102);
    });

    test('o capítulo gerado cobre exatamente a fase pedida', () {
      for (int n = 11; n <= 1000; n++) {
        final chapter = chapterOf(n);
        expect(chapter.contains(n), isTrue, reason: 'fase $n');
        expect(chapter.levelCount, kBlockSize, reason: 'fase $n');
        expect(chapter.starTotal, kBlockSize * kStarsPerLevel, reason: 'fase $n');
      }
    });

    test('a numeração dos capítulos não tem buraco', () {
      var previous = chapterOf(1).number;
      for (int n = 2; n <= 1000; n++) {
        final current = chapterOf(n).number;
        expect(current - previous, anyOf(0, 1), reason: 'fase $n');
        previous = current;
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/game/domain/level_catalog_test.dart`
Expected: FAIL — arquivo `level_catalog.dart` não existe.

- [ ] **Step 3: Write `level_catalog.dart`**

```dart
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_generator.dart';

export 'package:nine_fuse/features/game/domain/game_level.dart';

/// A fase de número [number] — a **única** porta de acesso a fases.
///
/// Existe porque uma campanha infinita não pode ser uma lista: não há `length`
/// para indexar nem para comparar. Quem chama não sabe, e não precisa saber, se
/// a fase que recebeu foi escrita à mão ou calculada — as duas são `GameLevel`,
/// e é isso que mantém motor, HUD, mapa e cartões alheios à mudança.
GameLevel levelAt(int number) {
  assert(number >= 1, 'a campanha começa na fase 1');

  return number <= kHandcraftedLevels
      ? kCampaign[number - 1]
      : generateLevel(number);
}
```

- [ ] **Step 4: Rewrite `chapterOf` in `campaign_chapter.dart`**

Substitua `chapterOf` e remova `kCampaignStarTotal` (linhas 68-79 do arquivo atual) por:

```dart
/// O capítulo a que [levelNumber] pertence.
///
/// Além do último capítulo artesanal os capítulos são **gerados**, um a cada
/// [kBlockSize] fases, no mesmo compasso do bloco de progressão do gerador — o
/// jogador vê o bloco virar e o capítulo virar no mesmo pin.
///
/// Os nomes ciclam pela lista de [ChapterName]. Nomes se repetem lá na frente,
/// e isso é aceitável: o que não pode repetir é o **número**, que é o que dá
/// ao jogador a medida de quanto ele atravessou.
CampaignChapter chapterOf(int levelNumber) {
  for (final chapter in kChapters) {
    if (chapter.contains(levelNumber)) return chapter;
  }

  final beyond = levelNumber - kChapters.last.lastLevel;
  final block = (beyond - 1) ~/ kBlockSize;
  final first = kChapters.last.lastLevel + block * kBlockSize + 1;

  return CampaignChapter(
    number: kChapters.last.number + block + 1,
    name: ChapterName.values[(block + kChapters.length) %
        ChapterName.values.length],
    firstLevel: first,
    lastLevel: first + kBlockSize - 1,
  );
}
```

Acrescente ao topo do arquivo o import do gerador (por `kBlockSize`):

```dart
import 'package:nine_fuse/features/game/domain/level_generator.dart';
```

E remova o import agora não usado de `game_level.dart` **apenas se** `flutter analyze` reclamar dele.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/game/domain/level_catalog_test.dart`
Expected: PASS

- [ ] **Step 6: Fix the fallout of removing `kCampaignStarTotal`**

Run: `flutter analyze`
Expected: erro em `lib/features/game/presentation/screens/level_select_screen.dart:166` — `Undefined name 'kCampaignStarTotal'`.

Deixe **este erro específico** de pé: ele é corrigido na Task 5, que é dona daquele arquivo. Se `flutter analyze` apontar qualquer outro erro, corrija-o agora.

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/domain/level_catalog.dart lib/features/game/domain/campaign_chapter.dart test/features/game/domain/level_catalog_test.dart
git commit -m "feat: levelAt como porta única de acesso a fases, com capítulos infinitos"
```

Nota: neste ponto a árvore não compila — a Task 5 fecha o buraco. Se o executor precisar de commits sempre verdes, faça as Tasks 2 e 5 como uma unidade.

---

### Task 3: A campanha deixa de ter fim

**Files:**
- Modify: `lib/features/game/providers/game_notifier.dart:189-196`
- Modify: `lib/features/game/presentation/widgets/level_outcome_card.dart:53`
- Test: `test/features/game/providers/` (arquivo existente de campanha; se não houver um, crie `test/features/game/providers/infinite_campaign_test.dart`)

**Interfaces:**
- Consumes: `levelAt(int)` (Task 2).
- Produces: nada novo. `_isLastLevel` deixa de existir.

- [ ] **Step 1: Write the failing test**

Crie `test/features/game/providers/infinite_campaign_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';

void main() {
  test('vencer a última fase artesanal abre a seguinte, que é gerada', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameProvider.notifier);
    notifier.startLevel(levelAt(10));
    notifier.nextLevel();

    expect(container.read(gameProvider).level.number, 11);
  });

  test('a campanha não repete a fase nem lá adiante', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameProvider.notifier);
    notifier.startLevel(levelAt(250));
    notifier.nextLevel();

    expect(container.read(gameProvider).level.number, 251);
  });
}
```

Se o provider do jogo não se chamar `gameProvider` ou exigir dublês (armazenamento, feedback tátil), copie o padrão de setup do arquivo de teste de providers já existente mais próximo — por exemplo `test/features/game/providers/nine_reward_test.dart` — em vez de inventar um novo.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/game/providers/infinite_campaign_test.dart`
Expected: FAIL — a segunda asserção dá `250` em vez de `251`, porque `nextLevel()` repete a fase quando não acha índice em `kCampaign`.

- [ ] **Step 3: Rewrite `nextLevel`**

Em `lib/features/game/providers/game_notifier.dart`, substitua o método (linhas 189-196):

```dart
  /// Vai para a fase seguinte. Não há última fase: acima do conteúdo
  /// artesanal, `levelAt` calcula.
  void nextLevel() => startLevel(levelAt(state.level.number + 1));
```

Troque o import de `game_level.dart` por `level_catalog.dart` no topo do arquivo (o catálogo reexporta `game_level.dart`, então nada mais quebra).

- [ ] **Step 4: Remove `_isLastLevel`**

Em `lib/features/game/presentation/widgets/level_outcome_card.dart`, remova o getter `_isLastLevel` (linha 53) e o ramo de UI que ele controla — o caso "campanha vencida" não pode mais ocorrer. Leia o arquivo antes de editar: se `_isLastLevel` alimentar o rótulo de um botão, o botão passa a usar incondicionalmente o rótulo de "próxima fase".

Se essa remoção deixar chaves de tradução órfãs (uma frase de "campanha concluída"), remova-as dos dois ARB e rode `flutter gen-l10n`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/game/providers/infinite_campaign_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
flutter test
git add -A
git commit -m "feat: a campanha deixa de ter última fase"
```

`flutter test` ainda pode falhar por causa do buraco da Task 2 em `level_select_screen.dart`. Nesse caso, siga para a Task 4 e comite ao fim da Task 5.

---

### Task 4: O mapa perde o "Em Breve" e ganha janela deslizante

**Files:**
- Modify: `lib/features/game/presentation/widgets/saga_map.dart:190-235`
- Modify: `lib/l10n/app_pt.arb:103`, `lib/l10n/app_en.arb:189-190`
- Test: `test/features/game/presentation/` (crie `saga_map_infinite_test.dart`)

**Interfaces:**
- Consumes: `levelAt(int)` (Task 2).
- Produces: nada novo. `_comingSoonLabel` e a chave `chapterComingSoon` deixam de existir.

- [ ] **Step 1: Write the failing test**

Crie `test/features/game/presentation/saga_map_infinite_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/level_catalog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

void main() {
  Widget host(List<GameLevel> levels, int progress) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SagaMapWidget(
              levels: levels,
              progress: progress,
              starsOf: (_) => 0,
              onTapLevel: (_) {},
            ),
          ),
        ),
      );

  testWidgets('o mapa não anuncia mais capítulo em breve', (tester) async {
    await tester.pumpWidget(host(
      [for (int n = 1; n <= 18; n++) levelAt(n)],
      10,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Em Breve'), findsNothing);
    expect(find.textContaining('Coming Soon'), findsNothing);
  });

  testWidgets('mostra pins além da última fase artesanal', (tester) async {
    await tester.pumpWidget(host(
      [for (int n = 1; n <= 18; n++) levelAt(n)],
      10,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(levelCardKey(11)), findsOneWidget);
    expect(find.byKey(levelCardKey(18)), findsOneWidget);
  });
}
```

Se `SagaMapWidget` exigir parâmetros além destes, leia a assinatura no arquivo e preencha com os mesmos valores usados pelo teste de mapa já existente.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/game/presentation/saga_map_infinite_test.dart`
Expected: FAIL no primeiro teste — o rótulo "Em Breve" ainda é renderizado.

- [ ] **Step 3: Remove the label from the widget**

Em `lib/features/game/presentation/widgets/saga_map.dart`:
1. Remova a chamada `_comingSoonLabel(context, geometry),` da lista de filhos do `Stack` (perto da linha 190).
2. Remova o método `_comingSoonLabel` inteiro, com seu comentário de doc (linhas ~200-235).
3. Rode `flutter analyze` e remova os imports que ficarem sem uso (provavelmente `campaign_chapter.dart` e/ou `app_fonts.dart` — remova **apenas** os que o analisador apontar).

Se o widget também desenhar `_FuturePin`s projetados (nós fantasma além da última fase), mantenha-os: agora eles representam fases que existem de verdade, e a Task 5 passa a alimentá-los com fases reais.

- [ ] **Step 4: Remove the orphaned translation keys**

Remova de `lib/l10n/app_pt.arb` a linha `"chapterComingSoon": ...` e de `lib/l10n/app_en.arb` a linha `"chapterComingSoon"` **e** o bloco `"@chapterComingSoon"` inteiro. Cuide das vírgulas do JSON.

Run: `flutter gen-l10n`
Expected: sem saída de erro; `lib/l10n/app_localizations*.dart` regenerados sem `chapterComingSoon`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/game/presentation/saga_map_infinite_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: o mapa deixa de anunciar fim de conteúdo"
```

---

### Task 5: A tela do mapa passa a gerar fases sob demanda

**Files:**
- Modify: `lib/features/game/presentation/screens/level_select_screen.dart:70-105, 143-170, 228`
- Test: `test/features/game/presentation/saga_map_infinite_test.dart` (acrescentar)

**Interfaces:**
- Consumes: `levelAt(int)`, `chapterOf(int)` (Task 2); `CampaignRecords.starsInChapter` (já existe).
- Produces: constante `kLookahead`.

- [ ] **Step 1: Write the failing test**

Acrescente ao fim de `test/features/game/presentation/saga_map_infinite_test.dart`:

```dart
  testWidgets('a tela do mapa abre com fases além da campanha artesanal',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LevelSelectScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Com progresso zero a janela ainda tem de alcançar as dez artesanais.
    expect(find.byKey(levelCardKey(10)), findsOneWidget);
    expect(find.textContaining('Em Breve'), findsNothing);
  });
```

Acrescente os imports necessários ao topo do arquivo: `flutter_riverpod/flutter_riverpod.dart` e a tela `.../screens/level_select_screen.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/game/presentation/saga_map_infinite_test.dart`
Expected: FAIL na compilação — `Undefined name 'kCampaignStarTotal'` (o buraco deixado pela Task 2).

- [ ] **Step 3: Introduce the sliding window**

Em `lib/features/game/presentation/screens/level_select_screen.dart`, acrescente perto do topo do arquivo (fora da classe):

```dart
/// Quantas fases o mapa mostra à frente do progresso do jogador.
///
/// Mais de uma tela de pins, para a trilha nunca terminar dentro do campo de
/// visão: o jogador precisa ver que há continuação sem precisar rolar para
/// descobrir. Uma lista infinita não existe em memória e não precisa existir —
/// alocar mil fases para mostrar oito seria pagar por nada.
const int kLookahead = 8;
```

Substitua todos os usos de `kCampaign` nesta tela. Nos três lugares:

1. Em `_centerOnCurrentLevel`, troque `levelCount: kCampaign.length` por `levelCount: _visibleCount(progress)`.
2. Substitua `_currentIndex` inteiro — o índice agora é aritmética direta, já que a janela sempre começa na fase 1:

```dart
  /// Quantas fases a trilha mostra agora.
  int _visibleCount(int progress) {
    final wanted = progress + kLookahead;
    return wanted < kHandcraftedLevels ? kHandcraftedLevels : wanted;
  }

  /// Índice da primeira fase ainda não vencida, dentro da janela visível.
  ///
  /// A janela sempre começa na fase 1, então índice e número diferem por um —
  /// não há mais busca a fazer.
  int _currentIndex(int progress) =>
      progress.clamp(0, _visibleCount(progress) - 1);
```

3. No `build`, troque a linha do capítulo e a montagem do mapa:

```dart
    final visible = [
      for (int n = 1; n <= _visibleCount(progress); n++) levelAt(n),
    ];
    final chapter = chapterOf(progress + 1);
```

e no `SagaMapWidget`: `levels: visible,`.

4. No `CampaignHeader`, troque o denominador:

```dart
                  CampaignHeader(
                    chapter: chapter,
                    totalStars: records.starsInChapter(chapter),
                    starTotal: chapter.starTotal,
                  ),
```

Acrescente ao comentário do `CampaignHeader` na tela (ou logo acima da chamada) a razão:

```dart
                  // O denominador é o **capítulo**, não a campanha: sem
                  // `length` não há total de campanha, e uma barra com
                  // denominador infinito decairia para zero para sempre. Medir
                  // o trecho atual devolve à barra um significado — quanto
                  // falta para fechar este pedaço.
```

Ajuste os imports: troque `game_level.dart` por `level_catalog.dart` e acrescente `level_generator.dart` (por `kHandcraftedLevels`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/game/presentation/saga_map_infinite_test.dart`
Expected: PASS

- [ ] **Step 5: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` e `All tests passed!`

Testes antigos que afirmavam "o mapa mostra Em Breve" ou "a fase 10 é a última" agora falham **corretamente** — atualize-os para o comportamento novo, não reintroduza o antigo.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: mapa com janela deslizante de fases geradas sob demanda"
```

---

### Task 6: Poda dos registros de fase

**Files:**
- Modify: `lib/features/game/providers/game_storage.dart:20-30, 55, 110-150, 155-215`
- Modify: `lib/features/game/providers/campaign_records.dart`
- Test: `test/features/game/providers/campaign_records_pruning_test.dart` (criar)

**Interfaces:**
- Consumes: `GameStorage`, `FakeGameStorage` (o dublê já existente em `game_storage.dart`, linhas ~155+), `LevelRecord`.
- Produces: em `GameStorage` — `Future<int> readArchivedStars()` e `Future<void> writeArchivedStars(int stars)`. Em `CampaignRecords` — a constante `kRecordWindow` e o campo `archivedStars`; `totalStars` passa a incluir o arquivo.

- [ ] **Step 1: Write the failing test**

Crie `test/features/game/providers/campaign_records_pruning_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

void main() {
  test('poda o detalhe das fases antigas sem perder as estrelas', () async {
    final storage = FakeGameStorage();
    final records = CampaignRecords(storage: storage);
    addTearDown(records.dispose);

    // Uma fase a mais do que a janela comporta.
    for (int n = 1; n <= kRecordWindow + 5; n++) {
      records.record(n, stars: 3, score: 100);
    }

    expect(records.state.length, lessThanOrEqualTo(kRecordWindow));
    expect(records.totalStars, (kRecordWindow + 5) * 3);
  });

  test('a poda descarta as fases mais antigas, não as recentes', () async {
    final storage = FakeGameStorage();
    final records = CampaignRecords(storage: storage);
    addTearDown(records.dispose);

    for (int n = 1; n <= kRecordWindow + 5; n++) {
      records.record(n, stars: 3, score: 100);
    }

    expect(records.state.containsKey(1), isFalse);
    expect(records.state.containsKey(kRecordWindow + 5), isTrue);
  });

  test('o arquivo sobrevive a uma releitura do disco', () async {
    final storage = FakeGameStorage();
    final first = CampaignRecords(storage: storage);
    for (int n = 1; n <= kRecordWindow + 5; n++) {
      first.record(n, stars: 3, score: 100);
    }
    first.dispose();

    final second = CampaignRecords(storage: storage);
    addTearDown(second.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(second.totalStars, (kRecordWindow + 5) * 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/game/providers/campaign_records_pruning_test.dart`
Expected: FAIL — `Undefined name 'kRecordWindow'`.

- [ ] **Step 3: Add the archive to `GameStorage`**

Em `lib/features/game/providers/game_storage.dart`, acrescente à interface abstrata (junto de `readLevelRecords`):

```dart
  /// Estrelas de fases cujo detalhe já foi podado.
  ///
  /// A campanha é infinita, e o histórico por fase é gravado como **uma única
  /// string JSON** reescrita a cada vitória: sem poda, cada fase vencida
  /// custaria uma escrita proporcional a tudo que já foi jogado. O agregado é
  /// o que preserva a conta de estrelas quando o detalhe sai.
  Future<int> readArchivedStars();
  Future<void> writeArchivedStars(int stars);
```

Na implementação `PrefsGameStorage`, ao lado de `_recordsKey`:

```dart
  static const String _archivedStarsKey = 'campaign_archived_stars';
```

e os dois métodos:

```dart
  @override
  Future<int> readArchivedStars() async =>
      (await SharedPreferences.getInstance()).getInt(_archivedStarsKey) ?? 0;

  @override
  Future<void> writeArchivedStars(int stars) async =>
      (await SharedPreferences.getInstance()).setInt(_archivedStarsKey, stars);
```

No dublê `FakeGameStorage`, acrescente o campo e os dois métodos:

```dart
  int archivedStars = 0;

  @override
  Future<int> readArchivedStars() async => archivedStars;

  @override
  Future<void> writeArchivedStars(int stars) async => archivedStars = stars;
```

- [ ] **Step 4: Add pruning to `CampaignRecords`**

Em `lib/features/game/providers/campaign_records.dart`, acrescente no topo do arquivo:

```dart
/// Quantas fases guardam registro detalhado.
///
/// A campanha não tem fim, mas a memória tem: o histórico é uma única string
/// JSON reescrita a cada vitória, então guardar tudo tornaria cada fase vencida
/// mais cara que a anterior, para sempre. Duzentas fases são muito mais do que
/// o mapa mostra sem minutos de rolagem — o que se perde é detalhe que ninguém
/// consulta, e as estrelas seguem contadas no agregado.
const int kRecordWindow = 200;
```

Acrescente o campo e a leitura do arquivo:

```dart
  /// Estrelas de fases já podadas. Somadas ao total, nunca ao mapa.
  int archivedStars = 0;
```

Em `_load`, depois do `_merge`, acrescente:

```dart
      archivedStars = await _storage.readArchivedStars();
```

Substitua `totalStars` para incluir o arquivo:

```dart
  /// Soma de todas as estrelas conquistadas, incluindo as das fases podadas.
  int get totalStars =>
      archivedStars +
      state.values.fold(0, (total, record) => total + record.stars);
```

Em `record`, logo antes de `_persist()`, aplique a poda:

```dart
    state = _pruned({...state, levelNumber: merged});
```

(substituindo a atribuição de `state` que já existe ali), e acrescente o método:

```dart
  /// Mantém apenas as [kRecordWindow] fases mais recentes, arquivando as
  /// estrelas das que saem.
  ///
  /// Poda pelo **número da fase**, e não pela ordem de gravação: o jogador pode
  /// rejogar uma fase antiga a qualquer momento, e nesse caso o que interessa
  /// continua sendo onde ela está na trilha.
  Map<int, LevelRecord> _pruned(Map<int, LevelRecord> records) {
    if (records.length <= kRecordWindow) return records;

    final ordered = records.keys.toList()..sort();
    final dropCount = records.length - kRecordWindow;

    final kept = Map.of(records);
    for (final number in ordered.take(dropCount)) {
      archivedStars += kept.remove(number)!.stars;
    }

    unawaited(_storage.writeArchivedStars(archivedStars));
    return kept;
  }
```

Acrescente `import 'dart:async';` ao topo (por `unawaited`).

Em `reset()`, zere o arquivo também:

```dart
  void reset() {
    state = const {};
    archivedStars = 0;
    _persist();
    unawaited(_storage.writeArchivedStars(0));
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/game/providers/campaign_records_pruning_test.dart`
Expected: PASS

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat: poda o histórico de fases mantendo a conta de estrelas"
```

---

### Task 7: Calibragem por simulação

**Files:**
- Modify: `tool/simulate_economy.dart:620-630, 712-755`
- Modify: `lib/features/game/domain/level_generator.dart` (só as constantes numéricas)
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `generateLevel(int)` (Task 1); `_rankMoves`, `_targetOf(GameLevel, Board)`, `_gainOf(GameLevel, Resolution)`, `_pad`, `_padLeft`, `MatchEngine` (todos já existentes no simulador).
- Produces: `--mode=generated`.

- [ ] **Step 1: Add the new mode to the simulator**

Em `tool/simulate_economy.dart`, acrescente após o bloco `if (mode == 'obstacles' ...)`:

```dart
  if (mode == 'generated' || mode == 'both') {
    print('');
    print('#' * 62);
    print('# I) FASES GERADAS   (campanha infinita)');
    print('#' * 62);
    print('# Taxa de vitória das fases procedurais, no limite que o');
    print('# próprio gerador escolheu. Meta: 70-90%.');
    print('#' * 62);

    _reportGeneratedLevels(
      games: games,
      // Os pontos em que a curva muda de natureza: primeira fase gerada, troca
      // de degrau de janela, saturação do dígito máximo, e o longo prazo.
      // Sete amostras não provam mil fases; provam que a curva não descarrila
      // onde ela muda.
      numbers: const [11, 25, 50, 100, 250, 500, 1000],
    );
  }
```

E o relatório, junto das outras funções `_report*`:

```dart
/// Taxa de vitória das fases geradas, cada uma no limite de movimentos que o
/// gerador escolheu para ela.
///
/// O jogador automático é o guloso de sempre — mira a fusão de maior valor e
/// **nunca** a cobertura. Nas fases de objetivo de cobertura o número que sai
/// daqui é portanto um **piso**, pela mesma razão já registrada em
/// `_reportObstaclePhases`.
void _reportGeneratedLevels({
  required int games,
  required List<int> numbers,
}) {
  print('');
  print('  ${_pad('fase', 8)}${_pad('objetivo', 24)}'
      '${_padLeft('janela', 10)}${_padLeft('mov', 7)}${_padLeft('vitórias', 11)}');
  print('  ${'-' * 60}');

  for (final number in numbers) {
    final level = generateLevel(number);
    var wins = 0;

    for (int seed = 0; seed < games; seed++) {
      final engine = MatchEngine(
        random: Random(seed),
        spawnMin: level.spawnMin,
        spawnMax: level.spawnMax,
      );

      var board = engine.generateBoard(obstacles: level.obstacles);

      // `_targetOf` e `_gainOf` já existem no arquivo e já sabem tratar os três
      // tipos de objetivo — inclusive o alvo de "limpe todas", que sai do
      // tabuleiro sorteado e não do pedido da fase. Reusá-los é o que mantém
      // este modo medindo a mesma coisa que os outros.
      final target = _targetOf(level, board);

      var progress = 0;
      var moves = 0;

      while (moves < level.moveLimit && progress < target) {
        final options = _rankMoves(engine, board);
        if (options.isEmpty) break;

        final chosen = options.first;
        final resolution = engine.resolve(
          engine.swap(board, chosen.from, chosen.to),
          anchor: chosen.to,
        );
        board = resolution.board;
        progress += _gainOf(level, resolution);
        moves++;
      }

      if (progress >= target) wins++;
    }

    final rate = (wins / games * 100).toStringAsFixed(0);
    print('  ${_pad('$number', 8)}'
        '${_pad(level.objective.debugLabel, 24)}'
        '${_padLeft('${level.spawnMin}-${level.spawnMax}', 10)}'
        '${_padLeft('${level.moveLimit}', 7)}'
        '${_padLeft('$rate%', 11)}');
  }

  print('');
  print('  Piso nas fases de cobertura: o bot nunca mira a cobertura.');
}
```

Acrescente o import de `level_generator.dart` ao topo do arquivo. `_targetOf` e `_gainOf` já existem no arquivo (usados pelo modo `efficiency`, por volta da linha 413) — não crie versões novas nem acrescente métodos ao domínio.

- [ ] **Step 2: Run the simulator**

Run: `dart run tool/simulate_economy.dart --mode=generated`
Expected: uma tabela de sete linhas com uma coluna de vitórias em porcentagem.

- [ ] **Step 3: Calibrate**

Ajuste **apenas** as constantes numéricas de `lib/features/game/domain/level_generator.dart` — os multiplicadores de `_movesFor`, o aperto de 2% por bloco, `kMinMoveLimit`, os limites de `_obstaclesFor` — e rode de novo, até que as fases de **objetivo de dígito** fiquem entre 70% e 90%.

Regras da calibragem:
- Fases de objetivo de cobertura ficarem abaixo da meta é **esperado** e não é motivo para inflar o limite: o bot não mira cobertura. Registre o número observado e siga.
- Nenhuma amostra pode ficar em 100%: um limite que nunca pesa é uma fase que não pede nada.
- Nenhuma amostra pode ficar abaixo de 40%: o jogador reprovaria mais do que passa.
- Não toque na fórmula dos objetivos nem da janela de sorteio para bater a meta — o eixo de calibragem é o limite de movimentos.

- [ ] **Step 4: Re-run the suite**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` e `All tests passed!`

Os testes da Task 1 travam invariantes, não números específicos, então a calibragem não deve quebrá-los. Se quebrar, a constante nova violou uma invariante — corrija a constante.

- [ ] **Step 5: Document in CLAUDE.md**

Acrescente uma seção "### Fase 15: Campanha Infinita (`LevelGenerator`) ✅ Concluída" ao roadmap, no estilo das anteriores: as decisões e os *porquês*, não a lista de arquivos. Cubra, no mínimo:
- por que `levelAt` é função e não lista;
- por que a seed determina o contrato mas **não** o tabuleiro (e que isso preserva a decisão da Fase 13);
- por que a dificuldade não escala pelo dígito-alvo (teto do `kMaxDigit`) e escala por `count`, movimentos e coberturas;
- por que o degrau da janela cicla a partir de 2 e nunca volta a 0;
- por que o denominador da barra virou o capítulo;
- por que o histórico de fases precisa de poda, e o que a poda preserva;
- os números medidos em `--mode=generated`, com a ressalva do piso nas fases de cobertura.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: calibragem das fases geradas por simulação

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Verificação final

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `All tests passed!`
- [ ] `dart run tool/simulate_economy.dart --mode=generated` → sete amostras, fases de dígito em 70-90%
- [ ] `grep -rn "kCampaignStarTotal\|chapterComingSoon" lib test` → sem resultado
- [ ] `grep -rn "kCampaign\b" lib` → só em `game_level.dart` (a definição) e `level_catalog.dart` (o consumo)
- [ ] Nenhuma dependência nova em `pubspec.yaml`; nenhuma chamada de rede adicionada
