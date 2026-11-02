import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/game_settings.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Disco que não responde à leitura até o teste liberar.
class _SlowStorage extends InMemoryGameStorage {
  _SlowStorage({super.settings});

  final Completer<void> gate = Completer<void>();

  @override
  Future<GameSettings> readSettings() async {
    await gate.future;
    return super.readSettings();
  }
}

class _BrokenStorage extends InMemoryGameStorage {
  @override
  Future<GameSettings> readSettings() async => throw StateError('sem disco');

  @override
  Future<void> writeSettings(GameSettings value) async =>
      throw StateError('sem disco');
}

void main() {
  group('SettingsNotifier', () {
    test('lê o que foi salvo ao nascer', () async {
      final storage = InMemoryGameStorage(
        settings: const GameSettings(musicOn: false, language: AppLanguage.en),
      );
      final notifier = SettingsNotifier(storage: storage);
      await notifier.ready;

      expect(notifier.state.musicOn, isFalse);
      expect(notifier.state.language, AppLanguage.en);
    });

    test('cada mudança é gravada e relida por um notifier novo', () async {
      final storage = InMemoryGameStorage();
      final first = SettingsNotifier(storage: storage);
      await first.ready;

      first
        ..setSound(false)
        ..setSoundVolume(0.4)
        ..setMusic(false)
        ..setVibration(false)
        ..setLanguage(AppLanguage.pt);
      await pumpEventQueue();

      final reread = SettingsNotifier(storage: storage);
      await reread.ready;
      expect(
        reread.state,
        const GameSettings(
          soundOn: false,
          soundVolume: 0.4,
          musicOn: false,
          vibrationOn: false,
          language: AppLanguage.pt,
        ),
      );
    });

    test('um toque antes de o disco responder não é desfeito', () async {
      final storage = _SlowStorage(
        settings: const GameSettings(vibrationOn: true),
      );
      final notifier = SettingsNotifier(storage: storage);

      notifier.setVibration(false);
      storage.gate.complete();
      await notifier.ready;

      expect(notifier.state.vibrationOn, isFalse);
    });

    test('disco quebrado vale como padrão e não lança', () async {
      final notifier = SettingsNotifier(storage: _BrokenStorage());
      await notifier.ready;
      expect(notifier.state, const GameSettings());

      expect(() => notifier.setMusic(false), returnsNormally);
      expect(notifier.state.musicOn, isFalse);
    });

    test('volume fora da faixa é preso entre 0 e 1', () async {
      final notifier = SettingsNotifier(storage: InMemoryGameStorage());
      notifier.setSoundVolume(3);
      expect(notifier.state.soundVolume, 1);
    });
  });

  group('PrefsGameStorage', () {
    test('ida e volta pelo disco', () async {
      SharedPreferences.setMockInitialValues({});
      const storage = PrefsGameStorage();
      const settings = GameSettings(
        soundOn: false,
        soundVolume: 0.3,
        musicOn: false,
        vibrationOn: false,
        language: AppLanguage.en,
      );

      await storage.writeSettings(settings);
      expect(await storage.readSettings(), settings);

      // Voltar ao idioma do aparelho apaga a chave, não grava "system".
      await storage.writeSettings(
        settings.copyWith(language: AppLanguage.system),
      );
      expect((await storage.readSettings()).language, AppLanguage.system);
    });

    test('disco vazio devolve o padrão', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await const PrefsGameStorage().readSettings(),
        const GameSettings(),
      );
    });

    test('um campo corrompido volta ao padrão sem levar os outros', () async {
      SharedPreferences.setMockInitialValues({
        'settings_vibration_on': false,
        // Tipo errado: um volume gravado como texto.
        'settings_sound_volume': 'alto',
        'settings_language': 'klingon',
      });

      final read = await const PrefsGameStorage().readSettings();
      expect(read.vibrationOn, isFalse);
      expect(read.soundVolume, 1);
      expect(read.language, AppLanguage.system);
    });
  });

  test('AppLanguage.fromCode tolera código desconhecido', () {
    expect(AppLanguage.fromCode('pt'), AppLanguage.pt);
    expect(AppLanguage.fromCode('en'), AppLanguage.en);
    expect(AppLanguage.fromCode(null), AppLanguage.system);
    expect(AppLanguage.fromCode('fr'), AppLanguage.system);
  });
}
