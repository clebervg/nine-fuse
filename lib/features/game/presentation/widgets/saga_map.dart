import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/features/game/presentation/widgets/obstacle_overlay.dart';
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

/// Distância fixa entre a borda de baixo do círculo e o rótulo do pin
/// (estrelas ou "JOGAR").
///
/// Negativa de propósito: o rótulo fica **fora** do círculo, ancorado a ele e
/// não à caixa do nó, para nunca cavalgar a curva do caminho — que passa
/// exatamente pelo centro do pin.
const double kPinBadgeOffset = -18;

/// Estado visual de um pin.
enum PinState {
  /// Já vencida: mostra as estrelas conquistadas.
  cleared,

  /// A próxima a jogar. É o único pin que pulsa.
  current,

  /// Ainda travada.
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
  static const double step = 132;

  /// Folga acima do primeiro pin e abaixo do último.
  static const double margin = 90;

  /// Diâmetro do pin comum. O da fase atual é desenhado maior, mas ocupa o
  /// mesmo lugar — senão a rolagem calculada não bateria com o que se vê.
  static const double pinSize = 68;

  /// Quanto o pin da fase atual é maior que os demais.
  ///
  /// Contido de propósito: o destaque precisa ser óbvio sem desalinhar a
  /// trilha, e o aro dourado já faz metade do trabalho. Acima disso o pin
  /// começa a encostar nos vizinhos.
  static const double currentPinScale = 1.1;

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
                _positionedPin(geometry, i, child: _pinFor(levels[i])),
              // Nós projetados: nem fase nem placeholder tocável, só a promessa
              // de que a trilha continua.
              for (int i = levels.length; i <= geometry.lastIndex; i++)
                _positionedPin(geometry, i, child: const _FuturePin()),
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

  Widget _pinFor(GameLevel level) => _LevelPin(
    level: level,
    state: _stateOf(level),
    stars: starsOf(level.number),
    onTap: () => onTapLevel(level),
  );

  /// Assenta um nó **centrado no ponto da trilha**.
  ///
  /// A caixa é quadrada e um pouco maior que o pin, e o conteúdo vai num
  /// `Center`: assim o pin recebe restrição frouxa e se mede sozinho, o que é
  /// o que deixa as estrelas ancoradas em relação ao **círculo** e não em
  /// relação a uma caixa arbitrária.
  Widget _positionedPin(
    SagaGeometry geometry,
    int index, {
    required Widget child,
  }) {
    final centre = geometry.centerOf(index);
    const box = SagaGeometry.pinSize * 1.3;

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
/// Dois traços sobrepostos: o cinza inteiro, e por cima o colorido até onde o
/// jogador chegou. É o que dá ao mapa a leitura de "isto já é meu, aquilo
/// ainda não" sem precisar de legenda.
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

  /// Traçado completo das fases jogáveis.
  Path _fullPath() => _pathBetween(0, geometry.levelCount - 1);

  /// Desenha [path] em tracinhos, para o trecho projetado se ler como
  /// "ainda não existe" sem precisar de outra cor.
  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 11.0;
    const gap = 10.0;

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          paint,
        );
        start += dash + gap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.levelCount < 1) return;

    // O caminho projetado vem primeiro: ele passa por trás de tudo e é o que
    // impede o mapa de terminar em corte seco na última fase.
    if (SagaGeometry.futureNodes > 0) {
      _drawDashed(
        canvas,
        _pathBetween(geometry.levelCount - 1, geometry.lastIndex),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.10),
      );
    }

    if (geometry.levelCount < 2) return;

    final path = _fullPath();
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.07);

    canvas.drawPath(path, track);

    // Quanto do caminho está conquistado, em fração do traçado inteiro. Cada
    // trecho vale o mesmo, então a fração é contagem de trechos.
    final segments = geometry.levelCount - 1;
    var doneSegments = clearedUpTo.clamp(0, segments).toDouble();

    // Animação de liberação: o último trecho cresce em vez de aparecer pronto.
    if (revealTo != null && revealTo! > 0) {
      final target = revealTo!.clamp(0, segments).toDouble();
      doneSegments = math.min(doneSegments, target - 1 + revealProgress);
    }

    if (doneSegments <= 0) return;

    final done = metric.extractPath(0, metric.length * doneSegments / segments);

    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.digit2, AppColors.digit7],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.clearedUpTo != clearedUpTo ||
      old.revealTo != revealTo ||
      old.revealProgress != revealProgress ||
      old.geometry.width != geometry.width;
}

/// Um pin de fase: o número da fase, o estado e as estrelas.
class _LevelPin extends StatelessWidget {
  const _LevelPin({
    required this.level,
    required this.state,
    required this.stars,
    required this.onTap,
  });

  final GameLevel level;
  final PinState state;
  final int stars;
  final VoidCallback onTap;

  bool get _isLocked => state == PinState.locked;

  @override
  Widget build(BuildContext context) {
    // Fase de cobertura não tem dígito-alvo: o pin toma a cor da própria
    // cobertura, a mesma que ela terá no tabuleiro.
    final accent = level.objective.isObstacleGoal
        ? obstacleAccent(level.objective.obstacle)
        : AppColors.getColorByDigit(level.objective.digit!);

    // O rótulo é `Positioned` e não irmão de `Column`: fora do cálculo de
    // tamanho, ele fica ancorado a uma distância fixa da borda do círculo, sem
    // depender de quanto o pin cresce (o da fase atual é maior) nem esbarrar na
    // curva do caminho, que passa exatamente pelo centro do pin.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Semantics(
          button: !_isLocked,
          enabled: !_isLocked,
          // Sem rótulo, um leitor de tela anuncia só o número solto do pin.
          label: _semanticLabel(AppLocalizations.of(context)),
          child: GestureDetector(
            key: levelCardKey(level.number),
            onTap: _isLocked ? null : _handleTap,
            behavior: HitTestBehavior.opaque,
            child: switch (state) {
              PinState.current => _CurrentPin(level: level, accent: accent),
              PinState.cleared => _StaticPin(
                level: level,
                color: accent,
                locked: false,
              ),
              PinState.locked => _StaticPin(
                level: level,
                color: accent,
                locked: true,
              ),
            },
          ),
        ),
        if (state == PinState.cleared)
          Positioned(
            bottom: kPinBadgeOffset,
            child: _StarRow(stars: stars),
          )
        else if (state == PinState.current)
          Positioned(
            bottom: kPinBadgeOffset,
            child: Text(
              AppLocalizations.of(context).playButton,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
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
    // Som curto de toque do próprio sistema. Escolhido em vez de um pacote de
    // áudio de propósito: não acrescenta dependência nem arquivo de som ao
    // pacote, e respeita o ajuste de som do aparelho sem código nosso.
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
    onTap();
  }
}

/// Pin de fase concluída ou bloqueada. Não anima: só a fase atual chama a
/// atenção, senão o mapa inteiro pisca e nada se destaca.
class _StaticPin extends StatelessWidget {
  const _StaticPin({
    required this.level,
    required this.color,
    required this.locked,
    this.highlighted = false,
  });

  final GameLevel level;
  final Color color;
  final bool locked;

  /// Pin da fase atual: maior, com aro dourado. O destaque é estático — o
  /// pulso vem de fora, em [_CurrentPin] — para que ele continue valendo mesmo
  /// com a animação desligada.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fill = locked ? const Color(0xFF2A2A2E) : color;
    final size =
        SagaGeometry.pinSize * (highlighted ? SagaGeometry.currentPinScale : 1);

    return Container(
      // Chave própria: o pin da fase atual vem embrulhado numa aura que também
      // é um `Container` redondo, e procurar pelo tipo acharia a aura.
      key: pinCoreKey(level.number),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: locked
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.lighten(fill, 0.12),
                  fill,
                  AppColors.darken(fill, 0.10),
                ],
                stops: const [0, 0.55, 1],
              ),
        color: locked ? fill : null,
        // O aro dourado é o que diz "toque aqui". Mais grosso e opaco que o
        // dos demais: num mapa cheio de círculos coloridos, um contorno branco
        // translúcido some.
        border: Border.all(
          color: switch ((locked, highlighted)) {
            (_, true) => AppColors.digit3,
            (true, _) => Colors.white.withValues(alpha: 0.10),
            _ => Colors.white.withValues(alpha: 0.28),
          },
          width: highlighted ? 4 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: locked ? Colors.black54 : color.withValues(alpha: 0.45),
            blurRadius: locked ? 6 : 14,
            offset: const Offset(0, 4),
          ),
          // Halo dourado por fora do aro, para o destaque sobreviver ao fundo
          // escuro e ao caminho passando atrás.
          if (highlighted)
            BoxShadow(
              color: AppColors.digit3.withValues(alpha: 0.55),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        child: locked
            ? const Icon(Icons.lock_outline, color: Colors.white38, size: 26)
            : Text(
                '${level.number}',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  color: level.objective.isObstacleGoal
                      ? AppColors.darkBackground
                      : AppColors.getTextColorForDigit(level.objective.digit!),
                  fontSize: highlighted ? 29 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

/// Nó projetado, além da última fase existente.
///
/// Menor, translúcido e sem número: não promete uma fase específica, só que a
/// trilha continua. Não é tocável e não tem semântica de botão — anunciá-lo a
/// um leitor de tela como fase daria a entender que existe algo para abrir.
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
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.lock_outline,
            size: 20,
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
      ),
    );
  }
}

/// Pin da fase atual: maior, com aura pulsando.
///
/// É o único elemento animado do mapa, e por isso o olho vai direto nele — que
/// é exatamente a função dele.
class _CurrentPin extends StatefulWidget {
  const _CurrentPin({required this.level, required this.accent});

  final GameLevel level;
  final Color accent;

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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(_c.value);
      return Stack(
        alignment: Alignment.center,
        // A aura passa da caixa do pin de propósito; sem isto o recorte
        // padrão do `Stack` cortaria justamente o auge do pulso.
        clipBehavior: Clip.none,
        children: [
          // A aura cresce e some; o pin em si só respira de leve, para o
          // número não ficar dançando e ilegível.
          //
          // Ela é **decoração e não deve medir nada**: como filho comum do
          // `Stack` ela ditava o tamanho do conjunto, e no auge do pulso
          // empurrava o rótulo "JOGAR" para fora da caixa do pin. Nenhum
          // teste via isso, porque o pulso fica desligado na suíte inteira
          // e a aura parada cabe. `Positioned.fill` a tira do cálculo de
          // tamanho, e o `OverflowBox` a deixa passar da borda ao crescer.
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Container(
                    width: SagaGeometry.pinSize * (1.35 + t * 0.35),
                    height: SagaGeometry.pinSize * (1.35 + t * 0.35),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.digit3.withValues(alpha: 0.26 * (1 - t)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.scale(scale: 1 + t * 0.04, child: child),
        ],
      );
    },
    // O destaque vive no pin, não na animação: com o pulso desligado (na
    // suíte de testes, ou num aparelho com movimento reduzido) a fase da
    // vez continua sendo a maior e a única com aro dourado.
    child: _StaticPin(
      level: widget.level,
      color: widget.accent,
      locked: false,
      highlighted: true,
    ),
  );
}

/// Desliga o pulso do pin da fase atual.
///
/// Ligado para a suíte inteira em `test/flutter_test_config.dart`: uma animação
/// que se repete deixa `pumpAndSettle` sem fim.
bool debugDisableMapPulse = false;

/// As três estrelas de uma fase vencida, as não conquistadas apagadas.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (int i = 0; i < kStarsPerLevel; i++)
        Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: i < stars
              ? AppColors.digit3
              : Colors.white.withValues(alpha: 0.20),
        ),
    ],
  );
}
