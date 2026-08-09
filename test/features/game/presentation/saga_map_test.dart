import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/presentation/widgets/campaign_header.dart';
import 'package:nine_fuse/features/game/presentation/widgets/endless_highlight.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import '../../../support/localized.dart';

void main() {
  late InMemoryGameStorage storage;
  late ProviderContainer container;

  void buildContainer() {
    container = ProviderContainer(
      overrides: [
        endlessProvider.overrideWith(
          (ref) => EndlessNotifier(random: Random(1), storage: storage),
        ),
        campaignProgressProvider.overrideWith(
          (ref) => CampaignProgress(storage: storage),
        ),
        campaignRecordsProvider.overrideWith(
          (ref) => CampaignRecords(storage: storage),
        ),
        endlessHighScoreProvider.overrideWith(
          (ref) => EndlessHighScore(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  setUp(() {
    storage = InMemoryGameStorage();
  });

  /// Monta o mapa. [size] permite trocar de aparelho no meio do teste.
  Future<void> pumpMap(
    WidgetTester tester, {
    Size size = const Size(1200, 2600),
    double pixelRatio = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);

    buildContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const LevelSelectScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('geometria da trilha', () {
    test('a fase 1 fica embaixo e a última em cima', () {
      const geometry = SagaGeometry(width: 400, levelCount: 10);

      expect(
        geometry.centerOf(0).dy,
        greaterThan(geometry.centerOf(9).dy),
        reason: 'a trilha sobe: a primeira fase é o pé do caminho',
      );
    });

    test('os pins alternam de lado, formando o sinuoso', () {
      const geometry = SagaGeometry(width: 400, levelCount: 6);
      final centre = 400 / 2;

      // Ondulação: um pin ao centro, um à direita, um ao centro, um à esquerda.
      expect(geometry.centerOf(0).dx, closeTo(centre, 0.01));
      expect(geometry.centerOf(1).dx, greaterThan(centre));
      expect(geometry.centerOf(2).dx, closeTo(centre, 0.01));
      expect(geometry.centerOf(3).dx, lessThan(centre));
    });

    test('o espaçamento vertical é sempre o mesmo', () {
      const geometry = SagaGeometry(width: 400, levelCount: 10);

      for (int i = 1; i < 10; i++) {
        expect(
          geometry.centerOf(i - 1).dy - geometry.centerOf(i).dy,
          closeTo(SagaGeometry.step, 0.01),
        );
      }
    });

    // Num tablet a amplitude proporcional jogaria os pins nas bordas, e a
    // trilha viraria um zigue-zague de canto a canto em vez de um caminho.
    test('a amplitude tem teto, para o tablet não esticar a trilha', () {
      const narrow = SagaGeometry(width: 320, levelCount: 10);
      const tablet = SagaGeometry(width: 1200, levelCount: 10);

      // Na tela larga a amplitude para de crescer.
      expect(tablet.amplitude, SagaGeometry.maxAmplitude);
      // Na estreita ela acompanha a largura, senão os pins encostariam nas
      // bordas.
      expect(narrow.amplitude, lessThan(SagaGeometry.maxAmplitude));
    });

    test('todo pin cabe na largura disponível', () {
      for (final width in [320.0, 375.0, 430.0, 834.0, 1200.0]) {
        final geometry = SagaGeometry(width: width, levelCount: 10);

        for (int i = 0; i < 10; i++) {
          final x = geometry.centerOf(i).dx;
          expect(
            x - SagaGeometry.pinSize / 2,
            greaterThanOrEqualTo(0.0),
            reason: 'pin $i saiu pela esquerda em ${width}pt',
          );
          expect(
            x + SagaGeometry.pinSize / 2,
            lessThanOrEqualTo(width),
            reason: 'pin $i saiu pela direita em ${width}pt',
          );
        }
      }
    });
  });

  group('estado dos pins', () {
    testWidgets('só a fase da vez traz o convite para jogar', (tester) async {
      await pumpMap(tester);

      // Um "JOGAR" só: se todo pin chamasse, nenhum chamaria.
      expect(find.text('JOGAR'), findsOneWidget);
    });

    testWidgets('a fase vencida mostra as estrelas que rendeu', (tester) async {
      storage.campaignProgress = 2;
      storage.levelRecords = {
        1: const LevelRecord(stars: 3, bestScore: 900),
        2: const LevelRecord(stars: 1, bestScore: 200),
      };
      await pumpMap(tester);

      // Só as da trilha: o cabeçalho também tem uma estrela, e ela não conta.
      expect(
        find.descendant(
          of: find.byType(SagaMapWidget),
          matching: find.byIcon(Icons.star_rounded),
        ),
        // Três cheias na fase 1, uma na fase 2.
        findsNWidgets(4),
      );
    });

    testWidgets('fase nunca vencida não mostra estrela nenhuma', (
      tester,
    ) async {
      await pumpMap(tester);

      expect(
        find.descendant(
          of: find.byType(SagaMapWidget),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsNothing,
      );
    });

    /// Diâmetro desenhado do círculo de um pin, sem a aura em volta.
    double pinDiameter(WidgetTester tester, int level) =>
        tester.getSize(find.byKey(pinCoreKey(level))).width;

    // O jogador tem de saber onde tocar sem procurar. Escala e aro dourado são
    // estáticos de propósito: continuam valendo com o pulso desligado.
    testWidgets('a fase da vez é maior que as outras', (tester) async {
      storage.campaignProgress = 2;
      await pumpMap(tester);

      final current = pinDiameter(tester, 3);
      final cleared = pinDiameter(tester, 1);
      final locked = pinDiameter(tester, 5);

      expect(current, closeTo(cleared * SagaGeometry.currentPinScale, 0.5));
      expect(current, greaterThan(locked));
    });

    testWidgets('a fase da vez tem aro dourado, e só ela', (tester) async {
      storage.campaignProgress = 2;
      await pumpMap(tester);

      Border? borderOf(int level) {
        final box = tester.widget<Container>(find.byKey(pinCoreKey(level)));
        return (box.decoration as BoxDecoration?)?.border as Border?;
      }

      expect(borderOf(3)?.top.color, AppColors.digit3);
      expect(borderOf(1)?.top.color, isNot(AppColors.digit3));
      expect(borderOf(5)?.top.color, isNot(AppColors.digit3));
    });

    testWidgets('tocar numa fase bloqueada não faz nada', (tester) async {
      await pumpMap(tester);

      await tester.tap(find.byKey(levelCardKey(9)), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(LevelSelectScreen), findsOneWidget);
    });
  });

  group('cabeçalho de progresso', () {
    testWidgets('soma as estrelas de todas as fases', (tester) async {
      storage.campaignProgress = 2;
      storage.levelRecords = {
        1: const LevelRecord(stars: 3, bestScore: 900),
        2: const LevelRecord(stars: 2, bestScore: 350),
      };
      await pumpMap(tester);

      expect(find.byKey(totalStarsKey), findsOneWidget);
      expect(find.text('5/$kCampaignStarTotal'), findsOneWidget);
    });

    // O contador é da campanha inteira, mas fica lado a lado com o nome de um
    // **capítulo**, que cobre só um trecho dela. Sem a legenda, "23/30" ao lado
    // de "Capítulo 2" se lê como progresso do capítulo — que tem 4 fases e 12
    // estrelas, não 30. Foi relato de jogador, não hipótese.
    testWidgets('a legenda diz que o contador é da campanha', (tester) async {
      storage.campaignProgress = kChapters.last.firstLevel;
      await pumpMap(tester);

      expect(find.text(l10nFor().starsCaption), findsOneWidget);

      // O denominador tem de ser o da campanha, e não o do capítulo em que o
      // jogador está: trocá-lo faria a legenda mentir.
      expect(find.text('0/$kCampaignStarTotal'), findsOneWidget);
      expect(
        find.text('0/${kChapters.last.starTotal}'),
        findsNothing,
        reason: 'o total do capítulo não pode aparecer no contador da conta',
      );
    });

    // "23/30" lido em voz alta não diz de que é a fração — a mesma ambiguidade
    // que a legenda resolve para quem enxerga.
    testWidgets('o leitor de tela ouve de que é a fração', (tester) async {
      final semantics = tester.ensureSemantics();
      storage.levelRecords = {1: const LevelRecord(stars: 3, bestScore: 900)};
      await pumpMap(tester);

      expect(
        find.bySemanticsLabel(l10nFor().starsSemantics(3, kCampaignStarTotal)),
        findsOneWidget,
      );

      semantics.dispose();
    });

    testWidgets('sem progresso, o placar começa zerado', (tester) async {
      await pumpMap(tester);

      expect(find.text('0/$kCampaignStarTotal'), findsOneWidget);
    });

    // O NineFuse não tem trava de vidas nem energia. Um medidor desses no topo
    // prometeria uma mecânica que o jogo não tem.
    testWidgets('não exibe medidor de energia', (tester) async {
      await pumpMap(tester);

      expect(find.byIcon(Icons.bolt_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('anuncia o capítulo da fase da vez', (tester) async {
      await pumpMap(tester);
      expect(
        find.text(l10nFor().chapterTitle(kChapters.first)),
        findsOneWidget,
      );

      // Avançar para a faixa seguinte troca o capítulo anunciado.
      container
          .read(campaignProgressProvider.notifier)
          .complete(kChapters.first.lastLevel);
      await tester.pumpAndSettle();

      expect(find.byKey(chapterLabelKey), findsOneWidget);
      expect(find.text(l10nFor().chapterTitle(kChapters.last)), findsOneWidget);
    });
  });

  group('destaque do Endless', () {
    // Ele não é fase e não pode parecer uma: fase tem objetivo, limite e fim.
    testWidgets('fica fora da trilha de pins', (tester) async {
      await pumpMap(tester);

      expect(find.byKey(endlessCardKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SagaMapWidget),
          matching: find.byKey(endlessCardKey),
        ),
        findsNothing,
      );
    });

    testWidgets('destravado, exibe o recorde do jogador', (tester) async {
      storage.campaignProgress = kEndlessUnlockLevel;
      storage.highScore = 4820;
      await pumpMap(tester);

      expect(find.text('Sua melhor pontuação: 4820 pts'), findsOneWidget);
    });

    testWidgets('travado, esconde o recorde e explica como liberar', (
      tester,
    ) async {
      storage.highScore = 4820;
      await pumpMap(tester);

      expect(find.byKey(endlessRecordKey), findsNothing);
      expect(
        find.text('Conclua a fase $kEndlessUnlockLevel para liberar'),
        findsOneWidget,
      );
    });
  });

  group('responsividade', () {
    testWidgets('cabe num iPhone SE sem estourar o layout', (tester) async {
      storage.campaignProgress = 3;
      storage.levelRecords = {
        for (int i = 1; i <= 3; i++)
          i: const LevelRecord(stars: 3, bestScore: 99999),
      };
      await pumpMap(tester, size: const Size(750, 1334), pixelRatio: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(SagaMapWidget), findsOneWidget);
      expect(find.byKey(endlessCardKey), findsOneWidget);
    });

    testWidgets('cabe num tablet sem estourar o layout', (tester) async {
      await pumpMap(tester, size: const Size(1668, 2388), pixelRatio: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(SagaMapWidget), findsOneWidget);
    });

    // O cabeçalho e o Endless ficam fora da rolagem: consultá-los não pode
    // exigir voltar ao topo do mapa.
    testWidgets('o cabeçalho não rola junto com a trilha', (tester) async {
      await pumpMap(tester, size: const Size(750, 1334), pixelRatio: 2.0);

      final before = tester.getRect(find.byType(CampaignHeader));
      await tester.drag(find.byType(SagaMapWidget), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(CampaignHeader)), before);
    });
  });

  // O mapa não pode terminar em corte seco na última fase existente: sem
  // continuidade visível, quem chega ao fim da campanha lê "acabou o jogo".
  group('continuidade da trilha', () {
    testWidgets('a trilha segue além da última fase', (tester) async {
      storage.campaignProgress = kCampaign.length;
      await pumpMap(tester);

      // Todas as fases estão vencidas — nenhum cadeado vem de fase. Os que
      // sobram na trilha são exatamente os nós projetados.
      expect(
        find.descendant(
          of: find.byType(SagaMapWidget),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNWidgets(SagaGeometry.futureNodes),
      );
    });

    // Três cadeados sozinhos dizem "travado", que é o que o pin de uma fase
    // ainda fechada também diz. O rótulo é o que transforma o fim da trilha em
    // promessa de continuação — e ele anuncia o capítulo **seguinte**, não o
    // último existente.
    testWidgets('o fim da trilha anuncia o capítulo seguinte', (tester) async {
      await pumpMap(tester);

      expect(
        find.text(l10nFor().chapterComingSoon(kChapters.last.number + 1)),
        findsOneWidget,
      );
    });

    // A altura tem de contar os nós projetados, senão eles nasceriam fora da
    // área rolável e ninguém os veria.
    test('a altura do mapa reserva espaço para os nós projetados', () {
      const geometry = SagaGeometry(width: 400, levelCount: 10);

      expect(geometry.lastIndex, 10 - 1 + SagaGeometry.futureNodes);
      expect(
        geometry.height,
        SagaGeometry.margin * 2 + SagaGeometry.step * geometry.lastIndex,
      );
      // O último nó projetado cai dentro do mapa, não acima dele.
      expect(geometry.centerOf(geometry.lastIndex).dy, greaterThan(0));
    });
  });

  // As estrelas ficam ancoradas ao círculo, e não a uma caixa: o caminho passa
  // pelo centro do pin, e um rótulo mal ancorado cavalga a curva.
  group('âncora do rótulo do pin', () {
    testWidgets('as estrelas ficam logo abaixo do círculo', (tester) async {
      // Só a fase 1 vencida: as únicas estrelas cheias do mapa são as dela,
      // então não há como confundir de qual pin elas são.
      storage.campaignProgress = 1;
      storage.levelRecords[1] = const LevelRecord(stars: 3, bestScore: 100);
      await pumpMap(tester);

      final pin = tester.getRect(find.byKey(pinCoreKey(1)));
      // Escopado ao mapa: o cabeçalho também tem uma estrela, e ela é a
      // primeira da árvore.
      final stars = tester.getRect(
        find
            .descendant(
              of: find.byType(SagaMapWidget),
              matching: find.byIcon(Icons.star_rounded),
            )
            .first,
      );

      // `bottom` negativo empurra a **borda de baixo** do rótulo para fora do
      // círculo: a fileira começa exatamente na base do pin e desce dali.
      expect(stars.bottom, closeTo(pin.bottom - kPinBadgeOffset, 1.0));
      expect(stars.top, greaterThanOrEqualTo(pin.bottom - 1));
      // A fileira inteira (primeira estrela à última) fica centrada no pin.
      final lastStar = tester.getRect(
        find
            .descendant(
              of: find.byType(SagaMapWidget),
              matching: find.byIcon(Icons.star_rounded),
            )
            .last,
      );
      expect((stars.left + lastStar.right) / 2, closeTo(pin.center.dx, 1.0));
    });
  });

  group('rolagem', () {
    // Com a campanha adiantada, abrir no pé da trilha esconde justamente o pin
    // que deveria chamar a atenção.
    testWidgets('abre centralizado na fase da vez', (tester) async {
      storage.campaignProgress = 8;
      await pumpMap(tester, size: const Size(750, 1334), pixelRatio: 2.0);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final pin = tester.getRect(find.byKey(levelCardKey(9)));

      expect(pin.top, greaterThanOrEqualTo(0.0));
      expect(
        pin.bottom,
        lessThanOrEqualTo(screen.height),
        reason: 'a fase da vez deveria estar visível ao abrir o mapa',
      );
    });

    testWidgets('sem progresso, abre na fase 1', (tester) async {
      await pumpMap(tester, size: const Size(750, 1334), pixelRatio: 2.0);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final pin = tester.getRect(find.byKey(levelCardKey(1)));

      expect(pin.bottom, lessThanOrEqualTo(screen.height));
      expect(pin.top, greaterThanOrEqualTo(0.0));
    });
  });

  group('liberação do caminho', () {
    // Voltar de uma fase vencida acende o trecho até a próxima, em vez de ele
    // já aparecer pronto.
    testWidgets('vencer uma fase anima o trecho seguinte', (tester) async {
      await pumpMap(tester);

      container.read(campaignProgressProvider.notifier).complete(1);
      await tester.pump();
      await tester.pump();

      // No meio da animação o mapa ainda está redesenhando.
      await tester.pump(kPathRevealDuration ~/ 2);
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(find.byType(SagaMapWidget), findsOneWidget);
    });
  });

  group('acessibilidade', () {
    testWidgets('cada pin se anuncia com o seu estado', (tester) async {
      storage.campaignProgress = 1;
      storage.levelRecords = {1: const LevelRecord(stars: 2, bestScore: 300)};
      await pumpMap(tester);

      final semantics = tester.getSemantics(find.byKey(levelCardKey(1)));
      expect(semantics.label, contains('concluída'));
      expect(semantics.label, contains('2 de $kStarsPerLevel'));

      expect(
        tester.getSemantics(find.byKey(levelCardKey(2))).label,
        contains('liberada'),
      );
      expect(
        tester.getSemantics(find.byKey(levelCardKey(5))).label,
        contains('bloqueada'),
      );
    });
  });
}
