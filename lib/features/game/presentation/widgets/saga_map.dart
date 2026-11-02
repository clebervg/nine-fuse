import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/widgets/chapter_chest.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do pin de uma fase.
///
/// Mantém o nome antigo (`level_N`) de propósito: é a porta pela qual os testes
/// de acesso a fase tocam numa fase específica, e trocar o nome faria uma
/// mudança de layout parecer mudança de regra.
Key levelCardKey(int number) => Key('level_$number');

/// Chave do círculo desenhado de um pin, sem a aura em volta.
///
/// Serve para medir tamanho e ler a borda do pin em si: é o que distingue a
/// fase da vez das demais, e é o que o teste precisa alcançar.
Key pinCoreKey(int number) => Key('pin_core_$number');

/// Chave da etiqueta "VOCÊ ESTÁ AQUI" ao lado da fase da vez.
const Key youAreHereKey = Key('map_you_are_here');

/// Chave do tile 9 que marca a fase da vez, acima dela.
const Key currentMarkerKey = Key('map_current_marker');

/// Chave do marcador "Fases 1–N concluídas", no pé de uma trilha que não
/// começa na fase 1.
const Key collapsedLevelsKey = Key('map_collapsed_levels');

/// Distância fixa entre a borda de baixo do círculo e o número de uma fase
/// bloqueada.
///
/// Negativa de propósito: o rótulo fica **fora** do círculo, ancorado a ele e
/// não à caixa do nó, para nunca cavalgar a curva do caminho — que passa
/// exatamente pelo centro do pin.
const double kPinBadgeOffset = -18;

/// Quanto a fileira de estrelas de uma fase vencida encosta no topo do disco.
///
/// As estrelas ficam **acima** do disco, como uma coroa (é o desenho do
/// "Observatório Real"): abaixo, elas disputariam lugar com o número da fase
/// bloqueada e com a trilha que desce para a fase anterior.
const double kPinStarsOverlap = 2;

/// Estado visual de um pin.
enum PinState {
  /// Já vencida: disco de ouro com as estrelas conquistadas.
  cleared,

  /// A próxima a jogar: gema roxa, o tile 9 por cima. É o único pin que pulsa.
  current,

  /// Ainda travada: disco azul-noite com cadeado.
  locked,
}

/// Geometria do caminho sinuoso.
///
/// Fica separada do widget porque **três** coisas precisam concordar sobre onde
/// cada pin está: o traçado do caminho, a posição dos pins e a rolagem que
/// centraliza a fase atual. Duplicar a fórmula faria o caminho descolar dos
/// pins ao primeiro ajuste de espaçamento.
class SagaGeometry {
  const SagaGeometry({required this.width, required this.levelCount});

  final double width;
  final int levelCount;

  /// Distância vertical entre dois pins.
  ///
  /// Fixa, e não proporcional à altura: o mapa rola, então o que importa é o
  /// espaço entre vizinhos, não caber tudo na tela.
  static const double step = 120;

  /// Folga acima do primeiro pin e abaixo do último.
  static const double margin = 90;

  /// Diâmetro do disco de uma fase vencida. O da fase atual é desenhado
  /// maior, mas ocupa o mesmo lugar — senão a rolagem calculada não bateria
  /// com o que se vê.
  static const double pinSize = 62;

  /// Quanto a gema da fase atual é maior que os discos vencidos (88 contra 62
  /// no design).
  ///
  /// É o maior salto de tamanho do mapa, e cabe porque os vizinhos estão
  /// deslocados na horizontal pela senoide: a gema cresce para o vão entre
  /// eles, não para cima deles.
  static const double currentPinScale = 1.42;

  /// Quanto o disco bloqueado é menor que o vencido (58 contra 62): o que
  /// ainda não é do jogador pesa menos na tela.
  static const double lockedPinScale = 0.94;

  /// Quanto o caminho se afasta do centro, como fração da largura útil.
  ///
  /// Limitado porque num tablet a amplitude proporcional jogaria os pins nas
  /// bordas da tela, e o caminho viraria um zigue-zague de canto a canto em vez
  /// de uma trilha.
  static const double maxAmplitude = 96;

  double get amplitude => math.min(maxAmplitude, width * 0.28);

  /// Nós projetados acima da última fase jogável.
  ///
  /// O mapa nunca termina em corte seco: a trilha segue em pontilhado por mais
  /// alguns nós bloqueados, para dizer que o universo do jogo continua. É
  /// geometria e não enfeite — a altura do mapa conta com eles, senão os nós
  /// nasceriam fora da área rolável.
  static const int futureNodes = 3;

  /// Índice do último nó desenhado, contando os projetados.
  int get lastIndex => levelCount - 1 + futureNodes;

  /// Altura total do mapa.
  double get height => margin * 2 + step * math.max(0, lastIndex);

  /// Centro do pin da fase de índice [index] (0 é a primeira).
  ///
  /// O caminho sobe: a fase 1 fica **embaixo**, como numa trilha que se escala.
  /// A ondulação é uma senoide, não um zigue-zague de segmentos retos — a
  /// curva contínua é o que faz o traçado parecer caminho e não gráfico.
  Offset centerOf(int index) {
    final y = height - margin - step * index;
    final x = width / 2 + amplitude * math.sin(index * math.pi / 2);
    return Offset(x, y);
  }
}

/// O mapa da campanha: um caminho sinuoso com um pin por fase.
class SagaMapWidget extends StatelessWidget {
  const SagaMapWidget({
    super.key,
    required this.levels,
    required this.progress,
    required this.starsOf,
    required this.onTapLevel,
    this.revealTo,
    this.revealProgress = 1,
    this.claimedChests = const <int>{},
    this.onTapChest,
  });

  final List<GameLevel> levels;

  /// Número da última fase concluída.
  final int progress;

  /// Estrelas de uma fase, de 0 a 3.
  final int Function(int levelNumber) starsOf;

  final void Function(GameLevel level) onTapLevel;

  /// Índice até onde o caminho deve ser preenchido pela animação de liberação.
  /// Nulo desenha o caminho já no estado final.
  final int? revealTo;

  /// Andamento do preenchimento do último trecho, de 0 a 1.
  final double revealProgress;

  /// Capítulos cujo baú já foi pago (`Wallet.claimedChests`).
  final Set<int> claimedChests;

  /// Toque no baú de um capítulo. Nulo não desenha baú nenhum — o mapa
  /// continua usável sem carteira (golden antigo, testes de trilha pura).
  final void Function(CampaignChapter chapter, ChestState state)? onTapChest;

  /// A fase que o jogador deve jogar agora: a primeira ainda não vencida.
  int get currentLevelNumber {
    for (final level in levels) {
      if (level.number > progress) return level.number;
    }
    // Campanha inteira concluída: o destaque fica na última.
    return levels.last.number;
  }

  PinState _stateOf(GameLevel level) {
    if (level.number <= progress) return PinState.cleared;
    if (level.number == currentLevelNumber) return PinState.current;
    return PinState.locked;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = SagaGeometry(
          width: constraints.maxWidth,
          levelCount: levels.length,
        );

        return SizedBox(
          height: geometry.height,
          child: Stack(
            // As estrelas ficam ancoradas abaixo do círculo, e a aura do pin da
            // vez passa da caixa dele: nenhum dos dois pode ser recortado.
            clipBehavior: Clip.none,
            children: [
              // O caminho vem primeiro: é o fundo sobre o qual os pins pousam.
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    geometry: geometry,
                    clearedUpTo: _clearedIndex,
                    revealTo: revealTo,
                    revealProgress: revealProgress,
                  ),
                ),
              ),
              for (int i = 0; i < levels.length; i++)
                _positionedPin(
                  geometry,
                  i,
                  child: _pinFor(
                    levels[i],
                    // A etiqueta vai para o lado com mais espaço: à direita de
                    // um pin já encostado na borda direita ela sairia da tela.
                    tagOnLeft: geometry.centerOf(i).dx > geometry.width / 2 + 1,
                  ),
                ),
              // Nós projetados: nem fase nem placeholder tocável, só a promessa
              // de que a trilha continua.
              for (int i = levels.length; i <= geometry.lastIndex; i++)
                _positionedPin(geometry, i, child: const _FuturePin()),
              if (onTapChest != null) ..._chests(geometry),
              // A janela deslizante não monta as fases antigas: o pé da
              // trilha diz o que ficou para trás, em vez de terminar num
              // corte seco que pareceria o começo do jogo.
              if (levels.isNotEmpty && levels.first.number > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  top: geometry.centerOf(0).dy + SagaGeometry.pinSize / 2 + 12,
                  child: Center(
                    child: _CollapsedLevels(upTo: levels.first.number - 1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Índice do último pin já vencido, ou -1 se nenhum.
  int get _clearedIndex {
    var last = -1;
    for (int i = 0; i < levels.length; i++) {
      if (levels[i].number <= progress) last = i;
    }
    return last;
  }

  /// Um baú no fim de cada capítulo pagável cuja última fase já está na
  /// trilha.
  ///
  /// O baú não ganha nó próprio na geometria: entrar na sequência de pins
  /// empurraria todas as fases seguintes e desalinharia a rolagem que
  /// centraliza a fase da vez. Ele pousa **ao lado** da trilha, a meio
  /// caminho entre a última fase do capítulo e a primeira do seguinte, do
  /// lado oposto ao da curva — longe da etiqueta "VOCÊ ESTÁ AQUI", do tile 9
  /// e da coroa de estrelas, que vivem colados nos pins.
  List<Widget> _chests(SagaGeometry geometry) {
    final chests = <Widget>[];
    if (levels.isEmpty) return chests;
    // Começa no capítulo da primeira fase **montada**: a trilha é uma janela
    // deslizante, e partir do capítulo 1 pararia no primeiro baú fora dela.
    var chapter = chapterOf(levels.first.number);
    while (chapterHasChest(chapter)) {
      final index = levels.indexWhere((l) => l.number == chapter.lastLevel);
      // Fim do capítulo depois da janela: daqui em diante nada mais cabe.
      if (index < 0) break;

      final a = geometry.centerOf(index);
      final b = geometry.centerOf(index + 1);
      final midX = (a.dx + b.dx) / 2;
      final side = midX > geometry.width / 2 ? -1 : 1;
      final centre = Offset(
        geometry.width / 2 + side * geometry.amplitude,
        (a.dy + b.dy) / 2,
      );
      final state = chestStateFor(
        chapter,
        progress: progress,
        claimedChests: claimedChests,
      );
      final current = chapter;
      const box = ChapterChestNode.size + 16;
      chests.add(
        Positioned(
          left: centre.dx - box / 2,
          top: centre.dy - box / 2,
          width: box,
          height: box,
          child: Center(
            child: ChapterChestNode(
              chapter: current.number,
              state: state,
              onTap: () => onTapChest!(current, state),
            ),
          ),
        ),
      );
      chapter = chapterOf(chapter.lastLevel + 1);
    }
    return chests;
  }

  Widget _pinFor(GameLevel level, {required bool tagOnLeft}) => _LevelPin(
    level: level,
    state: _stateOf(level),
    stars: starsOf(level.number),
    tagOnLeft: tagOnLeft,
    onTap: () => onTapLevel(level),
  );

  /// Assenta um nó **centrado no ponto da trilha**.
  ///
  /// A caixa é quadrada e um pouco maior que o maior pin (a gema da vez), e o
  /// conteúdo vai num `Center`: assim o pin recebe restrição frouxa e se mede
  /// sozinho, o que é o que deixa as estrelas ancoradas em relação ao
  /// **círculo** e não em relação a uma caixa arbitrária.
  Widget _positionedPin(
    SagaGeometry geometry,
    int index, {
    required Widget child,
  }) {
    final centre = geometry.centerOf(index);
    const box = SagaGeometry.pinSize * SagaGeometry.currentPinScale + 16;

    return Positioned(
      left: centre.dx - box / 2,
      top: centre.dy - box / 2,
      width: box,
      height: box,
      child: Center(child: child),
    );
  }
}

/// Desenha a trilha que liga os pins.
///
/// Duas camadas, cada uma em pontilhado sobre um leito: o trecho vencido em
/// pontos de ouro sobre leito bronze, o que falta em pontos apagados sobre
/// leito de noite. É o que dá ao mapa a leitura de "isto já é meu, aquilo
/// ainda não" sem precisar de legenda — e o pontilhado, em vez de traço
/// cheio, é o que faz a linha ler como trilha de constelação e não gráfico.
class _PathPainter extends CustomPainter {
  const _PathPainter({
    required this.geometry,
    required this.clearedUpTo,
    required this.revealTo,
    required this.revealProgress,
  });

  final SagaGeometry geometry;
  final int clearedUpTo;
  final int? revealTo;
  final double revealProgress;

  /// Distância entre dois pontos do pontilhado.
  static const double _dotGap = 13;

  /// Traçado entre os nós de índice [from] e [to], em curvas suaves.
  Path _pathBetween(int from, int to) {
    final path = Path();
    if (to <= from) return path;

    path.moveTo(geometry.centerOf(from).dx, geometry.centerOf(from).dy);

    for (int i = from + 1; i <= to; i++) {
      final a = geometry.centerOf(i - 1);
      final b = geometry.centerOf(i);
      // Controles na horizontal de cada ponta: a curva sai e chega na vertical,
      // que é o que faz os trechos se emendarem sem bico no pin.
      path.cubicTo(
        a.dx,
        a.dy - SagaGeometry.step * 0.5,
        b.dx,
        b.dy + SagaGeometry.step * 0.5,
        b.dx,
        b.dy,
      );
    }

    return path;
  }

  /// Leito largo e escuro sob os pontos: sem ele o pontilhado se perde entre
  /// as estrelas do céu.
  void _drawBed(Canvas canvas, Path path, Color color) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = color,
  );

  /// Pontos redondos ao longo de [path], numa chamada de desenho só — a
  /// trilha de uma campanha adiantada tem milhares deles.
  void _drawDots(Canvas canvas, Path path, Color color, double size) {
    final points = <Offset>[];
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += _dotGap) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) points.add(tangent.position);
      }
    }
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..strokeWidth = size
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.levelCount < 1) return;

    // O caminho projetado vem primeiro: ele passa por trás de tudo e é o que
    // impede o mapa de terminar em corte seco na última fase.
    if (SagaGeometry.futureNodes > 0) {
      final future = _pathBetween(geometry.levelCount - 1, geometry.lastIndex);
      _drawBed(canvas, future, const Color(0x8005081C));
      _drawDots(canvas, future, const Color(0x803A4380), 4);
    }

    if (geometry.levelCount < 2) return;

    final path = _pathBetween(0, geometry.levelCount - 1);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    // Quanto do caminho está conquistado, em fração do traçado inteiro. Cada
    // trecho vale o mesmo, então a fração é contagem de trechos.
    final segments = geometry.levelCount - 1;
    var doneSegments = clearedUpTo.clamp(0, segments).toDouble();

    // Animação de liberação: o último trecho cresce em vez de aparecer pronto.
    if (revealTo != null && revealTo! > 0) {
      final target = revealTo!.clamp(0, segments).toDouble();
      doneSegments = math.min(doneSegments, target - 1 + revealProgress);
    }

    final doneLength = metric.length * math.max(0, doneSegments) / segments;
    final pending = metric.extractPath(doneLength, metric.length);
    _drawBed(canvas, pending, const Color(0xFF05081C));
    _drawDots(canvas, pending, const Color(0xFF3A4380), 4);

    if (doneLength <= 0) return;

    final done = metric.extractPath(0, doneLength);
    _drawBed(canvas, done, NfColors.bronze);
    _drawDots(canvas, done, NfColors.gold, 5);
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.clearedUpTo != clearedUpTo ||
      old.revealTo != revealTo ||
      old.revealProgress != revealProgress ||
      old.geometry.width != geometry.width ||
      old.geometry.levelCount != geometry.levelCount;
}

/// Um pin de fase: o número da fase, o estado e o que vem pendurado nele
/// (estrelas, marcador da vez, número da bloqueada).
class _LevelPin extends StatelessWidget {
  const _LevelPin({
    required this.level,
    required this.state,
    required this.stars,
    required this.tagOnLeft,
    required this.onTap,
  });

  final GameLevel level;
  final PinState state;
  final int stars;

  /// De que lado do pin da vez vai a etiqueta "VOCÊ ESTÁ AQUI".
  final bool tagOnLeft;
  final VoidCallback onTap;

  bool get _isLocked => state == PinState.locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = switch (state) {
      PinState.cleared => SagaGeometry.pinSize,
      PinState.current => SagaGeometry.pinSize * SagaGeometry.currentPinScale,
      PinState.locked => SagaGeometry.pinSize * SagaGeometry.lockedPinScale,
    };

    // Tudo o que pende do pin é `Positioned`, e não irmão num `Column`: fora
    // do cálculo de tamanho, cada peça fica ancorada a uma distância fixa da
    // borda do círculo, sem depender de quanto o pin cresce nem esbarrar na
    // curva do caminho, que passa exatamente pelo centro dele.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Semantics(
          button: !_isLocked,
          enabled: !_isLocked,
          // Sem rótulo, um leitor de tela anuncia só o número solto do pin.
          label: _semanticLabel(l10n),
          child: GestureDetector(
            key: levelCardKey(level.number),
            onTap: _isLocked ? null : _handleTap,
            behavior: HitTestBehavior.opaque,
            child: switch (state) {
              PinState.current => _CurrentPin(level: level, size: size),
              PinState.cleared => _ClearedPin(level: level, size: size),
              PinState.locked => _LockedPin(level: level, size: size),
            },
          ),
        ),
        if (state == PinState.cleared)
          Positioned(
            bottom: size - kPinStarsOverlap,
            child: _StarRow(stars: stars),
          )
        else if (state == PinState.current) ...[
          // O tile 9 é o "você" do mapa: a peça-símbolo do jogo pousada
          // sobre a fase que o jogador vai jogar.
          Positioned(
            bottom: size + 8,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Image.asset(
                  'assets/sprites/tiles/tile_9.png',
                  key: currentMarkerKey,
                  width: 56,
                  height: 56,
                  // Sem a arte, o marcador simplesmente não aparece: a gema
                  // e a etiqueta já dizem onde o jogador está.
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned(
            left: tagOnLeft ? null : size + 8,
            right: tagOnLeft ? size + 8 : null,
            child: _YouAreHereTag(label: l10n.mapYouAreHere),
          ),
        ] else
          Positioned(
            bottom: kPinBadgeOffset,
            child: ExcludeSemantics(
              child: Text(
                '${level.number}',
                style: const TextStyle(
                  fontFamily: AppFonts.number,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1,
                  color: _lockedInk,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _semanticLabel(AppLocalizations l10n) => switch (state) {
    PinState.cleared => l10n.semanticsLevelCleared(
      level.number,
      stars,
      kStarsPerLevel,
      l10n.objectiveLabel(level.objective),
    ),
    PinState.current => l10n.semanticsLevelCurrent(
      level.number,
      l10n.objectiveLabel(level.objective),
    ),
    PinState.locked => l10n.semanticsLevelLocked(level.number),
  };

  void _handleTap() {
    // O toque de botão do jogo quando o arquivo existir; até lá, o clique
    // curto do próprio sistema, que já respeitava o ajuste de som do aparelho.
    GameAudio.play(SoundEvent.buttonTap, fallback: Haptics.click);
    Haptics.selection();
    onTap();
  }
}

/// Tinta do que ainda está trancado: cadeado, número e aro apagados.
const Color _lockedInk = Color(0xFF7D86C2);

/// Número de fase que encolhe em vez de vazar do disco (fase 1000+).
class _PinNumber extends StatelessWidget {
  const _PinNumber({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}

/// Fase vencida: disco de ouro com o número em marrom.
///
/// Não anima: só a fase atual chama a atenção, senão o mapa inteiro pisca e
/// nada se destaca.
class _ClearedPin extends StatelessWidget {
  const _ClearedPin({required this.level, required this.size});

  final GameLevel level;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    // Chave própria: é o que o teste mede, sem confundir com a coroa de
    // estrelas nem com a caixa do nó.
    key: pinCoreKey(level.number),
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment(-0.35, -1),
        end: Alignment(0.35, 1),
        colors: [NfColors.goldLight, Color(0xFFFFD033), Color(0xFFE39A00)],
        stops: [0, 0.4, 1],
      ),
      border: Border.all(color: const Color(0xFFFFF6C8), width: 3),
      boxShadow: const [
        // Blur zero: é a espessura do disco, não uma sombra.
        BoxShadow(color: NfColors.goldShadow, offset: Offset(0, 6)),
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Center(
      child: _PinNumber(
        child: Text(
          '${level.number}',
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontFamily: AppFonts.title,
            color: NfColors.goldText,
            fontSize: 24,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

/// Fase bloqueada: disco azul-noite com cadeado. O número vai abaixo, fora do
/// disco (ver [_LevelPin]).
class _LockedPin extends StatelessWidget {
  const _LockedPin({required this.level, required this.size});

  final GameLevel level;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    key: pinCoreKey(level.number),
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1F2A66), Color(0xFF0E1640)],
      ),
      border: Border.all(color: const Color(0xFF3A4380), width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 6)),
      ],
    ),
    child: const Icon(Icons.lock_outline, color: _lockedInk, size: 24),
  );
}

/// Nó projetado, além da última fase existente.
///
/// Menor, translúcido e sem número: não promete uma fase específica, só que a
/// trilha continua. Não é tocável e não tem semântica de botão — anunciá-lo a
/// um leitor de tela como fase daria a entender que existe algo para abrir.
/// "Fases 1–N concluídas": fecha o pé de uma trilha que não começa na 1.
class _CollapsedLevels extends StatelessWidget {
  const _CollapsedLevels({required this.upTo});

  final int upTo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: collapsedLevelsKey,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: NfColors.night1.withValues(alpha: 0.85),
        border: Border.all(
          color: NfColors.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: NfColors.gold,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context).mapLevelsCleared(upTo),
            style: const TextStyle(
              fontFamily: AppFonts.number,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1,
              color: NfColors.goldPale,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuturePin extends StatelessWidget {
  const _FuturePin();

  @override
  Widget build(BuildContext context) {
    const size = SagaGeometry.pinSize * 0.72;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0E1640).withValues(alpha: 0.6),
          border: Border.all(
            color: const Color(0xFF3A4380).withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.lock_outline,
            size: 18,
            color: _lockedInk.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// Pin da fase atual: gema roxa em aro de ouro, com aura pulsando.
///
/// É o único elemento animado do mapa, e por isso o olho vai direto nele — que
/// é exatamente a função dele.
class _CurrentPin extends StatefulWidget {
  const _CurrentPin({required this.level, required this.size});

  final GameLevel level;
  final double size;

  @override
  State<_CurrentPin> createState() => _CurrentPinState();
}

class _CurrentPinState extends State<_CurrentPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Criado aqui, e não como `late final`: um campo preguiçoso pode acabar
    // sendo inicializado pelo próprio `dispose()`.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // O pulso **não** roda em teste: uma animação repetitiva faz
    // `pumpAndSettle` nunca terminar e derruba toda a suíte de widget. É a
    // mesma regra do brilho da dica no tabuleiro.
    if (!debugDisableMapPulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    // A aura passa da caixa do pin de propósito; sem isto o recorte
    // padrão do `Stack` cortaria justamente o auge do pulso.
    clipBehavior: Clip.none,
    children: [
      // A aura cresce e some; a gema fica parada. Sem `Transform.scale` na
      // gema de propósito: o número dela tem sombra empilhada, e sombra de
      // texto dentro de transformação animada borra no Impeller.
      //
      // Ela é **decoração e não deve medir nada**: como filho comum do
      // `Stack` ela ditaria o tamanho do conjunto e, no auge do pulso,
      // empurraria as peças ancoradas no pin. `Positioned.fill` a tira do
      // cálculo de tamanho, e o `OverflowBox` a deixa passar da borda.
      Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_c.value);
                  final aura = widget.size * (1.2 + t * 0.3);
                  return Container(
                    width: aura,
                    height: aura,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFC77BFF,
                      ).withValues(alpha: 0.22 * (1 - t)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      // O destaque vive na gema, não na animação: com o pulso desligado (na
      // suíte de testes, ou num aparelho com movimento reduzido) a fase da
      // vez continua sendo a maior e a única com aro de ouro.
      _CurrentGem(level: widget.level, size: widget.size),
    ],
  );
}

/// A gema da fase atual, parada.
class _CurrentGem extends StatelessWidget {
  const _CurrentGem({required this.level, required this.size});

  final GameLevel level;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    key: pinCoreKey(level.number),
    width: size,
    height: size,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment(-0.35, -1),
        end: Alignment(0.35, 1),
        colors: [
          NfColors.goldLight,
          NfColors.goldDeep,
          Color(0xFF9C5F0A),
          Color(0xFFF6C54A),
        ],
        stops: [0, 0.4, 0.7, 1],
      ),
      // O fio dourado por fora do aro é o que distingue a fase da vez das
      // demais com o pulso desligado — e é o que o teste lê.
      border: Border.all(color: AppColors.uiGold, width: 1),
      boxShadow: [
        const BoxShadow(color: NfColors.bronze, offset: Offset(0, 7)),
        // Os anéis de luz roxa do design: o halo que separa a gema do céu e
        // da trilha que passa atrás.
        BoxShadow(
          color: const Color(0xFFC77BFF).withValues(alpha: 0.22),
          spreadRadius: 8,
        ),
        BoxShadow(
          color: const Color(0xFFC77BFF).withValues(alpha: 0.10),
          spreadRadius: 18,
        ),
        BoxShadow(
          color: const Color(0xFFC77BFF).withValues(alpha: 0.6),
          blurRadius: 40,
        ),
      ],
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.4),
          radius: 0.85,
          colors: [Color(0xFFD49BFF), NfColors.gem, Color(0xFF5A12A8)],
          stops: [0, 0.4, 1],
        ),
      ),
      child: Center(
        child: _PinNumber(child: NfText.title('${level.number}', size: 34)),
      ),
    ),
  );
}

/// Etiqueta dourada "VOCÊ ESTÁ AQUI" ao lado da gema da vez.
class _YouAreHereTag extends StatelessWidget {
  const _YouAreHereTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // A gema já se anuncia como "liberada"; ler a etiqueta de novo seria eco.
    child: Container(
      key: youAreHereKey,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NfColors.gold,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: NfColors.goldShadow, offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: AppFonts.number,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1,
          height: 1,
          color: NfColors.goldText,
        ),
      ),
    ),
  );
}

/// Desliga o pulso do pin da fase atual.
///
/// Ligado para a suíte inteira em `test/flutter_test_config.dart`: uma animação
/// que se repete deixa `pumpAndSettle` sem fim.
bool debugDisableMapPulse = false;

/// A coroa de estrelas de uma fase vencida: a do meio maior e mais alta.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (int i = 0; i < kStarsPerLevel; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == 1 ? 5 : 0),
          child: _star(earned: i < stars, size: i == 1 ? 24 : 20),
        ),
    ],
  );

  /// A estrela não conquistada usa outro glifo (`grade_rounded`, o mesmo
  /// desenho de estrela) em vez de `star_rounded` apagada: assim "estrelas da
  /// fase" contadas pelo ícone são só as **conquistadas**, que é o que o
  /// número quer dizer.
  Widget _star({required bool earned, required double size}) => Icon(
    earned ? Icons.star_rounded : Icons.grade_rounded,
    size: size,
    color: earned ? const Color(0xFFFFC93C) : const Color(0xFF2A3266),
    shadows: earned
        ? const [Shadow(color: NfColors.goldShadow, offset: Offset(0, 1.5))]
        : null,
  );
}
