import 'package:flutter/foundation.dart';

/// Idioma escolhido nas Configurações.
enum AppLanguage {
  /// Segue o aparelho (`MaterialApp.locale` nulo).
  system,
  pt,
  en;

  /// O código gravado no disco e passado ao `Locale`; nulo para o sistema.
  String? get code => this == system ? null : name;

  /// Lê o código do disco. Valor desconhecido vale como [system]: um idioma
  /// removido numa versão futura não pode travar a abertura do jogo.
  static AppLanguage fromCode(String? code) => switch (code) {
    'pt' => pt,
    'en' => en,
    _ => system,
  };
}

/// As Configurações do jogador. O padrão é tudo ligado e o idioma do
/// aparelho — exatamente o jogo antes de esta tela existir.
@immutable
class GameSettings {
  const GameSettings({
    this.soundOn = true,
    this.soundVolume = 1,
    this.musicOn = true,
    this.vibrationOn = true,
    this.language = AppLanguage.system,
  });

  final bool soundOn;

  /// Volume dos efeitos, de 0 a 1.
  final double soundVolume;
  final bool musicOn;
  final bool vibrationOn;
  final AppLanguage language;

  GameSettings copyWith({
    bool? soundOn,
    double? soundVolume,
    bool? musicOn,
    bool? vibrationOn,
    AppLanguage? language,
  }) => GameSettings(
    soundOn: soundOn ?? this.soundOn,
    soundVolume: soundVolume ?? this.soundVolume,
    musicOn: musicOn ?? this.musicOn,
    vibrationOn: vibrationOn ?? this.vibrationOn,
    language: language ?? this.language,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSettings &&
          soundOn == other.soundOn &&
          soundVolume == other.soundVolume &&
          musicOn == other.musicOn &&
          vibrationOn == other.vibrationOn &&
          language == other.language;

  @override
  int get hashCode =>
      Object.hash(soundOn, soundVolume, musicOn, vibrationOn, language);

  @override
  String toString() =>
      'GameSettings(som: $soundOn ${(soundVolume * 100).round()}%, '
      'música: $musicOn, vibração: $vibrationOn, idioma: ${language.name})';
}
