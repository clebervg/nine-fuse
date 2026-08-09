import 'package:nine_fuse/features/game/domain/game_level.dart';

/// Um trecho nomeado da campanha.
///
/// Existe para o mapa ter marcos: dez pins numerados em fila são dez pins
/// numerados em fila, mas "Capítulo 1: Fusões Primárias" dá ao jogador a
/// sensação de ter atravessado alguma coisa. O corte não é decorativo — cai
/// exatamente onde a **janela de spawn** começa a subir, que é onde o jogo
/// muda de natureza.
/// Nome de um capítulo, como **identidade** e não como texto.
///
/// O nome traduzido mora nos arquivos de tradução, pelo mesmo motivo de
/// [LevelTip]: guardá-lo aqui obrigaria o `domain` a conhecer `BuildContext`.
enum ChapterName { primaryFusions, towardNine }

class CampaignChapter {
  const CampaignChapter({
    required this.number,
    required this.name,
    required this.firstLevel,
    required this.lastLevel,
  });

  final int number;
  final ChapterName name;

  /// Faixa de fases, inclusiva nas duas pontas.
  final int firstLevel;
  final int lastLevel;

  bool contains(int levelNumber) =>
      levelNumber >= firstLevel && levelNumber <= lastLevel;

  /// Quantas fases o capítulo tem.
  int get levelCount => lastLevel - firstLevel + 1;

  /// Total de estrelas em jogo neste capítulo.
  int get starTotal => levelCount * kStarsPerLevel;

  @override
  String toString() => 'CampaignChapter($number, ${name.name})';
}

/// Estrelas máximas por fase.
const int kStarsPerLevel = 3;

/// Os capítulos da campanha.
///
/// O corte em 6 não é arbitrário: até a fase 6 a janela de sorteio é 0-3 e o
/// jogo inteiro se resolve com os dígitos baixos. Da 7 em diante a janela sobe,
/// o `0` para de cair e as fases passam a repetir dificuldades já calibradas um
/// dígito acima — é outro jogo, e merece outro nome.
const List<CampaignChapter> kChapters = [
  CampaignChapter(
    number: 1,
    name: ChapterName.primaryFusions,
    firstLevel: 1,
    lastLevel: 6,
  ),
  CampaignChapter(
    number: 2,
    name: ChapterName.towardNine,
    firstLevel: 7,
    lastLevel: 10,
  ),
];

/// O capítulo a que [levelNumber] pertence.
///
/// Nunca devolve nulo: uma fase fora de qualquer faixa cai no último capítulo,
/// porque estender a campanha sem lembrar de estender os capítulos não pode
/// quebrar o mapa.
CampaignChapter chapterOf(int levelNumber) => kChapters.firstWhere(
  (chapter) => chapter.contains(levelNumber),
  orElse: () => kChapters.last,
);

/// Total de estrelas que a campanha inteira oferece.
int get kCampaignStarTotal => kCampaign.length * kStarsPerLevel;
