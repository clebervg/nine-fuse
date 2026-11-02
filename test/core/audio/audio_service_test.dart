import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';

/// Porta que só anota o que pediram a ela.
class _RecordingPort implements AudioPort {
  final List<(String, double)> sfx = [];
  final List<String> music = [];
  int stops = 0;
  bool explode = false;

  @override
  Future<void> playSfx(String assetPath, {required double volume}) async {
    if (explode) throw StateError('plugin ausente');
    sfx.add((assetPath, volume));
  }

  @override
  Future<void> playMusic(String assetPath, {required double volume}) async {
    if (explode) throw StateError('plugin ausente');
    music.add(assetPath);
  }

  @override
  Future<void> stopMusic() async => stops++;
}

void main() {
  late _RecordingPort port;

  AudioService serviceWith(
    Set<String> assets, {
    List<String> extensions = const ['mp3', 'ogg'],
  }) {
    port = _RecordingPort();
    return AudioService(
      port: port,
      loadAssets: () async => assets,
      extensions: extensions,
    );
  }

  group('efeitos', () {
    test('evento sem arquivo não toca nem lança', () async {
      final service = serviceWith(const {});

      for (final event in SoundEvent.values) {
        expect(await service.play(event), isFalse);
      }
      expect(port.sfx, isEmpty);
    });

    test('evento com arquivo toca no volume do jogador vezes o peso', () async {
      final service = serviceWith(const {'assets/audio/sfx/spin_tick.mp3'});
      await service.applySettings(soundOn: true, volume: 0.8, musicOn: true);

      expect(await service.play(SoundEvent.spinTick), isTrue);
      expect(port.sfx.single.$1, 'assets/audio/sfx/spin_tick.mp3');
      expect(port.sfx.single.$2, closeTo(0.8 * SoundEvent.spinTick.gain, 1e-9));
    });

    test('com o som desligado nada toca', () async {
      final service = serviceWith(const {'assets/audio/sfx/fusion.mp3'});
      await service.applySettings(soundOn: false, volume: 1, musicOn: true);

      expect(await service.play(SoundEvent.fusion), isFalse);
      expect(port.sfx, isEmpty);
    });

    test('volume zero vale como som desligado', () async {
      final service = serviceWith(const {'assets/audio/sfx/fusion.mp3'});
      await service.applySettings(soundOn: true, volume: 0, musicOn: true);

      expect(await service.play(SoundEvent.fusion), isFalse);
      expect(port.sfx, isEmpty);
    });

    test('só escolhe extensões que a plataforma toca (iOS sem ogg)', () async {
      final service = serviceWith(
        const {'assets/audio/sfx/fusion.ogg'},
        extensions: const ['mp3', 'm4a', 'wav'],
      );

      expect(await service.play(SoundEvent.fusion), isFalse);
      expect(port.sfx, isEmpty);
    });

    test('segue a ordem de preferência das extensões', () async {
      final service = serviceWith(
        const {'assets/audio/sfx/fusion.ogg', 'assets/audio/sfx/fusion.mp3'},
        extensions: const ['ogg', 'mp3'],
      );

      await service.play(SoundEvent.fusion);
      expect(port.sfx.single.$1, 'assets/audio/sfx/fusion.ogg');
    });

    test('falha do plugin não escapa', () async {
      final service = serviceWith(const {'assets/audio/sfx/fusion.mp3'});
      port.explode = true;

      await expectLater(service.play(SoundEvent.fusion), completes);
    });

    test('manifesto ilegível vale como "sem arquivos"', () async {
      port = _RecordingPort();
      final service = AudioService(
        port: port,
        loadAssets: () async => throw StateError('sem manifesto'),
      );

      expect(await service.play(SoundEvent.fusion), isFalse);
      expect(port.sfx, isEmpty);
    });

    test('o mudo padrão nunca toca', () async {
      expect(await AudioService.silent().play(SoundEvent.victory), isFalse);
    });
  });

  group('música', () {
    const menu = 'assets/audio/music/menu.mp3';
    const game = 'assets/audio/music/game.mp3';

    test('com a música desligada a faixa não toca', () async {
      final service = serviceWith(const {menu});
      await service.applySettings(soundOn: true, volume: 1, musicOn: false);

      await service.playMusic(MusicTrack.menu);
      expect(port.music, isEmpty);
    });

    test('religar a música retoma a faixa que a tela pediu', () async {
      final service = serviceWith(const {menu});
      await service.applySettings(soundOn: true, volume: 1, musicOn: false);
      await service.playMusic(MusicTrack.menu);

      await service.applySettings(soundOn: true, volume: 1, musicOn: true);
      expect(port.music, [menu]);

      await service.applySettings(soundOn: true, volume: 1, musicOn: false);
      expect(port.stops, 1);
      expect(service.playingTrack, isNull);
    });

    test('pedir a faixa que já toca não a reinicia', () async {
      final service = serviceWith(const {menu});

      await service.playMusic(MusicTrack.menu);
      await service.playMusic(MusicTrack.menu);
      expect(port.music, [menu]);
    });

    test('desligar só o som não mexe na música', () async {
      final service = serviceWith(const {menu});
      await service.playMusic(MusicTrack.menu);

      await service.applySettings(soundOn: false, volume: 1, musicOn: true);
      expect(port.stops, 0);
      expect(service.playingTrack, MusicTrack.menu);
    });

    test('faixa nova sem arquivo para a anterior', () async {
      final service = serviceWith(const {menu});
      await service.playMusic(MusicTrack.menu);

      await service.playMusic(MusicTrack.game);
      expect(port.music, [menu]);
      expect(port.stops, 1);
      expect(service.playingTrack, isNull);
    });

    test('troca de faixa entre menu e partida', () async {
      final service = serviceWith(const {menu, game});

      await service.playMusic(MusicTrack.menu);
      await service.playMusic(MusicTrack.game);
      expect(port.music, [menu, game]);
    });

    test('app em segundo plano para a música e volta com ela', () async {
      final service = serviceWith(const {menu});
      await service.playMusic(MusicTrack.menu);

      await service.suspend();
      expect(port.stops, 1);

      await service.resume();
      expect(port.music, [menu, menu]);
    });

    test('anúncio de tela cheia cala a música e a devolve ao fechar', () async {
      final service = serviceWith(const {menu});
      await service.playMusic(MusicTrack.menu);

      await service.pauseForAd();
      expect(port.stops, 1);
      expect(service.playingTrack, isNull);

      await service.resumeAfterAd();
      expect(port.music, [menu, menu]);
    });

    test(
      'voltar do segundo plano com o anúncio aberto não religa a música',
      () async {
        // No Android o anúncio é outra activity: o app passa por "oculto →
        // visível" enquanto ele ainda está na tela.
        final service = serviceWith(const {menu});
        await service.playMusic(MusicTrack.menu);

        await service.pauseForAd();
        await service.suspend();
        await service.resume();
        expect(port.music, [menu]);

        await service.resumeAfterAd();
        expect(port.music, [menu, menu]);
      },
    );
  });

  group('GameAudio', () {
    tearDown(() => GameAudio.service = AudioService.silent());

    test('a reserva roda quando o efeito não tocou', () async {
      GameAudio.service = serviceWith(const {});
      var fallbacks = 0;

      GameAudio.play(SoundEvent.select, fallback: () => fallbacks++);
      await pumpEventQueue();

      expect(fallbacks, 1);
    });

    test('a reserva não roda quando o efeito tocou', () async {
      GameAudio.service = serviceWith(const {'assets/audio/sfx/select.mp3'});
      var fallbacks = 0;

      GameAudio.play(SoundEvent.select, fallback: () => fallbacks++);
      await pumpEventQueue();

      expect(fallbacks, 0);
      expect(port.sfx, hasLength(1));
    });
  });

  test('nomes de arquivo são únicos', () {
    final names = SoundEvent.values.map((e) => e.fileName).toSet();
    expect(names, hasLength(SoundEvent.values.length));
  });
}
