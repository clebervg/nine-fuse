# Barra de estrelas do capítulo — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrar, no cartão de vitória da campanha, uma barra que se preenche das estrelas que o jogador já tinha no capítulo até as que ele acabou de conquistar.

**Architecture:** `CampaignRecords.record()` passa a devolver quantas estrelas foram efetivamente ganhas — é o único ponto que enxerga o antes e o depois, já que o merge guarda o melhor de cada fase. Um widget novo e sem Riverpod, `ChapterStarProgress`, recebe o total do capítulo e esse ganho por parâmetro e anima a diferença. `LevelOutcomeCard` ganha dois parâmetros opcionais e desenha a barra só no ramo de vitória; `GameScreen` guarda o retorno de `record()` e os repassa.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), `flutter_localizations` + `gen-l10n`, `flutter_test` com goldens.

## Global Constraints

- **O repositório git foi criado em 2026-08-09**, e o trabalho corre na branch `feat/chapter-star-progress`. Cada tarefa termina com `flutter analyze && flutter test` verdes **e um commit** dos arquivos que ela tocou, em português, no formato `feat: <o que passou a existir>` (ou `test:` / `docs:` quando for só isso). Não faça commit com a suíte vermelha.
- **Proibido texto literal na UI.** Todo texto visível ao jogador vem do `AppLocalizations`, com tradução em `lib/l10n/app_en.arb` **e** `lib/l10n/app_pt.arb`. O template é o **inglês**.
- **Após mexer em qualquer `.arb`, rode `flutter gen-l10n`.** Os arquivos `lib/l10n/app_localizations*.dart` são gerados; não os edite à mão.
- **Nenhuma animação em repetição.** Toda animação nova toca uma vez e para. Repetição faz `pumpAndSettle` nunca terminar e derruba a suíte de widget inteira.
- **`FractionallySizedBox` com `DecoratedBox` sem filho exige `heightFactor: 1`.** Sem ele a barra colapsa para altura zero e some da tela sem nenhum teste reclamar.
- **`Semantics` que rotula um texto já legível leva `excludeSemantics: true`,** senão o leitor de tela anuncia a frase e depois o número solto.
- **Nunca `Opacity` nem `FadeTransition` dentro de `TileWidget`.** Não toque nesse widget neste plano.
- **Testes de widget fixam o locale** com `locale: kTestLocale` (de `test/support/localized.dart`); sem isso as asserções em português passam a afirmar algo sobre o locale da máquina.
- Comentários e documentação do código em **português**, seguindo o estilo do projeto (explicam *por quê*, não *o quê*).
- Validação final: `flutter analyze` sem achados e `flutter test` com aprovação integral.

---

### Task 1: `CampaignRecords.record()` devolve o ganho de estrelas

**Files:**
- Modify: `lib/features/game/providers/campaign_records.dart:54-65`
- Test: `test/features/game/providers/campaign_records_test.dart`

**Interfaces:**
- Consumes: `LevelRecord`, `CampaignRecords`, `InMemoryGameStorage` (já existem).
- Produces: `int CampaignRecords.record(int levelNumber, {required int stars, required int score})` — devolve `merged.stars - (existing?.stars ?? 0)`, sempre `>= 0`.

- [ ] **Step 1: Escrever os testes que falham**

Acrescente este grupo em `test/features/game/providers/campaign_records_test.dart`, logo após o teste `'conta estrelas por capítulo'` (por volta da linha 105):

```dart
    group('o retorno diz quantas estrelas entraram', () {
      test('a primeira vitória devolve as estrelas todas', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        expect(records.record(1, stars: 2, score: 100), 2);
      });

      test('rejogar melhor devolve só a diferença', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        records.record(1, stars: 1, score: 100);

        expect(records.record(1, stars: 3, score: 900), 2);
      });

      // O merge guarda o melhor de cada fase, então rejogar pior não tira
      // estrela — e também não dá nenhuma. A barra do capítulo não pode animar
      // um ganho que não houve.
      test('rejogar igual ou pior devolve zero', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        records.record(1, stars: 3, score: 900);

        expect(records.record(1, stars: 3, score: 900), 0);
        expect(records.record(1, stars: 1, score: 10), 0);
      });

      // Placar melhor com a mesma nota grava (o melhor placar mudou) mas não
      // acrescenta estrela nenhuma.
      test('só o placar melhorou: grava, mas devolve zero', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        records.record(1, stars: 2, score: 100);

        expect(records.record(1, stars: 2, score: 800), 0);
        expect(records.totalScore, 800);
      });
    });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/providers/campaign_records_test.dart`
Expected: FALHA de compilação — `This expression has a type of 'void' so its value can't be used.`

- [ ] **Step 3: Implementar**

Em `lib/features/game/providers/campaign_records.dart`, substitua o método `record` inteiro por:

```dart
  /// Registra o resultado de uma fase vencida, guardando o melhor.
  ///
  /// Devolve **quantas estrelas entraram** com este resultado. Quem pergunta é
  /// a barra do capítulo no cartão de vitória: ela precisa saber de onde
  /// começar a animar, e no instante em que o cartão renderiza o total já
  /// inclui o ganho. O número também não é dedutível da partida — o merge
  /// guarda o melhor, então rejogar com nota igual ou pior rende zero mesmo
  /// tirando três estrelas. Só este método enxerga os dois lados da conta.
  int record(int levelNumber, {required int stars, required int score}) {
    final fresh = LevelRecord(stars: stars, bestScore: score);
    final existing = state[levelNumber];
    final merged = existing == null ? fresh : existing.mergedWith(fresh);
    final gained = merged.stars - (existing?.stars ?? 0);

    // Nada mudou: não vale um estado novo nem uma gravação em disco.
    if (existing == merged) return 0;

    state = {...state, levelNumber: merged};
    _persist();
    return gained;
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/providers/campaign_records_test.dart`
Expected: todos os testes PASSAM.

- [ ] **Step 5: Conferir que nada mais quebrou**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` e suíte inteira verde. `record()` era usado só em `game_screen.dart:82`, como comando; ignorar um retorno não é erro em Dart.

---

### Task 2: A chave de tradução do rótulo semântico

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_pt.arb`
- Generated: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_pt.dart`
- Test: `test/l10n/arb_consistency_test.dart` (já existente, roda sem alteração)

**Interfaces:**
- Produces: `String AppLocalizations.chapterStarsSemantics(int stars, int total, String chapter)` — ex.: `"12 of 18 stars in Chapter 1: Primary Fusions."`

- [ ] **Step 1: Acrescentar a chave no template inglês**

Em `lib/l10n/app_en.arb`, antes da chave `"bonusMoves"`, insira:

```json
  "chapterStarsSemantics": "{stars} of {total} stars in {chapter}.",
  "@chapterStarsSemantics": {
    "placeholders": {
      "stars": { "type": "int" },
      "total": { "type": "int" },
      "chapter": { "type": "String" }
    }
  },

```

- [ ] **Step 2: Acrescentar a tradução em português**

Em `lib/l10n/app_pt.arb`, antes da chave `"bonusMoves"`, insira:

```json
  "chapterStarsSemantics": "{stars} de {total} estrelas em {chapter}.",

```

Não repita o bloco `"@chapterStarsSemantics"`: os metadados moram só no template.

- [ ] **Step 3: Gerar o código de localização**

Run: `flutter gen-l10n`
Expected: termina sem saída de erro; `lib/l10n/app_localizations.dart` passa a declarar `chapterStarsSemantics`.

- [ ] **Step 4: Verificar que os dois ARB continuam coerentes**

Run: `flutter test test/l10n/arb_consistency_test.dart`
Expected: PASSA. Esse teste lê os dois `.arb` como arquivos e exige conjunto de chaves idêntico e nenhum valor vazio — é o que impede a chave existir só em inglês e o jogador brasileiro receber a frase traduzida pela metade.

- [ ] **Step 5: Conferir a suíte**

Run: `flutter analyze && flutter test`
Expected: verde.

---

### Task 3: O widget `ChapterStarProgress`

**Files:**
- Create: `lib/features/game/presentation/widgets/victory_dialog.dart`
- Test: `test/features/game/presentation/victory_dialog_test.dart` (criar)

**Interfaces:**
- Consumes: `CampaignChapter` e `chapterOf` (`domain/campaign_chapter.dart`), `chapterTitle(chapter)` (extensão `DomainLabels` em `presentation/l10n_labels.dart`), `AppLocalizations.chapterStarsSemantics` (Task 2), `AppColors`, `AppFonts`.
- Produces:
  - `class ChapterStarProgress extends StatelessWidget` com `({Key? key, required CampaignChapter chapter, required int starsInChapter, required int starsGained})`
  - `const Key chapterStarProgressKey = Key('chapter_star_progress')`
  - `const Key chapterStarFillKey = Key('chapter_star_fill')`
  - `static const Duration ChapterStarProgress.fillDuration`

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/features/game/presentation/victory_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/widgets/victory_dialog.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

void main() {
  // O capítulo 1 tem 6 fases, logo 18 estrelas em jogo.
  final chapter = kChapters.first;

  Future<void> pumpBar(
    WidgetTester tester, {
    required int starsInChapter,
    required int starsGained,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ChapterStarProgress(
                chapter: chapter,
                starsInChapter: starsInChapter,
                starsGained: starsGained,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A fração que a barra desenha neste instante.
  double fillFactor(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(find.byKey(chapterStarFillKey))
      .widthFactor!;

  testWidgets('mostra o capítulo e o par estrelas/total', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 3);
    await tester.pumpAndSettle();

    expect(find.text('Capítulo 1: Fusões Primárias'), findsOneWidget);
    expect(find.text('12/18'), findsOneWidget);
  });

  testWidgets('parte do total anterior e chega no novo', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 3);

    // Primeiro quadro: ainda no que o jogador tinha antes desta fase (9/18).
    expect(fillFactor(tester), closeTo(9 / 18, 0.001));

    // A animação é finita, então `pumpAndSettle` termina — e o fato de
    // terminar é parte do que este teste garante: animação em repetição
    // derrubaria a suíte inteira.
    await tester.pumpAndSettle();

    expect(fillFactor(tester), closeTo(12 / 18, 0.001));
  });

  testWidgets('sem ganho, a barra nasce parada no total', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 0);

    expect(fillFactor(tester), closeTo(12 / 18, 0.001));

    await tester.pumpAndSettle();

    expect(fillFactor(tester), closeTo(12 / 18, 0.001));
  });

  testWidgets('o capítulo cheio enche a barra', (tester) async {
    await pumpBar(tester, starsInChapter: 18, starsGained: 3);
    await tester.pumpAndSettle();

    expect(fillFactor(tester), closeTo(1, 0.001));
    expect(find.text('18/18'), findsOneWidget);
  });

  // "12/18" lido em voz alta não diz de que é a fração. O rótulo diz — e
  // `excludeSemantics` impede o leitor de anunciar a frase e depois o número
  // solto, defeito já corrigido no cabeçalho do mapa.
  testWidgets('anuncia a fração por extenso, uma vez só', (tester) async {
    await pumpBar(tester, starsInChapter: 12, starsGained: 3);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        '12 de 18 estrelas em Capítulo 1: Fusões Primárias.',
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/victory_dialog_test.dart`
Expected: FALHA — `Target of URI doesn't exist: '.../victory_dialog.dart'`.

- [ ] **Step 3: Escrever o widget**

Crie `lib/features/game/presentation/widgets/victory_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do bloco inteiro, para o cartão de vitória afirmar que ele está lá.
const Key chapterStarProgressKey = Key('chapter_star_progress');

/// Chave da parte preenchida da barra. É por ela que o teste lê a fração
/// desenhada em cada quadro.
const Key chapterStarFillKey = Key('chapter_star_fill');

/// Quanto o jogador já juntou do capítulo, e o que esta fase acrescentou.
///
/// Mora num arquivo próprio, e não em `level_outcome_card.dart`: aquele já
/// carrega estrelas, confetes e botões, e uma barra de progresso de capítulo só
/// faz sentido na **vitória** — nenhuma das duas derrotas tem o que somar.
class ChapterStarProgress extends StatelessWidget {
  const ChapterStarProgress({
    super.key,
    required this.chapter,
    required this.starsInChapter,
    required this.starsGained,
  });

  final CampaignChapter chapter;

  /// Total de estrelas do capítulo **já incluindo** o que esta fase rendeu.
  final int starsInChapter;

  /// Quantas entraram agora. Zero quando o jogador rejogou sem melhorar a
  /// nota — e aí a barra não anima, porque não houve ganho para mostrar.
  final int starsGained;

  /// Toca uma vez e para. Animação em repetição faz `pumpAndSettle` nunca
  /// terminar e derruba a suíte de widget — mesma regra do brilho da dica, do
  /// pulso do mapa e do selo do maior bloco.
  static const Duration fillDuration = Duration(milliseconds: 900);

  double get _fraction => _fractionOf(starsInChapter);

  double get _previousFraction => _fractionOf(starsInChapter - starsGained);

  double _fractionOf(int stars) {
    final total = chapter.starTotal;
    if (total <= 0) return 0;
    return (stars / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n.chapterTitle(chapter);

    return Semantics(
      key: chapterStarProgressKey,
      // Sem isto o leitor anuncia a frase e **depois** "12/18" e o título
      // soltos, que é a mesma ambiguidade que a frase existe para resolver.
      excludeSemantics: true,
      label: l10n.chapterStarsSemantics(starsInChapter, chapter.starTotal, title),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$starsInChapter/${chapter.starTotal}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: AppColors.digit3,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Track(from: _previousFraction, to: _fraction),
        ],
      ),
    );
  }
}

/// A trilha e a parte preenchida.
class _Track extends StatelessWidget {
  const _Track({required this.from, required this.to});

  final double from;
  final double to;

  static const double _height = 7;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(_height / 2),
    child: SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.darkBackground),
        // `TweenAnimationBuilder` anima de `begin` até `end` na primeira
        // construção, que é exatamente o que se quer aqui: o cartão aparece
        // com o total antigo e ele sobe sozinho. Sem ganho, `begin == end` e
        // nada se move.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: from, end: to),
          duration: ChapterStarProgress.fillDuration,
          curve: Curves.easeOutCubic,
          // A chave fica no `FractionallySizedBox` porque é ele que carrega a
          // fração desenhada — é o que o teste mede a cada quadro.
          builder: (context, value, _) => FractionallySizedBox(
            key: chapterStarFillKey,
            alignment: Alignment.centerLeft,
            widthFactor: value,
            // Sem `heightFactor: 1` um `DecoratedBox` sem filho colapsa para
            // altura zero e a barra some — foi o que aconteceu com a barra do
            // objetivo no HUD, e nenhum teste acusou.
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.digit3),
            ),
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/victory_dialog_test.dart`
Expected: os cinco testes PASSAM.

- [ ] **Step 5: Conferir a suíte**

Run: `flutter analyze && flutter test`
Expected: verde.

---

### Task 4: `LevelOutcomeCard` desenha a barra na vitória

**Files:**
- Modify: `lib/features/game/presentation/widgets/level_outcome_card.dart:20-45` (construtor e campos) e `:102-128` (a `Column` do conteúdo)
- Test: `test/features/game/presentation/level_outcome_card_test.dart`

**Interfaces:**
- Consumes: `ChapterStarProgress`, `chapterStarProgressKey` (Task 3); `chapterOf` (`domain/campaign_chapter.dart`).
- Produces: `LevelOutcomeCard` com dois parâmetros nomeados novos e **opcionais**: `int? starsInChapter`, `int? starsGained`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/game/presentation/level_outcome_card_test.dart`, acrescente os dois parâmetros ao helper `pumpCard` (linhas 17-24 e a chamada do construtor em 38-50):

```dart
  Future<void> pumpCard(
    WidgetTester tester, {
    required GameStatus status,
    LossReason? lossReason,
    int moves = 10,
    int bonusMoves = 0,
    GameLevel target = level,
    int? starsInChapter,
    int? starsGained,
  }) async {
```

e, dentro do construtor do `LevelOutcomeCard` nesse helper, logo depois de `onEndless: () {},`:

```dart
                starsInChapter: starsInChapter,
                starsGained: starsGained,
```

Depois acrescente este grupo ao fim do `main()` do mesmo arquivo:

```dart
  group('barra de estrelas do capítulo', () {
    testWidgets('aparece na vitória quando os números chegam', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.won,
        starsInChapter: 12,
        starsGained: 3,
      );

      expect(find.byKey(chapterStarProgressKey), findsOneWidget);
      // A fase 4 é do capítulo 1, que tem 6 fases e portanto 18 estrelas.
      expect(find.text('12/18'), findsOneWidget);
    });

    // Os números são opcionais porque seis arquivos de teste constroem este
    // cartão direto; sem eles, o cartão continua sendo o de antes.
    testWidgets('sem os números, não desenha nada', (tester) async {
      await pumpCard(tester, status: GameStatus.won);

      expect(find.byKey(chapterStarProgressKey), findsNothing);
    });

    // Derrota não tem estrela para somar, e a barra ali leria como consolo.
    testWidgets('não aparece na derrota', (tester) async {
      await pumpCard(
        tester,
        status: GameStatus.lost,
        lossReason: LossReason.moveLimitReached,
        starsInChapter: 12,
        starsGained: 0,
      );

      expect(find.byKey(chapterStarProgressKey), findsNothing);
    });
  });
```

E acrescente o import no topo do arquivo de teste:

```dart
import 'package:nine_fuse/features/game/presentation/widgets/victory_dialog.dart';
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/level_outcome_card_test.dart`
Expected: FALHA de compilação — `No named parameter with the name 'starsInChapter'`.

- [ ] **Step 3: Acrescentar os parâmetros ao widget**

Em `lib/features/game/presentation/widgets/level_outcome_card.dart`, acrescente os imports:

```dart
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/presentation/widgets/victory_dialog.dart';
```

Depois substitua o construtor e o bloco de campos (linhas 21-36) por:

```dart
  const LevelOutcomeCard({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onNext,
    required this.onBack,
    this.onEndless,
    this.starsInChapter,
    this.starsGained,
  });

  final GameState state;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// Oferecido só ao vencer a última fase, como continuação da campanha.
  final VoidCallback? onEndless;

  /// Estrelas acumuladas no capítulo desta fase, já contando esta partida, e
  /// quantas entraram agora.
  ///
  /// Opcionais porque quem os conhece é a tela, que lê o `CampaignRecords`;
  /// este cartão é `StatelessWidget` sem provider de propósito, e é isso que
  /// permite testá-lo sem `ProviderScope`. Nulos, a barra não é desenhada.
  final int? starsInChapter;
  final int? starsGained;
```

- [ ] **Step 4: Desenhar a barra**

No `build`, dentro da `Column` do `GameDialog`, insira o bloco **entre** o `Text` do `_message` (com o `_detail` opcional que vem logo depois) e o `Text` do `l10n.outcomeScore` — ou seja, imediatamente antes de `const SizedBox(height: 6),` que precede `l10n.outcomeScore`:

```dart
          // Abaixo das estrelas da fase e acima do placar: a ordem vai do
          // imediato (o que esta partida rendeu) para o acumulado (o que o
          // capítulo já tem), sem empurrar "PRÓXIMA FASE" para fora da dobra.
          if (_won && starsInChapter != null && starsGained != null) ...[
            const SizedBox(height: 14),
            ChapterStarProgress(
              chapter: chapterOf(state.level.number),
              starsInChapter: starsInChapter!,
              starsGained: starsGained!,
            ),
          ],
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/level_outcome_card_test.dart`
Expected: PASSA, inclusive os testes que já existiam.

- [ ] **Step 6: Conferir a suíte**

Run: `flutter analyze && flutter test`
Expected: verde, exceto possivelmente o golden `level_outcome.png` — que só muda na Task 6, porque `hud_golden_test.dart` ainda não passa os parâmetros novos. Se algum golden falhar aqui, **pare e investigue**: significa que o cartão mudou sem os parâmetros, o que contraria o desenho.

---

### Task 5: `GameScreen` alimenta a barra

**Files:**
- Modify: `lib/features/game/presentation/screens/game_screen.dart:57` (campo do `State`), `:74-89` (o `ref.listen`), `:70-72` (o `build`) e `:203-212` (a construção do cartão)
- Test: `test/features/game/presentation/game_screen_test.dart`

**Interfaces:**
- Consumes: `int CampaignRecords.record(...)` (Task 1); `CampaignRecords.starsInChapter(chapter)`; `chapterOf`; `LevelOutcomeCard(starsInChapter:, starsGained:)` (Task 4).
- Produces: nada para tarefas posteriores.

- [ ] **Step 1: Escrever o teste que falha**

Acrescente ao fim do `main()` de `test/features/game/presentation/game_screen_test.dart`. Este teste **reaproveita os helpers que o arquivo já tem** (`pumpGame`, `findSwap`, `playSwap`) e o mesmo laço de vitória do teste `'vencer mostra o cartão de fase concluída'` (linha 136) — não invente mecanismo novo e **não** acrescente API de depuração ao `GameNotifier`:

```dart
  testWidgets('a vitória mostra a barra de estrelas do capítulo', (
    tester,
  ) async {
    // Objetivo mínimo: cai no primeiro movimento válido, como no teste do
    // cartão de fase concluída.
    const trivial = GameLevel(
      number: 43,
      objective: Objective(digit: 4),
      moveLimit: 30,
    );
    await pumpGame(tester, level: trivial);

    for (
      int i = 0;
      i < 20 && notifier.state.status == GameStatus.playing;
      i++
    ) {
      final pair = findSwap(creatingMatch: true);
      if (pair == null) break;
      await playSwap(tester, pair);
    }

    expect(notifier.state.status, GameStatus.won);
    expect(find.byKey(chapterStarProgressKey), findsOneWidget);
  });
```

Acrescente o import no topo do arquivo de teste:

```dart
import 'package:nine_fuse/features/game/presentation/widgets/victory_dialog.dart';
```

Nota sobre o `campaignRecordsProvider`: `pumpGame` sobrescreve apenas o `gameProvider`, então o `CampaignRecords` real é construído com `PrefsGameStorage`. Isso **já** acontece hoje (a tela chama `record()` desde antes deste plano) e não quebra nada — `CampaignRecords` engole falha de disco e de plugin, por desenho. Não acrescente override; fazê-lo divergiria do resto do arquivo sem ganho.

A fase 43 não pertence a nenhum capítulo declarado, e `chapterOf` cai no último de propósito — é a garantia de que estender a campanha sem estender os capítulos não quebra a tela.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/game/presentation/game_screen_test.dart`
Expected: FALHA — `Expected: exactly one matching candidate / Actual: _KeyFinder: found no widgets`.

- [ ] **Step 3: Guardar o ganho no `State`**

Em `lib/features/game/presentation/screens/game_screen.dart`, logo abaixo do campo `bool _ready = false;`:

```dart
  /// Quantas estrelas de capítulo a última vitória acrescentou.
  ///
  /// Vem do retorno de `CampaignRecords.record()`, e não de uma conta feita
  /// aqui: quando o cartão renderiza, o total do capítulo **já inclui** esta
  /// fase, e rejogar sem melhorar a nota rende zero mesmo tirando três
  /// estrelas. Só o notifier enxerga os dois lados.
  int _chapterStarsGained = 0;
```

- [ ] **Step 4: Capturar o retorno no `ref.listen`**

Substitua o trecho do `ref.listen` que chama `record` por:

```dart
        _chapterStarsGained = ref
            .read(campaignRecordsProvider.notifier)
            .record(
              next.level.number,
              stars: starRating(
                movesLeft: next.movesLeft,
                movesAvailable: next.movesAvailable,
              ),
              score: next.score,
            );
```

Sem `setState`: a atribuição acontece durante a notificação do `gameProvider`, que o `build` já observa com `ref.watch` — o rebuild vem de qualquer forma, e chamar `setState` aqui arrisca reentrada.

- [ ] **Step 5: Ler o total do capítulo e passar ao cartão**

No início do `build`, logo depois de `final notifier = ref.read(gameProvider.notifier);`:

```dart
    // Observar o mapa é o que faz a barra reagir quando a leitura do disco
    // chega depois da abertura da tela; o total sai do notifier.
    ref.watch(campaignRecordsProvider);
    final chapterStars = ref
        .read(campaignRecordsProvider.notifier)
        .starsInChapter(chapterOf(state.level.number));
```

E, na construção do `LevelOutcomeCard` (por volta da linha 203), acrescente:

```dart
                  starsInChapter: chapterStars,
                  starsGained: _chapterStarsGained,
```

Acrescente o import de `campaign_chapter.dart` se ele ainda não estiver no arquivo:

```dart
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/game/presentation/game_screen_test.dart`
Expected: PASSA.

- [ ] **Step 7: Conferir a suíte**

Run: `flutter analyze && flutter test`
Expected: verde, com a possível exceção do golden `level_outcome.png`, tratada na Task 6.

---

### Task 6: Inglês, golden e registros

**Files:**
- Modify: `test/l10n/english_screens_test.dart:103-118` (o helper `card`) e o grupo de vitória
- Modify: `test/features/game/presentation/hud_golden_test.dart:125-147`
- Regravar: `test/features/game/presentation/goldens/level_outcome.png`
- Modify: `CLAUDE.md:853-857`

**Interfaces:**
- Consumes: tudo das tarefas 1 a 5.
- Produces: nada.

- [ ] **Step 1: O par inglês/português da chave nova**

Em `test/l10n/english_screens_test.dart`, acrescente os parâmetros ao helper `card` (linha 103):

```dart
    Widget card({
      required GameStatus status,
      LossReason? reason,
      int moves = 8,
      int? starsInChapter,
      int? starsGained,
    }) => LevelOutcomeCard(
      state: GameState(
        board: Board.empty(),
        level: level,
        status: status,
        lossReason: reason,
        moves: moves,
      ),
      onRetry: () {},
      onNext: () {},
      onBack: () {},
      starsInChapter: starsInChapter,
      starsGained: starsGained,
    );
```

E acrescente este teste ao mesmo grupo:

```dart
    // As asserções vêm em par: o texto inglês aparece **e** o português não.
    // Só a primeira metade deixaria passar um widget que mostrasse os dois.
    testWidgets('barra de capítulo em inglês', (tester) async {
      await pumpEn(
        tester,
        card(status: GameStatus.won, starsInChapter: 12, starsGained: 3),
      );

      expect(find.text('Chapter 1: Primary Fusions'), findsOneWidget);
      expect(find.text('Capítulo 1: Fusões Primárias'), findsNothing);
    });
```

Os textos estão conferidos contra `lib/l10n/app_en.arb`: `chapterLabel` é `"Chapter {number}: {name}"` e `chapterPrimaryFusions` é `"Primary Fusions"`. A fase do helper é a de número 4, que pertence ao capítulo 1 — daí "Chapter 1: Primary Fusions" e o total de 18.

- [ ] **Step 2: Rodar e ver passar**

Run: `flutter test test/l10n/english_screens_test.dart`
Expected: PASSA.

- [ ] **Step 3: Passar os números para o golden**

Em `test/features/game/presentation/hud_golden_test.dart`, no teste `'cartão de vitória, com o selo do título'`, acrescente ao `LevelOutcomeCard`:

```dart
        starsInChapter: 12,
        starsGained: 3,
```

e aumente a caixa de `const Size(420, 560)` para `const Size(420, 620)`, porque a barra acrescenta altura ao cartão.

- [ ] **Step 4: Ver o golden falhar e conferir o diff**

Run: `flutter test test/features/game/presentation/hud_golden_test.dart`
Expected: FALHA do golden, com os arquivos gravados em `test/features/game/presentation/failures/`.

Abra `failures/level_outcome_isolatedDiff.png` e confira: só a barra nova e o deslocamento vertical do que ficou abaixo dela devem aparecer. **Se aparecer qualquer outra diferença — estrelas, confetes, botão —, pare e investigue em vez de regravar.** Esse é o ritual do projeto para decidir entre regravar e investigar.

- [ ] **Step 5: Regravar o golden**

Run: `flutter test --update-goldens test/features/game/presentation/hud_golden_test.dart`
Expected: PASSA e `goldens/level_outcome.png` é reescrito.

Depois: `flutter test test/features/game/presentation/hud_golden_test.dart`
Expected: PASSA sem `--update-goldens`.

- [ ] **Step 6: Atualizar o CLAUDE.md**

Em `CLAUDE.md`, substitua o parágrafo das linhas 853-857 por:

```markdown
**A contagem por capítulo passou a ser usada.** `CampaignChapter.starTotal` e
`CampaignRecords.starsInChapter` ficaram um bom tempo escritos sem nenhum
consumidor — foram feitos para esta leitura e pararam no meio do caminho.
Agora alimentam a barra de estrelas do capítulo no cartão de vitória
(`presentation/widgets/victory_dialog.dart`). O denominador do **cabeçalho do
mapa** continua sendo o da campanha inteira, e há teste que exige isso: as duas
leituras convivem de propósito, e uma "correção" futura não pode trocar uma
pela outra.
```

- [ ] **Step 7: Validação final**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: todos os testes passam, goldens incluídos.

---

## Verificação de cobertura

| Requisito da spec | Tarefa |
|---|---|
| `record()` devolve o ganho | 1 |
| Chave de tradução (en + pt) | 2 |
| `victory_dialog.dart` com `ChapterStarProgress` | 3 |
| Título do capítulo, barra e `12/18` | 3 |
| `TweenAnimationBuilder` do valor antigo ao novo | 3 |
| `heightFactor: 1`, `excludeSemantics`, animação finita | 3 |
| Parâmetros opcionais no `LevelOutcomeCard`, posição na coluna | 4 |
| Ligação no `GameScreen` | 5 |
| Teste do retorno de `record()`, incluindo "rejogou pior" | 1 |
| Teste do widget novo | 3 |
| Teste "com/sem parâmetros" no cartão | 4 |
| Par inglês/português | 6 |
| Golden regravado com `isolatedDiff` conferido | 6 |
| Ponta solta removida do CLAUDE.md | 6 |
| `flutter analyze` + `flutter test` | 6 |
