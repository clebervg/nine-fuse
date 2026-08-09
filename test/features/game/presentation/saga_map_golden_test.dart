@Tags(['golden'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/presentation/screens/level_select_screen.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/endless_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import '../../../support/localized.dart';

/// Referência visual do mapa da campanha.
///
/// O mapa é a primeira tela do jogo e é onde o jogador decide se continua. Ele
/// não cabe numa asserção de texto: trilha, pins, estrelas e a ilha do Endless
/// só se julgam olhando.
///
/// Regerar após mudança visual proposital:
///   flutter test --update-goldens test/features/game/presentation/saga_map_golden_test.dart
Future<void> _loadFonts() async {
  final nunito = FontLoader(AppFonts.display);
  for (final weight in const ['Bold', 'ExtraBold', 'Black']) {
    nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await nunito.load();

  // Sem a MaterialIcons, estrela, cadeado e coroa viram quadrados — e o mapa
  // é feito justamente desses símbolos. Diferente da Nunito, ela vem do pacote
  // do Flutter e o caminho pode mudar entre versões, então a falha não pode
  // derrubar o teste: perde-se nitidez no golden, não a suíte.
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

  testWidgets('mapa da campanha a meio caminho', (tester) async {
    // Um iPhone comum. A campanha a meio caminho é o estado mais informativo:
    // tem pin vencido com estrelas, o pin da vez e os bloqueados, tudo junto.
    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final storage = InMemoryGameStorage(
      campaignProgress: 3,
      highScore: 4820,
      levelRecords: {
        1: const LevelRecord(stars: 3, bestScore: 1200),
        2: const LevelRecord(stars: 2, bestScore: 860),
        3: const LevelRecord(stars: 1, bestScore: 410),
      },
    );

    final container = ProviderContainer(
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const LevelSelectScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LevelSelectScreen),
      matchesGoldenFile('goldens/saga_map.png'),
    );
  });
}
