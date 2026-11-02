import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/features/game/domain/game_settings.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// As Configurações do jogador, lidas do disco ao nascer e gravadas a cada
/// mudança.
class SettingsNotifier extends StateNotifier<GameSettings> {
  SettingsNotifier({GameStorage? storage})
    : _storage = storage ?? const PrefsGameStorage(),
      super(const GameSettings()) {
    ready = _load();
  }

  final GameStorage _storage;

  /// Completa quando a leitura inicial do disco terminou (com ou sem falha).
  late final Future<void> ready;

  /// O jogador mexeu antes de o disco responder: a leitura é descartada, senão
  /// ela desfaria o toque que ele acabou de dar — o mesmo remédio do
  /// `WalletNotifier.refresh`.
  bool _changedLocally = false;

  Future<void> _load() async {
    try {
      final saved = await _storage.readSettings();
      if (!mounted || _changedLocally) return;
      state = saved;
    } catch (error) {
      // Falha de leitura vale como padrão: perder um ajuste é ruim, abrir o
      // jogo mudo ou travado é pior.
      debugPrint('Configurações ilegíveis, usando o padrão: $error');
    }
  }

  void setSound(bool on) => _update(state.copyWith(soundOn: on));

  void setSoundVolume(double volume) =>
      _update(state.copyWith(soundVolume: volume.clamp(0.0, 1.0)));

  void setMusic(bool on) => _update(state.copyWith(musicOn: on));

  void setVibration(bool on) => _update(state.copyWith(vibrationOn: on));

  void setLanguage(AppLanguage language) =>
      _update(state.copyWith(language: language));

  void _update(GameSettings next) {
    if (next == state) return;
    _changedLocally = true;
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _persist(GameSettings value) async {
    try {
      await _storage.writeSettings(value);
    } catch (error) {
      debugPrint('Falha ao gravar as Configurações: $error');
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, GameSettings>(
  (ref) => SettingsNotifier(),
);

/// Espelha as Configurações nos pontos globais de feedback: a vibração e os
/// sons de sistema ([Haptics]) e o [GameAudio].
///
/// Chamado pelo `main` a cada mudança de [settingsProvider]. Fica fora do
/// notifier de propósito: o notifier só guarda e grava, e uma suíte que cria
/// dez notifiers não sai mexendo em estado global a cada um.
void applyFeedbackSettings(GameSettings settings) {
  Haptics.enabled = settings.vibrationOn;
  Haptics.systemSoundsEnabled = settings.soundOn;
  unawaited(
    GameAudio.service.applySettings(
      soundOn: settings.soundOn,
      volume: settings.soundVolume,
      musicOn: settings.musicOn,
    ),
  );
}
