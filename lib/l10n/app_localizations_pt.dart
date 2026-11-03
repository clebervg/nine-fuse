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
  String objectiveCollect(int count, int digit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Funda $count peças $digit',
      one: 'Funda 1 peça $digit',
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
  String obstacleChainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'correntes',
      one: 'corrente',
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
  String get levelStartShopHammer => 'Martelo';

  @override
  String get levelStartShopBomb => 'Bomba';

  @override
  String get levelStartShopBrush => 'Pincel';

  @override
  String levelStartShopBuy(int price) {
    return '$price 🪙';
  }

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
    return 'O $digit não evolui: ele fica no tabuleiro e limpa os bloqueios ao redor.';
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
  String get endlessExplosions => 'Super 9 ativados';

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
  String get boostersLabel => 'Boosters';

  @override
  String get hammerAimHint => 'Toque na célula para quebrar';

  @override
  String get hammerOfferTitle => 'Sem martelos';

  @override
  String get hammerOfferBody =>
      'Assista a um anúncio curto e quebre a célula que você escolheu.';

  @override
  String get hammerOfferAdCapReached => 'Volte amanhã para mais vídeos';

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
  String get continueOfferTitle => 'SEM JOGADAS';

  @override
  String continueOfferBody(int bonus) {
    return 'Assista a um anúncio curto ou gaste moedas para ganhar $bonus movimentos extras e continuar.';
  }

  @override
  String continueOfferWatch(int bonus) {
    return 'ASSISTIR (+$bonus)';
  }

  @override
  String continueOfferBuy(int price) {
    return 'Comprar por $price 🪙';
  }

  @override
  String get continueOfferDecline => 'DESISTIR';

  @override
  String get continueOfferFailed => 'Nenhum anúncio disponível agora.';

  @override
  String get continueOfferNoCoins => 'Moedas insuficientes';

  @override
  String continueOfferBalance(int coins) {
    return 'Você tem $coins 🪙';
  }

  @override
  String get bombOfferTitle => 'Sem bombas';

  @override
  String get bombOfferBody =>
      'Assista a um anúncio curto e destrua a área 3x3 escolhida.';

  @override
  String get bombOfferWatch => 'ASSISTIR ANÚNCIO';

  @override
  String bombOfferBuy(int price) {
    return 'Comprar por $price 🪙';
  }

  @override
  String get bombOfferDecline => 'AGORA NÃO';

  @override
  String get bombOfferFailed => 'Nenhum anúncio disponível agora.';

  @override
  String get bombOfferNoCoins => 'Moedas insuficientes';

  @override
  String bombOfferBalance(int coins) {
    return 'Você tem $coins 🪙';
  }

  @override
  String get brushOfferTitle => 'Sem pincéis';

  @override
  String get brushOfferBody =>
      'Assista a um anúncio curto e eleve em 1 a peça escolhida.';

  @override
  String get brushOfferWatch => 'ASSISTIR ANÚNCIO';

  @override
  String brushOfferBuy(int price) {
    return 'Comprar por $price 🪙';
  }

  @override
  String get brushOfferDecline => 'AGORA NÃO';

  @override
  String get brushOfferFailed => 'Nenhum anúncio disponível agora.';

  @override
  String get brushOfferNoCoins => 'Moedas insuficientes';

  @override
  String brushOfferBalance(int coins) {
    return 'Você tem $coins 🪙';
  }

  @override
  String get coinStoreTitle => 'Suas moedas';

  @override
  String get coinStoreClose => 'FECHAR';

  @override
  String coinsBadgeSemantics(int coins) {
    return '$coins moedas';
  }

  @override
  String hammersBadgeSemantics(int hammers) {
    return '$hammers martelos';
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
  String get coinSourceNova => 'Dispare uma Fusão Nova';

  @override
  String hammerSemantics(int count) {
    return 'Martelo de Fusão, $count em estoque. Quebra uma célula sem gastar movimento.';
  }

  @override
  String bombSemantics(int count) {
    return 'Bomba, $count em estoque. Explode uma área 3x3 sem gastar movimento.';
  }

  @override
  String brushSemantics(int count) {
    return 'Pincel, $count em estoque. Soma 1 ao valor de uma peça sem gastar movimento.';
  }

  @override
  String get dailySpinTitle => 'Roleta Diária';

  @override
  String get dailySpinSubtitle => '1 giro grátis por dia';

  @override
  String get dailySpinSpinButton => 'GIRAR';

  @override
  String get dailySpinWatchAgainButton => 'Girar de Novo (Assistir Vídeo)';

  @override
  String get dailySpinCloseButton => 'FECHAR';

  @override
  String get dailySpinFreeButton => 'GIRAR GRÁTIS';

  @override
  String get dailySpinNextFreeIn => 'Próximo giro grátis em';

  @override
  String get dailySpinPrizeTitle => 'VOCÊ GANHOU!';

  @override
  String get dailySpinCollectButton => 'COLETAR';

  @override
  String dailySpinStockFull(int coins) {
    return 'Estoque cheio: +$coins moedas';
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
  String get endlessSuggestionTitle => 'Sem energia agora?';

  @override
  String get endlessSuggestionBody =>
      'Sua energia nesta fase acabou! Que tal bater seu Recorde Pessoal enquanto ela recarrega?';

  @override
  String get endlessSuggestionGo => 'IR PARA O MODO RECORDE';

  @override
  String get endlessSuggestionDecline => 'CONTINUAR TENTANDO';

  @override
  String get storeSubtitle => 'Combine 3, evolua o número, alcance o 9';

  @override
  String get storeShortDescription =>
      'Match-3 de números: três iguais viram o próximo. Chegue ao 9 e libere o Super 9.';

  @override
  String get storeFullDescription =>
      'NineFuse é um quebra-cabeça de números em que combinar não é só eliminar.\n\nAlinhe três dígitos iguais e o do meio EVOLUI para o próximo: três 4 viram um 5. Repita a fusão, planeje a cadeia e suba a escala até o clímax do jogo — o dígito 9, que limpa os bloqueios ao redor, e o raro Super 9 (fusão de 5+), que converte todo um valor do tabuleiro numa única troca.\n\n• FUSÃO, NÃO SÓ ELIMINAÇÃO — a mecânica do Match-3 com a progressão do merge.\n• O RITUAL DO 9 — o dígito máximo limpa bloqueios ao redor, e o Super 9 promove o tabuleiro inteiro.\n• GELO, VIDRO E PEDRA — coberturas que cedem a 1, 2 ou 3 fusões encostadas.\n• CAMPANHA COM OBJETIVOS — alcance um dígito, quebre coberturas, limpe o tabuleiro.\n• MODO RECORDE — corrida sem limite de movimentos, com o seu recorde guardado.\n• MARTELO DE FUSÃO — quebre uma célula travada sem gastar jogada.\n• SEM TRAVA DE VIDAS — jogue quantas vezes quiser, na hora que quiser.\n\nVisual escuro, cores vibrantes por dígito e animações de fusão fluídas.';

  @override
  String get storeKeywords =>
      'match 3 numeros,quebra cabeca numeros,jogo de fusao,puzzle numerico,merge numeros,jogo 2048 match 3,puzzle offline,jogo de logica';

  @override
  String get privacyTitle => 'Privacidade';

  @override
  String get privacyBody =>
      'O NineFuse guarda seu progresso só neste aparelho. Os anúncios são do Google AdMob.';

  @override
  String get privacyPolicyLink => 'Política de Privacidade';

  @override
  String get privacyAdOptions => 'Opções de privacidade dos anúncios';

  @override
  String get privacyClose => 'FECHAR';

  @override
  String get privacyTooltip => 'Privacidade';

  @override
  String get outcomeWonHeadline => 'CONCLUÍDA!';

  @override
  String get continueOfferResume => 'CONTINUAR DE ONDE PAROU';

  @override
  String continueOfferBonus(int bonus) {
    String _temp0 = intl.Intl.pluralLogic(
      bonus,
      locale: localeName,
      other: '+$bonus JOGADAS',
      one: '+1 JOGADA',
    );
    return '$_temp0';
  }

  @override
  String objectiveMissingDigit(int count, int digit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltou pouco: $count peças $digit.',
      one: 'Faltou pouco: 1 peça $digit.',
    );
    return '$_temp0';
  }

  @override
  String objectiveMissingObstacle(int count, String obstacle) {
    return 'Faltou pouco: $count $obstacle.';
  }

  @override
  String mapChapterStars(int number, int earned, int total) {
    return 'CAPÍTULO $number · $earned/$total';
  }

  @override
  String get mapYouAreHere => 'VOCÊ ESTÁ AQUI';

  @override
  String mapLevelsCleared(int last) {
    return 'Fases 1–$last concluídas';
  }

  @override
  String mapPlayLevel(int number) {
    return 'JOGAR FASE $number';
  }

  @override
  String mapNewObstacle(int level, String obstacle) {
    return 'Novo obstáculo na fase $level: $obstacle';
  }

  @override
  String get mapDailySpinTooltip => 'Roleta diária';

  @override
  String get homeShop => 'LOJA';

  @override
  String get homeSpin => 'ROLETA';

  @override
  String get homeMap => 'MAPA';

  @override
  String homeChapterLevel(int chapter, int level) {
    return 'CAPÍTULO $chapter · FASE $level';
  }

  @override
  String homeStarsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estrelas na campanha',
      one: '1 estrela na campanha',
    );
    return '$_temp0';
  }

  @override
  String get shopTitle => 'LOJA';

  @override
  String get shopBoosters => 'BOOSTERS';

  @override
  String get shopCoins => 'MOEDAS';

  @override
  String shopStock(int count) {
    return 'Você tem $count';
  }

  @override
  String shopVideoTitle(int coins) {
    return '+$coins moedas';
  }

  @override
  String get shopVideoSubtitle => 'Assista a um vídeo curto';

  @override
  String get shopWatch => 'ASSISTIR';

  @override
  String get shopBuyFailed =>
      'Não deu para concluir a compra. Suas moedas não foram gastas.';

  @override
  String get chestReadyTitle => 'Baú do capítulo!';

  @override
  String get chestCollect => 'COLETAR';

  @override
  String get chestLockedTitle => 'Baú trancado';

  @override
  String chestLockedHint(int chapter) {
    return 'Vença as fases do capítulo $chapter para abrir.';
  }

  @override
  String get chestOk => 'OK';

  @override
  String semanticsChestLocked(int chapter) {
    return 'Baú do capítulo $chapter, trancado.';
  }

  @override
  String semanticsChestReady(int chapter) {
    return 'Baú do capítulo $chapter, pronto para abrir.';
  }

  @override
  String semanticsChestOpened(int chapter) {
    return 'Baú do capítulo $chapter, já aberto.';
  }

  @override
  String get settingsTooltip => 'Configurações';

  @override
  String get settingsTitle => 'AJUSTES';

  @override
  String get settingsSectionAudio => 'SOM E TOQUE';

  @override
  String get settingsSound => 'Efeitos sonoros';

  @override
  String get settingsVolume => 'Volume dos efeitos';

  @override
  String get settingsMusic => 'Música';

  @override
  String get settingsVibration => 'Vibração';

  @override
  String get settingsSectionLanguage => 'IDIOMA';

  @override
  String get settingsLanguageSystem => 'Do aparelho';

  @override
  String get settingsLanguagePt => 'Português';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsSectionPrivacy => 'PRIVACIDADE';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidade';

  @override
  String get settingsConsent => 'Gerenciar consentimento de anúncios';

  @override
  String get settingsSectionAbout => 'SOBRE';

  @override
  String get settingsCredits => 'Créditos';

  @override
  String get settingsLicenses => 'Licenças de código aberto';

  @override
  String get creditsTitle => 'Créditos';

  @override
  String get creditsBody =>
      'Fontes Nunito, Lilita One e Baloo 2 sob a SIL Open Font License (OFL).\nPeças, coberturas e ícones: pacote de arte \"candy pop\" do NineFuse.\nEfeitos sonoros: Kenney (kenney.nl), CC0.\nFeito com Flutter.';

  @override
  String get creditsClose => 'FECHAR';

  @override
  String get tutorialFirstSwap =>
      'Troque estas duas peças para alinhar três iguais.';

  @override
  String tutorialFusion(String amount, int from, int to) {
    return 'A peça do seu toque evolui: $amount $from viram um $to!';
  }

  @override
  String tutorialAmount(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {
      'three': 'três',
      'four': 'quatro',
      'five': 'cinco',
      'other': 'várias',
    });
    return '$_temp0';
  }

  @override
  String tutorialObjective(String objective) {
    return '$objective para vencer.';
  }

  @override
  String get tutorialMovesMedallion =>
      'Estas são suas jogadas. Cada troca que forma trio gasta uma.';

  @override
  String get tutorialFreeMiss =>
      'Troca sem trio não gasta jogada: as peças só voltam ao lugar.';

  @override
  String get tutorialBoosterDock =>
      'Travou? O Martelo quebra a peça que você tocar, sem gastar jogada.';

  @override
  String get tutorialObstacleIce =>
      'Gelo prende a peça. Uma fusão encostada nele o quebra.';

  @override
  String get tutorialObstacleGlass =>
      'Vidro aguenta duas fusões encostadas antes de quebrar.';

  @override
  String get tutorialObstacleStone =>
      'Pedra aguenta três fusões encostadas, ou cede de vez a um 9 nascido ao lado.';

  @override
  String get tutorialObstacleChain =>
      'A corrente prende a peça no lugar: ela não troca nem cai, mas ainda combina. Alinhe com ela ou funda ao lado para soltá-la.';

  @override
  String get tutorialCollectGoal =>
      'Aqui conta a peça que ENTRA na fusão: alinhe três dessas e já são três a menos.';

  @override
  String get tutorialBoardShape =>
      'As casas escuras não fazem parte do tabuleiro. As peças caem por cima delas.';

  @override
  String get tutorialGotIt => 'ENTENDI';

  @override
  String get tutorialSkip => 'Pular tutorial';

  @override
  String get settingsReplayTutorial => 'Rever tutorial';

  @override
  String get settingsReplayTutorialDone =>
      'O tutorial vai aparecer de novo nas próximas fases.';
}
