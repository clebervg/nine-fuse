@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/board.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_banner.dart';
import 'package:nine_fuse/features/game/presentation/widgets/level_outcome_card.dart';
import 'package:nine_fuse/features/game/providers/game_state.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import '../../../support/localized.dart';

/// Referência visual do HUD e da caixa de mensagem.
///
/// O acabamento destes dois é o que decide se o jogo parece jogo ou aplicativo,
/// e nenhuma asserção de texto pega degradê, aro ou o selo do título saindo da
/// caixa. Serve também de trava: mexer em sombra ou moldura sem querer falha
/// aqui.
///
/// Regerar após mudança visual proposital:
///   flutter test --update-goldens test/features/game/presentation/hud_golden_test.dart
Future<void> _loadFonts() async {
  final loader = FontLoader(AppFonts.display);
  for (final weight in const ['Bold', 'ExtraBold', 'Black']) {
    loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await loader.load();

  // Sem a MaterialIcons, o alvo, o troféu, o raio e as estrelas viram
  // quadrados — e as pílulas do HUD são feitas justamente desses símbolos.
  // Diferente da Nunito, ela vem do pacote do Flutter e o caminho pode mudar
  // entre versões, então a falha não pode derrubar o teste: perde-se nitidez
  // no golden, não a suíte.
  try {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  } catch (_) {
    // Segue com os quadrados.
  }
}

void main() {
  setUpAll(_loadFonts);

  const level = GameLevel(
    number: 6,
    objective: Objective(digit: 6, count: 3),
    moveLimit: 45,
  );

  Future<void> pumpOn(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        // A fonte ambiente do `flutter_test` desenha cada glifo como um
        // retângulo cheio. Os rótulos das pílulas não pedem família própria —
        // no app quem a fornece é o tema —, então aqui ela vem do tema também.
        theme: ThemeData(fontFamily: AppFonts.display),
        home: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('HUD da campanha, com as três pílulas', (tester) async {
    await pumpOn(
      tester,
      LevelBanner(
        state: GameState(
          board: Board.empty(),
          level: level,
          score: 3480,
          moves: 12,
          objectiveProgress: 1,
        ),
      ),
      const Size(400, 260),
    );

    await expectLater(
      find.byType(LevelBanner),
      matchesGoldenFile('goldens/game_hud.png'),
    );
  });

  testWidgets('HUD na reta final, com o alerta aceso', (tester) async {
    // O aro vermelho e o neon só existem aqui; um golden do estado calmo não
    // mostraria nada disso.
    await pumpOn(
      tester,
      LevelBanner(
        state: GameState(
          board: Board.empty(),
          level: level,
          score: 9120,
          moves: 43,
          objectiveProgress: 2,
        ),
      ),
      const Size(400, 260),
    );

    await expectLater(
      find.byType(LevelBanner),
      matchesGoldenFile('goldens/game_hud_urgent.png'),
    );
  });

  testWidgets('cartão de vitória, com o selo do título', (tester) async {
    await pumpOn(
      tester,
      LevelOutcomeCard(
        state: GameState(
          board: Board.empty(),
          level: level,
          score: 12400,
          moves: 20,
          status: GameStatus.won,
          objectiveProgress: 3,
        ),
        onRetry: () {},
        onNext: () {},
        onBack: () {},
        starsInChapter: 12,
        starsGained: 3,
      ),
      const Size(420, 620),
    );

    await expectLater(
      find.byType(LevelOutcomeCard),
      matchesGoldenFile('goldens/level_outcome.png'),
    );
  });
}
