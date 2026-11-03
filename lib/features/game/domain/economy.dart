/// Os números da economia de moedas, num lugar só.
///
/// Ficam nomeados porque vão ser recalibrados: espalhá-los como literais pela
/// UI e pelos providers transformaria o próximo ajuste de balanceamento em caça
/// ao número mágico.
library;

/// Moedas por estrela **nova**.
///
/// Só estrela nova paga: `CampaignRecords.record()` já devolve o ganho com as
/// que o jogador tinha descontadas, então refazer a fase 1 não farma.
///
/// Era 10, calibrado quando a campanha tinha 10 fases. Com a campanha
/// infinita, estrela e baú sozinhos davam ~0,5 booster por fase vencida, e
/// somados à recompensa diária e às missões passavam de um por fase
/// (recalibragem de 2026-11-03, ver `CLAUDE.md`).
const int kCoinsPerStar = 5;

/// Preço de um Martelo de Fusão em moedas.
///
/// Deliberadamente caro: um capítulo em três estrelas rende 150 moedas, mais
/// 100 do baú — um Martelo e pouco. O anúncio recompensado continua sendo o
/// caminho principal de aquisição — a moeda é o consolo de quem não quer vê-lo,
/// não um substituto. Subiu de 100 para 150 na recalibragem de 2026-11-03.
const int kHammerCoinPrice = 150;

/// Preço avulso da Bomba em moedas.
///
/// Mais cara que Martelo e Pincel (150): a Bomba afeta uma área 3x3 inteira
/// de uma vez, não uma célula única — o preço reflete o poder, não só a
/// categoria "booster avulso".
const int kBombCoinPrice = 200;

/// Preço avulso do Pincel em moedas. Mesmo do Martelo (150): afeta uma
/// célula só, sem a área da Bomba.
const int kBrushCoinPrice = 150;

/// O que o baú de fim de capítulo paga, uma única vez por capítulo.
const int kChapterChestReward = 100;

/// Último capítulo do baú **grande** ([kChapterChestReward]). Acima dele o
/// baú continua, menor ([kLateChapterChestReward]) — ver
/// [chapterChestReward].
///
/// Até 2026-11-03 acima disto não havia baú nenhum, para a campanha infinita
/// não imprimir moeda para sempre. O dono do produto pediu o baú de volta
/// depois do capítulo 20 (o jogador da fase 200 em diante ficava sem nenhuma
/// marca de fim de capítulo); a torneira continua contida pelo valor, não
/// mais pelo teto.
///
/// Capítulos 1-2 são os artesanais (fases 1-10); capítulos 3-20 são os
/// primeiros 18 capítulos gerados (10 fases cada, `kBlockSize` em
/// `level_generator.dart`) — cobre até a fase ~190. Teto de moeda
/// vitalícia via baú: 20 * kChapterChestReward = 2000.
const int kChapterChestPayableCount = 20;

/// O baú dos capítulos depois do [kChapterChestPayableCount]: metade do grande.
///
/// Uma vez a cada 10 fases, isto rende ~5 moedas por fase — 3% de um Martelo.
/// É a marca de "capítulo concluído", não uma fonte de moeda; a calibragem
/// de 2026-11-03 (`tool/economy_income_model.py`) quase não se move com ele.
const int kLateChapterChestReward = 50;

/// O que o baú do capítulo [chapter] paga. Zero para capítulo não positivo.
int chapterChestReward(int chapter) {
  if (chapter < 1) return 0;
  return chapter <= kChapterChestPayableCount
      ? kChapterChestReward
      : kLateChapterChestReward;
}

/// Moedas por anúncio premiado assistido até o fim.
///
/// Vinte e cinco é um sexto do martelo: seis vídeos compram o item que um
/// vídeo já daria direto. É de propósito — o vídeo que paga o martelo continua
/// sendo o caminho curto, e este é a torneira de quem prefere juntar. Um valor
/// alto demais aqui esvaziaria o funil do martelo; um valor baixo demais faria
/// o botão parecer enfeite.
const int kCoinsPerRewardedAd = 25;

/// Movimentos pagos por **alvo restante** no anúncio de reforço de saldo.
///
/// O prêmio fixo que este número substitui era esmola numa fase a um alvo do
/// fim e insuficiente numa fase de cobertura com três pedras de pé — o jogador
/// assistia ao anúncio e perdia do mesmo jeito, que é o que ensina a não
/// assistir ao próximo.
const double kMovesPerTarget = 3.0;

/// Piso do prêmio. Abaixo disto o anúncio não muda desfecho nenhum, e um
/// prêmio que não muda o desfecho é pior do que não ter sido oferecido.
const int kRewardedMinMoves = 4;

/// Teto do prêmio. Sem ele uma fase de objetivo alto renderia meia fase nova
/// por um vídeo, e o limite de movimentos deixaria de significar alguma coisa.
const int kRewardedMaxMoves = 10;

/// Movimentos pagos pelo resgate de derrota (Continue Offer).
///
/// Fixo, e não escalado por alvo restante como o [kMovesPerTarget] do
/// reforço de saldo pre-churn: este convite só aparece uma vez, depois da
/// fase já ter sido perdida — não há mais "quanto falta" para escalar contra,
/// só a decisão de tentar mais cinco movimentos ou aceitar a derrota.
const int kContinueBonusMoves = 5;

/// Preço em moedas do resgate de derrota, quando o jogador não quer assistir
/// ao vídeo. Mesmo preço do Martelo — mesma ordem de grandeza de "um item
/// avulso caro".
const int kContinueCoinPrice = 100;

/// Teto de estoque de cada booster (Martelo, Bomba, Pincel) para prêmios
/// gratuitos — roleta e recompensa diária.
///
/// Sem teto, a roleta diária acumularia booster indefinidamente e o jogador
/// chegaria às fases hard com uma pilha que dispensa jogar. Compra e anúncio
/// dentro da partida não passam por aqui: ali o jogador pediu o item
/// naquele instante, e recusar a entrega seria cobrar sem pagar.
const int kMaxBoosterStock = 5;

/// Moedas pagas por unidade de booster que não coube no [kMaxBoosterStock].
///
/// Metade do preço do Martelo: o prêmio não some (um giro que "não paga"
/// ensina a não girar), mas vale menos do que o item que o jogador já tem
/// de sobra.
const int kCoinsPerOverflowBooster = 50;

/// Resultado de creditar um prêmio de booster respeitando o teto.
typedef BoosterCredit = ({int count, int overflowCoins});

/// Credita [amount] unidades sobre [current] até [kMaxBoosterStock]; o que
/// sobra vira moeda.
///
/// Estoque acima do teto (salvo antes de o teto existir) não é cortado — tirar
/// item que o jogador já tinha seria pior do que o problema que o teto
/// resolve. Ele só não cresce mais por prêmio.
BoosterCredit capBoosterReward({required int current, required int amount}) {
  final room = (kMaxBoosterStock - current).clamp(0, amount);
  return (
    count: current + room,
    overflowCoins: (amount - room) * kCoinsPerOverflowBooster,
  );
}

/// Quantos Martelos o jogador pode ganhar **por vídeo** num mesmo dia (data
/// local).
///
/// Regra de monetização: sem teto, o anúncio premiado vira a fonte infinita do
/// item e esvazia a economia interna — a moeda e a roleta deixam de importar.
/// A compra com moeda não passa por aqui: quem paga com o que juntou jogando
/// não está drenando nada.
const int kMaxHammerAdsPerDay = 3;
