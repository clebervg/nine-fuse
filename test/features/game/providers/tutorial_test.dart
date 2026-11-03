import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/tutorial.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/tutorial.dart';

class _BrokenStorage extends InMemoryGameStorage {
  @override
  Future<Set<String>> readTutorialSeen() async => throw StateError('disco');

  @override
  Future<void> writeTutorialSeen(Set<String> steps) async =>
      throw StateError('disco');
}

class _SlowStorage extends InMemoryGameStorage {
  _SlowStorage({super.tutorialSeen});

  final Completer<void> gate = Completer<void>();

  @override
  Future<Set<String>> readTutorialSeen() async {
    await gate.future;
    return super.readTutorialSeen();
  }
}

void main() {
  test('sem disco o tutorial nasce desligado — o padrão da suíte', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final progress = container.read(tutorialProvider);
    expect(progress.enabled, isFalse);
    for (final step in TutorialStep.values) {
      expect(progress.isPending(step), isFalse);
    }
  });

  test('nada aparece antes de o disco responder', () async {
    final storage = _SlowStorage();
    final notifier = TutorialNotifier(storage: storage);

    expect(notifier.state.isPending(TutorialStep.firstSwap), isFalse);
    storage.gate.complete();
    await notifier.ready;
    expect(notifier.state.isPending(TutorialStep.firstSwap), isTrue);
  });

  test('lê do disco o que já foi visto, e ignora nome desconhecido', () async {
    final storage = InMemoryGameStorage(
      tutorialSeen: {'firstSwap', 'passo_que_nao_existe_mais'},
    );
    final notifier = TutorialNotifier(storage: storage);
    await notifier.ready;

    expect(notifier.state.isPending(TutorialStep.firstSwap), isFalse);
    expect(notifier.state.isPending(TutorialStep.fusion), isTrue);
  });

  test('marcar como visto grava no disco', () async {
    final storage = InMemoryGameStorage();
    final notifier = TutorialNotifier(storage: storage);
    await notifier.ready;

    notifier.markSeen(TutorialStep.movesMedallion);
    await pumpEventQueue();

    expect(notifier.state.isPending(TutorialStep.movesMedallion), isFalse);
    expect(storage.tutorialSeen, {'movesMedallion'});
  });

  test('pular marca todos; rever zera todos', () async {
    final storage = InMemoryGameStorage();
    final notifier = TutorialNotifier(storage: storage);
    await notifier.ready;

    notifier.skipAll();
    await pumpEventQueue();
    expect(storage.tutorialSeen, {
      for (final step in TutorialStep.values) step.name,
    });
    for (final step in TutorialStep.values) {
      expect(notifier.state.isPending(step), isFalse);
    }

    notifier.reset();
    await pumpEventQueue();
    expect(storage.tutorialSeen, isEmpty);
    for (final step in TutorialStep.values) {
      expect(notifier.state.isPending(step), isTrue);
    }
  });

  test('leitura que falha vale como nada visto, sem travar', () async {
    final notifier = TutorialNotifier(storage: _BrokenStorage());
    await notifier.ready;

    expect(notifier.state.loaded, isTrue);
    expect(notifier.state.isPending(TutorialStep.firstSwap), isTrue);

    // Gravar também falha em silêncio: o passo fica visto em memória.
    notifier.markSeen(TutorialStep.firstSwap);
    await pumpEventQueue();
    expect(notifier.state.isPending(TutorialStep.firstSwap), isFalse);
  });

  test('marcado antes de o disco responder continua visto', () async {
    final storage = _SlowStorage(tutorialSeen: {'fusion'});
    final notifier = TutorialNotifier(storage: storage);

    notifier.markSeen(TutorialStep.firstSwap);
    storage.gate.complete();
    await notifier.ready;

    expect(notifier.state.seen, {TutorialStep.firstSwap, TutorialStep.fusion});
    // E o disco recebe a soma, não só o passo marcado cedo.
    await pumpEventQueue();
    expect(storage.tutorialSeen, {'firstSwap', 'fusion'});
  });

  test(
    '"Rever" antes de o disco responder não é desfeito pela leitura',
    () async {
      final storage = _SlowStorage(tutorialSeen: {'fusion', 'firstSwap'});
      final notifier = TutorialNotifier(storage: storage);

      notifier.reset();
      storage.gate.complete();
      await notifier.ready;

      expect(notifier.state.seen, isEmpty);
      await pumpEventQueue();
      expect(storage.tutorialSeen, isEmpty);
    },
  );
}
