// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'NineFuse';

  @override
  String levelTitle(int number) {
    return 'Fase $number';
  }

  @override
  String objectiveCreateOne(int digit) {
    return 'Crie um $digit';
  }

  @override
  String objectiveCreateMany(int count, int digit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crie $count peças $digit',
      one: 'Crie uma peça $digit',
    );
    return '$_temp0';
  }

  @override
  String obstacleIceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'gelos',
      one: 'gelo',
    );
    return '$_temp0';
  }

  @override
  String obstacleGlassCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vidros',
      one: 'vidro',
    );
    return '$_temp0';
  }

  @override
  String obstacleStoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pedras',
      one: 'pedra',
    );
    return '$_temp0';
  }

  @override
  String objectiveClearObstacles(int count, String obstacle) {
    return 'Quebre $count $obstacle';
  }

  @override
  String objectiveClearAllObstacles(int count, String obstacle) {
    return 'Limpe o tabuleiro: $count $obstacle';
  }

  @override
  String get hudObjective => 'OBJETIVO';

  @override
  String get hudScore => 'PONTOS';

  @override
  String get hudMoves => 'JOGADAS';

  @override
  String hudScoreValue(int score) {
    return '$score pts';
  }

  @override
  String objectiveProgress(int progress, int count) {
    return '$progress de $count';
  }

  @override
  String moveBudget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Movimentos',
      one: '1 Movimento',
    );
    return '$_temp0';
  }

  @override
  String get playButton => 'JOGAR';

  @override
  String get tipAlignThree =>
      'Alinhe três peças iguais: a do seu toque evolui.';

  @override
  String get tipRepeatFusion =>
      'Repita a fusão. Trocas que não formam trio não gastam movimento.';

  @override
  String get tipChainFusion => 'Três 4 viram um 5. Planeje a fusão em cadeia.';

  @override
  String get tipBiggerMatches =>
      'Combinações de 4 ou 5 peças rendem mais que duas de 3.';

  @override
  String get tipLongLevel => 'Fase longa: cuide do espaço do tabuleiro.';

  @override
  String get tipZeroStopped =>
      'O 0 parou de cair. Peças maiores chegam do topo.';

  @override
  String get tipObstacleBlocks =>
      'Peça coberta fica presa: faça uma fusão encostada nela para quebrar a cobertura.';

  @override
  String tipApexExplodes(int digit) {
    return 'O $digit não evolui: ele explode e limpa a área em volta.';
  }

  @override
  String get outcomeWonTitle => 'FASE CONCLUÍDA!';

  @override
  String get outcomeMovesTitle => 'MOVIMENTOS ESGOTADOS';

  @override
  String get outcomeStuckTitle => 'TABULEIRO TRAVADO';

  @override
  String get outcomeGenericTitle => 'NÃO FOI DESSA VEZ';

  @override
  String outcomeWonMessage(int moves) {
    String _temp0 = intl.Intl.pluralLogic(
      moves,
      locale: localeName,
      other: 'Objetivo cumprido em $moves movimentos.',
      one: 'Objetivo cumprido em 1 movimento.',
    );
    return '$_temp0';
  }

  @override
  String get outcomeMovesMessage => 'Faltou pouco para alcançar o objetivo!';

  @override
  String get outcomeStuckMessage => 'Não restam trocas válidas!';

  @override
  String get outcomeGenericMessage => 'A fase terminou.';

  @override
  String outcomeMovesDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Os $count movimentos da fase acabaram — o tabuleiro ainda tinha jogadas.',
      one:
          'O único movimento da fase acabou — o tabuleiro ainda tinha jogadas.',
    );
    return '$_temp0';
  }

  @override
  String outcomeScore(int score) {
    return 'Pontos: $score';
  }

  @override
  String outcomeCoins(int coins) {
    return '+$coins 🪙';
  }

  @override
  String get outcomeCoinsLabel => 'MOEDAS GANHAS';

  @override
  String get nextLevelButton => 'PRÓXIMA FASE';

  @override
  String get playAgainButton => 'JOGAR DE NOVO';

  @override
  String get tryAgainButton => 'TENTAR NOVAMENTE';

  @override
  String get backToLevels => 'Voltar às fases';

  @override
  String get endlessTitle => 'Modo Recorde';

  @override
  String get endlessHighlightTitle => 'Modo Recorde 🏆';

  @override
  String get endlessPoints => 'Pontos';

  @override
  String get endlessRecord => 'Recorde';

  @override
  String get endlessBiggestTile => 'Maior Bloco';

  @override
  String get endlessNone => '—';

  @override
  String get endlessBandTop => 'Faixa máxima alcançada';

  @override
  String get endlessNextBand => 'Próxima faixa: crie um';

  @override
  String get endlessRecordTitle => 'Novo recorde!';

  @override
  String get endlessOverTitle => 'Sem Movimentos!';

  @override
  String get endlessOverMessage => 'Suas jogadas acabaram. Deseja continuar?';

  @override
  String get endlessMoves => 'Movimentos';

  @override
  String get endlessHighestDigit => 'Maior dígito';

  @override
  String get endlessExplosions => 'Explosões';

  @override
  String get endlessRestart => 'Nova corrida';

  @override
  String get endlessBackToMenu => 'Voltar ao menu';

  @override
  String endlessBestScore(int score) {
    return 'Sua melhor pontuação: $score pts';
  }

  @override
  String endlessLockedHint(int level) {
    return 'Conclua a fase $level para liberar';
  }

  @override
  String get endlessCta => 'Superar Recorde';

  @override
  String get starsCaption => 'CAPÍTULO';

  @override
  String starsSemantics(int earned, int total) {
    return '$earned de $total estrelas do capítulo';
  }

  @override
  String chapterLabel(int number, String name) {
    return 'Capítulo $number: $name';
  }

  @override
  String get chapterPrimaryFusions => 'Fusões Primárias';

  @override
  String get chapterTowardNine => 'Rumo ao Nove';

  @override
  String semanticsLevelCleared(
    int number,
    int stars,
    int total,
    String objective,
  ) {
    return 'Fase $number, concluída com $stars de $total estrelas. $objective.';
  }

  @override
  String semanticsLevelCurrent(int number, String objective) {
    return 'Fase $number, liberada. $objective.';
  }

  @override
  String semanticsLevelLocked(int number) {
    return 'Fase $number, bloqueada.';
  }

  @override
  String get comboSuperFusion => 'SUPER FUSÃO!';

  @override
  String get comboTwo => 'COMBO x2!';

  @override
  String comboMany(int count) {
    return 'INCRÍVEL x$count!';
  }

  @override
  String get apexCelebration => 'FUSÃO MÁXIMA ALCANÇADA! 🎉';

  @override
  String chapterStarsSemantics(int stars, int total, String chapter) {
    return '$stars de $total estrelas no $chapter.';
  }

  @override
  String bonusMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count Movimentos!',
      one: '+1 Movimento!',
    );
    return '$_temp0';
  }

  @override
  String hammerButton(int count) {
    return 'MARTELO ($count)';
  }

  @override
  String get hammerCancel => 'CANCELAR';

  @override
  String get hammerAimHint => 'Toque na célula para quebrar';

  @override
  String get hammerOfferTitle => 'Sem martelos';

  @override
  String get hammerOfferBody =>
      'Assista a um anúncio curto e quebre a célula que você escolheu.';

  @override
  String get hammerOfferWatch => 'ASSISTIR AD';

  @override
  String get hammerOfferDecline => 'AGORA NÃO';

  @override
  String get hammerOfferFailed => 'Nenhum anúncio disponível agora.';

  @override
  String hammerOfferBuy(int price) {
    return 'Comprar por $price 🪙';
  }

  @override
  String get hammerOfferNoCoins => 'Moedas insuficientes';

  @override
  String hammerOfferBalance(int coins) {
    return 'Você tem $coins 🪙';
  }

  @override
  String hammerOfferEarnCoins(int reward) {
    return 'Ganhar +$reward 🪙 (Assistir Vídeo)';
  }

  @override
  String hammerOfferEarnedCoins(int reward) {
    return '+$reward 🪙 creditadas no seu saldo!';
  }

  @override
  String get coinSourcesTitle => 'Como ganhar moedas';

  @override
  String get coinSourcesStars => 'Vença fases com 3 estrelas';

  @override
  String get coinSourcesAds => 'Assista a vídeos de recompensa';

  @override
  String get coinSourcesChests => 'Conclua os capítulos do mapa';

  @override
  String hammerSemantics(int count) {
    return 'Martelo de Fusão, $count em estoque. Quebra uma célula sem gastar movimento.';
  }

  @override
  String get movesOfferTitle => 'Quase lá!';

  @override
  String movesOfferBody(int count, int reward) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count movimentos',
      one: 'Resta 1 movimento',
    );
    return '$_temp0. Assista a um anúncio curto e ganhe mais $reward.';
  }

  @override
  String movesOfferWatch(int reward) {
    return 'GANHAR +$reward MOVIMENTOS';
  }

  @override
  String get movesOfferDecline => 'CONTINUAR ASSIM';

  @override
  String get movesOfferFailed => 'Nenhum anúncio disponível agora.';

  @override
  String get storeSubtitle => 'Combine 3, evolua o número, alcance o 9';

  @override
  String get storeShortDescription =>
      'Match-3 de números: três iguais viram o próximo. Chegue ao 9 e detone o tabuleiro.';

  @override
  String get storeFullDescription =>
      'NineFuse é um quebra-cabeça de números em que combinar não é só eliminar.\n\nAlinhe três dígitos iguais e o do meio EVOLUI para o próximo: três 4 viram um 5. Repita a fusão, planeje a cadeia e suba a escala até o clímax do jogo — o dígito 9, que detona numa onda de choque, limpa a vizinhança e devolve movimentos.\n\n• FUSÃO, NÃO SÓ ELIMINAÇÃO — a mecânica do Match-3 com a progressão do merge.\n• O RITUAL DO 9 — o dígito máximo explode, quebra pedras e paga movimentos bônus.\n• GELO, VIDRO E PEDRA — coberturas que cedem a 1, 2 ou 3 fusões encostadas.\n• CAMPANHA COM OBJETIVOS — alcance um dígito, quebre coberturas, limpe o tabuleiro.\n• MODO RECORDE — corrida sem limite de movimentos, com o seu recorde guardado.\n• MARTELO DE FUSÃO — quebre uma célula travada sem gastar jogada.\n• SEM TRAVA DE VIDAS — jogue quantas vezes quiser, na hora que quiser.\n\nVisual escuro, cores vibrantes por dígito e animações de fusão fluídas.';

  @override
  String get storeKeywords =>
      'match 3 numeros,quebra cabeca numeros,jogo de fusao,puzzle numerico,merge numeros,jogo 2048 match 3,puzzle offline,jogo de logica';
}
