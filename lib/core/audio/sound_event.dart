/// Os efeitos sonoros do jogo.
///
/// O nome do arquivo é derivado do enum ([fileName]) e não escrito à mão em
/// cada chamada: a lista de `assets/audio/README.md` e o código não podem
/// divergir, e um nome digitado em dois lugares diverge no primeiro ajuste.
enum SoundEvent {
  /// Peça selecionada para troca (e engajar a mira de um booster).
  select('select', gain: 0.6),

  /// Troca recusada: as peças voltam.
  invalidSwap('invalid_swap', gain: 0.7),

  /// Fusão comum (3+ peças iguais).
  fusion('fusion'),

  /// Cascata 2+: a combinação seguinte da mesma jogada.
  combo('combo'),

  /// Nascimento do 9 (Bloco 9).
  nineBorn('nine_born'),

  /// Super 9 criado ou ativado.
  superNine('super_nine'),

  /// Evento Nova (3+ peças 9).
  nova('nova'),

  /// Cobertura (gelo, vidro, pedra) quebrada.
  obstacleBreak('obstacle_break', gain: 0.8),

  /// Golpe do Martelo de Fusão.
  hammer('hammer'),

  /// Estouro da Bomba.
  bomb('bomb'),

  /// Pincel pintando uma peça.
  brush('brush', gain: 0.8),

  /// Tique da roleta passando por uma divisória.
  spinTick('spin_tick', gain: 0.5),

  /// Roleta parou: prêmio.
  spinPrize('spin_prize'),

  /// Fase vencida.
  victory('victory'),

  /// Fase perdida / corrida encerrada.
  defeat('defeat', gain: 0.8),

  /// Toque em botão (`GameButton`).
  buttonTap('button_tap', gain: 0.5),

  /// Moedas creditadas.
  coins('coins', gain: 0.8);

  const SoundEvent(this.fileName, {this.gain = 1});

  /// Nome do arquivo sem extensão, em `assets/audio/sfx/`.
  final String fileName;

  /// Peso relativo do efeito, multiplicado pelo volume do jogador.
  ///
  /// Sons frequentes (tique, toque, seleção) nascem mais baixos: no mesmo
  /// volume do clímax, o que se ouve cem vezes por partida cansaria antes do
  /// que se ouve uma.
  final double gain;
}

/// As faixas de música de fundo.
enum MusicTrack {
  /// Menu, mapa e loja.
  menu('menu'),

  /// Dentro de uma fase ou corrida do Modo Recorde.
  game('game');

  const MusicTrack(this.fileName);

  /// Nome do arquivo sem extensão, em `assets/audio/music/`.
  final String fileName;
}
