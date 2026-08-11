# Camada de Monetização (AdMob, Rewarded, Interstitial, No-Ads Pass) — Design

Data: 2026-08-11

## Objetivo

Dar ao NineFuse uma camada de monetização completa — anúncios recompensados,
intersticiais e um passe de remoção de anúncios — sem que nenhuma regra de
negócio dependa de um SDK que não roda em `flutter test`.

Hoje o jogo tem exatamente uma costura de anúncio: `hammerAdProvider`, um
`Provider<Future<bool> Function()>` cujo padrão **sempre paga** o jogador. O
CLAUDE.md já registra esse provider como "o ponto a trocar antes de monetizar de
verdade". Este design é essa troca, e mais quatro pontos como ele.

## Decisões que precedem o desenho

Quatro perguntas foram resolvidas antes de qualquer arquitetura:

**O alvo é domínio + adaptador real.** Não é um esqueleto: o
`google_mobile_ads` com UMP entra de fato, na última fatia.

**Os IDs de anúncio são os de teste do Google**, injetados por `--dart-define`
com o ID de teste como padrão. Trocar por IDs de produção é mudar o valor de uma
constante, não mexer em código.

**O Bônus Diário VIP paga em Martelos, não em moedas.** O pedido original falava
em "+50 Moedas/dia", mas o NineFuse não tem moedas — e o CLAUDE.md registra isso
como decisão de projeto, não como lacuna ("um botão desabilitado na tela comunica
menos do que sua ausência"). Criar uma carteira, uma loja e um preço de martelo
só para ter onde depositar o bônus VIP seria desenhar uma economia inteira como
efeito colateral de um passe. O passe credita **1 Martelo por dia**, usando o
inventário que já existe e que os dois modos já compartilham.

**O No-Ads Pass é uma flag persistida atrás de uma porta, sem SDK de IAP.**
`in_app_purchase` exige o produto criado no Play Console e na App Store Connect e
só se testa em build assinada — nada disso é verificável neste ambiente. A flag
`isNoAdsPurchased` e o `PurchasePort` stub entregam o comportamento hoje; o SDK
entra depois trocando o adaptador, sem tocar em nenhuma regra.

## Arquitetura

Uma feature nova, `lib/features/monetization/`:

```
domain/
  ad_placement.dart      // enum: preChurn, gameOver, hammerShop, levelComplete, exitToMap
  ad_gateway.dart        // porta: preload / showRewarded / showInterstitial -> AdOutcome
  analytics_port.dart    // porta: logEvent(name, params)
  ad_policy.dart         // ★ regras puras: sem SDK, sem Flutter, sem relógio real
providers/
  monetization_state.dart
  monetization_notifier.dart
data/
  admob_ad_gateway.dart  // google_mobile_ads + UMP
  debug_ad_gateway.dart  // paga sempre; padrão em teste e desktop
  purchase_port.dart     // stub hoje, in_app_purchase depois
```

**`AdPolicy` é o coração, e é puro.** Responde três perguntas —
`canShowInterstitial`, `shouldOfferPreChurn`, `canRewardHammer` — e nada mais.
Toda regra do pedido vive ali: os 45 segundos de flow state, o anti-churn de
derrota, o cooldown de partidas, o cap diário de martelos, a supressão por
No-Ads. O `now` entra como parâmetro; a política não lê relógio.

**Por que porta e não chamar o SDK direto do notifier.** `google_mobile_ads`
precisa de canal nativo e não roda em `flutter test`. Sem a porta, nenhuma das
regras acima seria testável — e são exatamente as regras onde um erro custa
receita (intersticial que nunca aparece) ou retenção (intersticial na cara do
jogador que acabou de perder). O `MonetizationNotifier` apenas orquestra:
consulta a política, chama o gateway, persiste, emite telemetria.

## Onde cada regra encosta no jogo existente

**Preload.** `startLevel` (campanha) e `startRun` (Endless) disparam
`gateway.preload()` em fire-and-forget; falha só loga. Nunca no `build` de um
widget.

**Pre-churn.** `GameState` já expõe `movesLeft`. Um `preChurnOfferProvider`
derivado (`movesLeft == 2 && objetivo não atingido && status == playing`)
alimenta uma **faixa discreta na HUD**, não um modal — modal no meio da partida é
a quebra de flow que o resto do projeto evita por princípio.

**Derrota.** O diálogo de game over ganha "+5 movimentos".
`GameNotifier.grantExtraMoves(5)` devolve a fase para `status: playing` **sem
regerar o tabuleiro** — o tabuleiro é o que o jogador estava resolvendo. Máximo
1 uso por partida, em `GameState.revivesUsed`.

**Martelo.** `hammerAdProvider` deixa de pagar sempre e passa a delegar ao
gateway, com o cap diário consultado **antes** de oferecer: um convite que o cap
vai recusar é pior do que convite nenhum.

**Intersticial.** Só em "Próxima Fase" e na saída para o Mapa, e só com a
política liberando. O caminho de derrota **não alcança** o gateway de
intersticial — a garantia é estrutural, não um `if` que alguém pode remover.

**Endless não tem "+5 movimentos".** A corrida não tem limite de movimentos; ela
acaba por `stuck`, sem jogadas válidas. Lá o recompensado natural é o Martelo,
que é justamente o que destrava um tabuleiro parado — como o CLAUDE.md já
registra ("No Endless o martelo compra outra coisa").

**Cooldown, fixado.** As duas guardas valem **juntas**: partida com menos de 45
segundos bloqueia, e menos de 3 partidas desde o último intersticial também
bloqueia. O pedido dizia "3 a 4 partidas"; o design fixa 3 numa constante
nomeada (`kInterstitialMatchCooldown`), porque uma faixa não é uma regra — alguém
teria de escolher o número na hora de escrever o `if`, e esse alguém não deve ser
o código.

## Estado persistido e a virada do dia

`MonetizationState` imutável, persistido em `GameStorage` — que já é a única
porta de disco do projeto; abrir uma segunda daria duas fontes de verdade sobre o
mesmo jogador.

| Campo | Serve para |
|---|---|
| `isNoAdsPurchased` | suprime intersticial, liga o VIP |
| `hammerAdsToday` + `hammerAdsDay` | cap de 3 martelos por dia |
| `vipBonusDay` | 1 martelo/dia do No-Ads Pass |
| `matchesSinceInterstitial` | cooldown de 3 partidas |
| `lastInterstitialAt` | cooldown de tempo e diagnóstico |

**A virada do dia é por data local, não por janela de 24h.** O dia é guardado
como `int` no formato `yyyymmdd`, e o contador zera quando o dia lido difere do
dia atual. Uma janela deslizante faria o jogador que joga toda noite às 21h
perder um dia inteiro de martelos por ter aberto o app dez minutos antes na
véspera. A regra tem de bater com o que ele chama de "hoje". O relógio entra como
`DateTime Function()` injetável — senão o teste do cap diário seria um teste que
espera a meia-noite.

**A duração da partida vem do notifier, não do gateway.** `startLevel` carimba um
`startedAt` e a política recebe a diferença já calculada. O gateway não deve
saber o que é uma partida.

## Telemetria

`AnalyticsPort.logEvent(name, params)`, com um `DebugAnalytics` que imprime como
padrão. Os quatro eventos pedidos:

- `ad_rewarded_offered` (com `trigger_location`: `pre_churn`, `game_over`, `hammer_shop`)
- `ad_rewarded_completed`
- `ad_interstitial_shown` (com o `AdPlacement`)
- `no_ads_pass_purchased`

Mais um quinto, `ad_rewarded_failed`. Sem ele, um *fill rate* ruim é
indistinguível de ninguém querer o anúncio — e essas duas causas pedem decisões
opostas.

**Sem Firebase nesta rodada.** A porta é a entrega; plugar `firebase_analytics`
depois é trocar um provider. Adicioná-lo agora pediria `google-services.json`,
configuração nativa nas duas plataformas e um projeto no console — nada
verificável neste ambiente, e um SDK que não posso rodar é um SDK que não posso
afirmar que funciona.

## Fatias de implementação

Cada fatia fecha com `flutter test` e `flutter analyze` verdes antes da próxima.
O teste da regra vem antes da regra.

1. **Portas + `AdPolicy` + persistência.** Testes puros: os 45 segundos, o
   cooldown de 3 partidas, a virada do dia no cap de martelos, a supressão por
   No-Ads. Nenhuma UI. É a fatia que carrega o risco todo.
2. **Rewarded.** Faixa de pre-churn na HUD; "+5 movimentos" na derrota com trava
   de 1 por partida; `hammerAdProvider` passando pelo cap. Testes de widget com
   gateway fake.
3. **Intersticial.** Gatilhos em "Próxima Fase" e saída para o Mapa, mais um
   teste de regressão afirmando que nenhum caminho de derrota alcança o
   intersticial.
4. **No-Ads Pass.** Flag, `PurchasePort` stub, bônus VIP de 1 martelo/dia.
5. **AdMob real.** `google_mobile_ads` + UMP, IDs de teste via `--dart-define`,
   configuração nativa Android/iOS.

**A fatia 5 não é verificável por teste automatizado aqui**, e será relatada como
tal em vez de declarada aprovada. Ela mexe em `android/app/build.gradle.kts`,
`AndroidManifest.xml` e `Info.plist`, onde uma quebra aparece longe da causa —
por isso vai por último e em commit isolado, para ser revertível sozinha.

## Fora de escopo, e registrado como pendência

Carteira de moedas, loja, `in_app_purchase` real, Firebase Analytics. Ficam
nomeados no CLAUDE.md do mesmo jeito que `hammerAdProvider` está hoje: uma
pendência escrita é uma decisão; uma pendência esquecida é um bug.
