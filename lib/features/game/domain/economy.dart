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
const int kCoinsPerStar = 10;

/// Preço de um Martelo de Fusão em moedas.
///
/// Deliberadamente caro: a campanha inteira com três estrelas em tudo rende 300
/// moedas, mais 200 por baú de capítulo. O anúncio recompensado continua sendo o
/// caminho principal de aquisição — a moeda é o consolo de quem não quer vê-lo,
/// não um substituto.
const int kHammerCoinPrice = 100;

/// O que o baú de fim de capítulo paga, uma única vez por capítulo.
const int kChapterChestReward = 200;

/// Moedas por anúncio premiado assistido até o fim.
///
/// Vinte e cinco é um quarto do martelo: quatro vídeos compram o item que um
/// vídeo já daria direto. É de propósito — o vídeo que paga o martelo continua
/// sendo o caminho curto, e este é a torneira de quem prefere juntar. Um valor
/// alto demais aqui esvaziaria o funil do martelo; um valor baixo demais faria
/// o botão parecer enfeite.
const int kCoinsPerRewardedAd = 25;
