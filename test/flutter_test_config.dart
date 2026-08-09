import 'dart:async';

import 'package:nine_fuse/features/game/presentation/widgets/board_grid_widget.dart';
import 'package:nine_fuse/core/juice_timings.dart';
import 'package:nine_fuse/features/game/presentation/widgets/saga_map.dart';

/// Configuração aplicada a toda a suíte de testes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // A dica espera segundos antes de acender. Em teste isso não acrescenta
  // cobertura e faz todo `pumpAndSettle` avançar o relógio inteiro — a suíte
  // ficava seis vezes mais lenta. Os testes da própria dica usam esta mesma
  // duração encurtada.
  BoardGridWidget.debugHintDelayOverride = const Duration(milliseconds: 120);

  // A jogada é encenada quadro a quadro no app, o que a torna assíncrona e
  // demorada. Quase todo teste verifica regra de jogo, não encenação: para
  // esses, resolver de uma vez mantém a asserção logo após a jogada. Os testes
  // da encenação desligam isto explicitamente.
  JuiceTimings.instantResolution = true;

  // O pin da fase atual pulsa sem parar no app. Uma animação repetitiva faz
  // `pumpAndSettle` nunca terminar, então ela fica desligada na suíte inteira —
  // mesma regra do brilho da dica no tabuleiro.
  debugDisableMapPulse = true;

  await testMain();
}
