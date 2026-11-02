import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';

/// A ponte com o `audioplayers`. Fina e **sem teste**, pela mesma razão do
/// `AdMobRewardedPort`: testá-la mediria o plugin, não o jogo.
class AudioplayersPort implements AudioPort {
  AudioplayersPort({this.sfxVoices = 6});

  final int sfxVoices;

  /// Uma voz por efeito simultâneo, em rodízio: a fusão e o tique da cascata
  /// caem no mesmo quadro, e um player só cortaria um pelo outro.
  ///
  /// `late`: os players nativos só nascem no primeiro som de verdade. Enquanto
  /// `assets/audio/` estiver vazio o serviço nunca chama a porta, e o jogo não
  /// paga nenhum player aberto por um áudio que não existe.
  late final List<AudioPlayer> _sfx = List.generate(
    sfxVoices,
    (_) => _player(ReleaseMode.stop),
  );
  late final AudioPlayer _music = _player(ReleaseMode.loop);
  int _next = 0;
  bool _contextSet = false;
  bool _musicStarted = false;

  static AudioPlayer _player(ReleaseMode mode) {
    final player = AudioPlayer()
      // Os caminhos vêm completos do AssetManifest (`assets/audio/...`); o
      // prefixo padrão do cache somaria um segundo `assets/`.
      ..audioCache = AudioCache(prefix: '');
    unawaited(player.setReleaseMode(mode));
    return player;
  }

  /// Som de jogo, não de mídia.
  ///
  /// No iOS, `ambient`: respeita a chave de silencioso e **mistura** com a
  /// música do próprio jogador em vez de pausá-la. No Android, uso `game` e
  /// foco nenhum, pelo mesmo motivo — o efeito de uma fusão tirar o Spotify
  /// do ar seria o tipo de coisa que faz o jogador desinstalar.
  /// (`AudioContextConfig(respectSilence: true)` não serve: no Android ele
  /// troca o uso para toque de chamada.)
  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> _ensureContext() async {
    if (_contextSet) return;
    _contextSet = true;
    await AudioPlayer.global.setAudioContext(_context);
  }

  @override
  Future<void> playSfx(String assetPath, {required double volume}) async {
    await _ensureContext();
    final player = _sfx[_next];
    _next = (_next + 1) % _sfx.length;
    await player.stop();
    await player.play(
      AssetSource(assetPath),
      volume: volume,
      mode: PlayerMode.lowLatency,
    );
  }

  @override
  Future<void> playMusic(String assetPath, {required double volume}) async {
    await _ensureContext();
    _musicStarted = true;
    await _music.stop();
    await _music.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> stopMusic() async {
    // Nunca tocou: não há player a parar (e criá-lo só para parar seria
    // abrir um player nativo à toa).
    if (!_musicStarted) return;
    await _music.stop();
  }
}

/// Lê do AssetManifest o que foi de fato empacotado em `assets/audio/`.
Future<Set<String>> bundledAudioAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((path) => path.startsWith('assets/audio/'))
      .toSet();
}

/// Extensões que a plataforma atual consegue tocar, em ordem de preferência.
///
/// O iOS não decodifica Vorbis: sem tirar o `.ogg` da lista, um arquivo só em
/// `.ogg` seria escolhido e falharia no plugin a cada efeito.
List<String> platformAudioExtensions() =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? const ['mp3', 'm4a', 'wav']
    : const ['ogg', 'mp3', 'm4a', 'wav'];
