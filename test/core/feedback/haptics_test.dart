import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/features/game/domain/game_settings.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/settings.dart';

import '../../support/localized.dart';

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    applyFeedbackSettings(const GameSettings());
  });

  Iterable<MethodCall> vibrations() =>
      calls.where((c) => c.method == 'HapticFeedback.vibrate');
  Iterable<MethodCall> systemSounds() =>
      calls.where((c) => c.method == 'SystemSound.play');

  void fireAll() {
    Haptics.selection();
    Haptics.light();
    Haptics.medium();
    Haptics.heavy();
  }

  testWidgets('com a vibração ligada, cada batida chega à plataforma', (
    tester,
  ) async {
    applyFeedbackSettings(const GameSettings());
    fireAll();
    expect(vibrations(), hasLength(4));
  });

  testWidgets('vibração desligada nas Configurações silencia o háptico', (
    tester,
  ) async {
    applyFeedbackSettings(const GameSettings(vibrationOn: false));
    fireAll();
    expect(vibrations(), isEmpty);
  });

  testWidgets('som desligado silencia o clique e o alerta do sistema', (
    tester,
  ) async {
    applyFeedbackSettings(const GameSettings(soundOn: false));
    Haptics.click();
    Haptics.alert();
    expect(systemSounds(), isEmpty);

    applyFeedbackSettings(const GameSettings());
    Haptics.click();
    expect(systemSounds(), hasLength(1));
  });

  testWidgets('o toque num GameButton respeita o interruptor', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      localizedApp(
        home: Center(
          child: GameButton(
            label: 'OK',
            color: Colors.blue,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );

    applyFeedbackSettings(const GameSettings(vibrationOn: false));
    await tester.tap(find.byType(GameButton));
    await tester.pumpAndSettle();

    expect(pressed, 1);
    expect(vibrations(), isEmpty);

    applyFeedbackSettings(const GameSettings());
    await tester.tap(find.byType(GameButton));
    await tester.pumpAndSettle();

    expect(pressed, 2);
    expect(vibrations(), hasLength(1));
  });
}
