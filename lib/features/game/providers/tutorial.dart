import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/tutorial.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// O que o tutorial sabe do jogador: se está ligado, se o disco já respondeu
/// e quais passos ele já viu.
@immutable
class TutorialProgress {
  const TutorialProgress({
    required this.enabled,
    required this.loaded,
    this.seen = const {},
  });

  /// Tutorial desligado: nenhum passo pendente, nada a gravar.
  static const TutorialProgress off = TutorialProgress(
    enabled: false,
    loaded: true,
  );

  final bool enabled;

  /// A leitura do disco terminou (com ou sem falha). Antes disso nenhum passo
  /// aparece: mostrar e, um quadro depois, descobrir que já tinha sido visto
  /// faria o balão piscar na cara de quem já sabe jogar.
  final bool loaded;

  final Set<TutorialStep> seen;

  /// O passo ainda está por mostrar?
  bool isPending(TutorialStep step) =>
      enabled && loaded && !seen.contains(step);
}

/// Guarda e grava os passos vistos do tutorial.
///
/// Sem [storage] o tutorial nasce desligado — é o padrão do provider, e o que
/// mantém a suíte antiga de tela (que monta fases 1-3 à vontade) sem balão
/// nenhum no caminho. Quem liga é o `main`, com o disco de verdade: o mesmo
/// desenho do anúncio e do áudio.
class TutorialNotifier extends StateNotifier<TutorialProgress> {
  TutorialNotifier({GameStorage? storage})
    : _storage = storage,
      super(
        storage == null
            ? TutorialProgress.off
            : const TutorialProgress(enabled: true, loaded: false),
      ) {
    ready = storage == null ? Future.value() : _load();
  }

  final GameStorage? _storage;

  /// Completa quando a leitura inicial terminou.
  late final Future<void> ready;

  /// "Rever tutorial" chegou antes do disco: a leitura velha não pode
  /// devolver os passos que o jogador acabou de pedir para rever.
  bool _resetLocally = false;

  /// Algo mudou antes de a leitura terminar.
  bool _changedBeforeLoad = false;

  Future<void> _load() async {
    var saved = <TutorialStep>{};
    try {
      final names = await _storage!.readTutorialSeen();
      saved = {
        for (final step in TutorialStep.values)
          if (names.contains(step.name)) step,
      };
    } catch (error) {
      // Leitura que falha vale como "nada visto": rever um balão é um
      // incômodo; travar o jogo esperando o disco seria pior.
      debugPrint('Tutorial ilegível, considerando nada visto: $error');
    }
    if (!mounted) return;
    // União, e não substituição: um passo marcado enquanto o disco não
    // respondia continua visto.
    state = TutorialProgress(
      enabled: true,
      loaded: true,
      seen: _resetLocally ? state.seen : {...saved, ...state.seen},
    );
    // O que mudou enquanto o disco não respondia só é gravado agora, já
    // somado ao que estava lá: gravar antes apagaria os passos do disco.
    if (_changedBeforeLoad) unawaited(_persist(state.seen));
  }

  /// Marca [step] como visto. Chamado no instante em que o balão sobe: um
  /// passo nunca aparece duas vezes, nem se o app fechar com ele na tela.
  void markSeen(TutorialStep step) {
    if (!state.enabled || state.seen.contains(step)) return;
    _save({...state.seen, step});
  }

  /// "Pular tutorial": tudo visto de uma vez.
  void skipAll() {
    if (!state.enabled) return;
    _save(TutorialStep.values.toSet());
  }

  /// "Rever tutorial", das Configurações: nada visto.
  void reset() {
    if (!state.enabled) return;
    _resetLocally = true;
    _save(const {});
  }

  void _save(Set<TutorialStep> seen) {
    state = TutorialProgress(enabled: true, loaded: state.loaded, seen: seen);
    if (state.loaded) {
      unawaited(_persist(seen));
    } else {
      _changedBeforeLoad = true;
    }
  }

  Future<void> _persist(Set<TutorialStep> seen) async {
    try {
      await _storage!.writeTutorialSeen({for (final s in seen) s.name});
    } catch (error) {
      debugPrint('Falha ao gravar o tutorial: $error');
    }
  }
}

/// De onde o tutorial lê e grava. Nulo = tutorial desligado (padrão da
/// suíte); o `main` aponta para o disco.
final tutorialStorageProvider = Provider<GameStorage?>((ref) => null);

final tutorialProvider =
    StateNotifierProvider<TutorialNotifier, TutorialProgress>(
      (ref) => TutorialNotifier(storage: ref.watch(tutorialStorageProvider)),
    );
