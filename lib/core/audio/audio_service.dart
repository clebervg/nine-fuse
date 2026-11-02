import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';

/// A ponte com o plugin de áudio.
///
/// Mesma régua do `RewardedAdPort`: a porta é fina e sem teste, e toda decisão
/// (o que tocar, se o arquivo existe, se o jogador desligou) vive no
/// [AudioService], testável em Dart puro.
abstract interface class AudioPort {
  /// Toca um efeito curto. Efeitos podem se sobrepor.
  Future<void> playSfx(String assetPath, {required double volume});

  /// Troca a música de fundo pela faixa em [assetPath], em laço.
  Future<void> playMusic(String assetPath, {required double volume});

  Future<void> stopMusic();
}

/// Porta que não fala com plataforma nenhuma: o padrão de teste e de quem não
/// tem plugin (desktop, web).
class SilentAudioPort implements AudioPort {
  const SilentAudioPort();

  @override
  Future<void> playSfx(String assetPath, {required double volume}) async {}

  @override
  Future<void> playMusic(String assetPath, {required double volume}) async {}

  @override
  Future<void> stopMusic() async {}
}

/// Volume da música relativo ao dos efeitos: ela é pano de fundo, e no mesmo
/// nível encobriria a fusão — o som que diz ao jogador que a jogada valeu.
const double kMusicVolume = 0.45;

/// Decide o que soa: efeito por evento, música por tela, tudo sob as
/// Configurações do jogador.
///
/// **Arquivo que falta é silêncio, não erro.** O jogo foi publicado sem áudio e
/// os arquivos chegam aos poucos: o serviço consulta a lista de assets
/// empacotados ([loadAssets], o AssetManifest em produção) e simplesmente não
/// toca o que não existe — sem exceção e sem log a cada jogada.
class AudioService {
  AudioService({
    required this.port,
    required this.loadAssets,
    this.extensions = const ['mp3', 'ogg', 'm4a', 'wav'],
  });

  /// O padrão: nada toca. É o que mantém a suíte sem canal de plataforma.
  AudioService.silent()
    : this(port: const SilentAudioPort(), loadAssets: () async => const {});

  final AudioPort port;

  /// Os assets empacotados (o AssetManifest, em produção). Lido uma vez, no
  /// primeiro som pedido.
  final Future<Set<String>> Function() loadAssets;

  /// Extensões aceitas, em ordem de preferência. Por plataforma porque o iOS
  /// não toca `.ogg` (o AVPlayer não tem Vorbis): lá a lista vem sem ele, e
  /// um `fusion.ogg` sozinho vira silêncio em vez de erro.
  final List<String> extensions;

  Future<Set<String>>? _assets;

  bool _soundOn = true;
  double _volume = 1;
  bool _musicOn = true;

  /// App em segundo plano: a música para, mesmo ligada.
  bool _suspended = false;

  /// A faixa que a tela atual pediu — lembrada para voltar quando a música é
  /// religada ou o app volta ao primeiro plano.
  MusicTrack? _wantedTrack;
  MusicTrack? _playingTrack;

  /// Uma falha do plugin é avisada uma vez: um `debugPrint` por efeito
  /// inundaria o console a cada fusão.
  bool _warned = false;

  bool get soundOn => _soundOn;
  double get volume => _volume;
  bool get musicOn => _musicOn;

  @visibleForTesting
  MusicTrack? get playingTrack => _playingTrack;

  /// Aplica as Configurações. Chamado pelo `main` a cada mudança.
  Future<void> applySettings({
    required bool soundOn,
    required double volume,
    required bool musicOn,
  }) {
    _soundOn = soundOn;
    _volume = volume.clamp(0.0, 1.0);
    final musicChanged = musicOn != _musicOn;
    _musicOn = musicOn;
    return musicChanged ? _syncMusic() : Future<void>.value();
  }

  /// Toca o efeito de [event], se o som estiver ligado e o arquivo existir.
  ///
  /// Devolve se tocou — é o que permite a quem chama cair no clique do
  /// sistema enquanto o arquivo próprio não chega (ver [GameAudio.play]).
  Future<bool> play(SoundEvent event) async {
    if (!_soundOn || _volume <= 0) return false;
    final path = await _resolve('assets/audio/sfx/${event.fileName}');
    if (path == null || !_soundOn) return false;
    await _guard(() => port.playSfx(path, volume: _volume * event.gain));
    return true;
  }

  /// Pede a faixa de fundo de [track]. Pedir a que já toca não a reinicia:
  /// voltar do mapa ao menu não pode começar a música do zero.
  Future<void> playMusic(MusicTrack track) {
    _wantedTrack = track;
    return _syncMusic();
  }

  Future<void> stopMusic() {
    _wantedTrack = null;
    return _syncMusic();
  }

  /// App saiu da tela (ou voltou).
  Future<void> suspend() {
    _suspended = true;
    return _syncMusic();
  }

  Future<void> resume() {
    _suspended = false;
    return _syncMusic();
  }

  Future<void> _syncMusic() async {
    final desired = _musicOn && !_suspended ? _wantedTrack : null;
    if (desired == _playingTrack) return;

    if (desired == null) {
      _playingTrack = null;
      await _guard(port.stopMusic);
      return;
    }

    // Marcado antes do `await`: dois pedidos seguidos da mesma faixa não
    // podem disparar dois `playMusic`.
    final previous = _playingTrack;
    _playingTrack = desired;
    final path = await _resolve('assets/audio/music/${desired.fileName}');
    // O pedido mudou enquanto a lista de assets carregava: o mais novo manda.
    if (_playingTrack != desired) return;
    if (path == null) {
      // Sem arquivo para a faixa nova: a anterior não pode continuar tocando
      // como se fosse desta tela.
      _playingTrack = null;
      if (previous != null) await _guard(port.stopMusic);
      return;
    }
    await _guard(() => port.playMusic(path, volume: kMusicVolume));
  }

  /// O caminho do primeiro arquivo existente para [base], ou nulo.
  Future<String?> _resolve(String base) async {
    final assets = await (_assets ??= _safeLoad());
    for (final ext in extensions) {
      final candidate = '$base.$ext';
      if (assets.contains(candidate)) return candidate;
    }
    return null;
  }

  Future<Set<String>> _safeLoad() async {
    try {
      return await loadAssets();
    } catch (error) {
      // Sem manifesto, sem áudio: o jogo segue mudo, que é o estado em que
      // ele já foi publicado.
      _warn('lista de assets ilegível: $error');
      return const {};
    }
  }

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      _warn('$error');
    }
  }

  void _warn(String message) {
    if (_warned) return;
    _warned = true;
    debugPrint('Áudio indisponível: $message');
  }
}

/// Acesso global ao [AudioService], no mesmo espírito dos ganchos táteis
/// estáticos: os boosters são mixins sem `ref`, e passar um provider até
/// eles mudaria a assinatura de dois notifiers por um som.
///
/// O padrão é o serviço mudo — em teste nada toca e nenhum canal é aberto.
/// Quem liga o plugin de verdade é o `main`, como faz com o AdMob.
abstract final class GameAudio {
  static AudioService service = AudioService.silent();

  /// Dispara e esquece: quem toca um efeito nunca espera por ele.
  ///
  /// [fallback] roda quando o efeito **não** tocou (arquivo ausente, som
  /// desligado). É onde ficam os sons de sistema que o jogo já usava: sem
  /// isso, o dia em que `select.mp3` chegar o jogador ouviria o clique do
  /// sistema e o efeito novo empilhados.
  static void play(SoundEvent event, {void Function()? fallback}) {
    final played = service.play(event);
    if (fallback == null) {
      unawaited(played);
      return;
    }
    unawaited(played.then((ok) => ok ? null : fallback()));
  }

  static void music(MusicTrack track) => unawaited(service.playMusic(track));
}
