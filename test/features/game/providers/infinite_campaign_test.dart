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
