# Economia de moedas e polimento AAA do menu

Data: 2026-08-12

## Relação com o spec de 2026-08-11

Este documento **estende** `2026-08-11-menu-e-appicon-design.md`, que projetou o
AppIcon e o redesign do menu em detalhe e **nunca foi implementado** — o commit
`468e1b6` gravou o documento, não o código. Todo aquele desenho continua valendo
e é insumo direto do plano, com **uma decisão sobrescrita**:

> **Sobrescreve "Sem moedas".** Aquele spec decidiu não pintar contador de moedas
> porque não havia economia que o alimentasse — raciocínio correto, e a conclusão
> a que ele chegou (`UserResourcesBar` só com martelo) era a certa *enquanto a
> premissa valia*. A premissa deixou de valer: a economia foi aprovada e entra
> aqui. A `UserResourcesBar` nasce com moeda **e** martelo.

O que aquele spec já resolve e não se repete aqui: forma do `9` no SVG, filtro de
glow, composição do anel, gradiente de fundo, grade fosca, badge de estrelas,
pílula do Endless e as três camadas da trilha.

## Estado real do código, medido

O segundo pedido descreve a tela de gameplay como se ela precisasse de trabalho.
Não precisa — os três itens já estão no código:

| Pedido | Onde já está |
|---|---|
| `SizedBox(height: 12)` entre booster e grid | `game_screen.dart:208` |
| Mira com `BackdropFilter` 3px + scrim 60% + aro neon | `hammer_targeting_layer.dart`, `kHammerScrimOpacity = 0.6`, dentro de `ClipRect` |
| Cards do header com gradiente, canto 16 e fio de luz | `game_metric_card.dart:67-80` |

**Nada da Fase 1 do pedido de gameplay entra no plano.** Reimplementar o que
existe produziria diff sem mudança de comportamento e arriscaria regressão nos
goldens por nada.

**O `ObstacleOverlay` não é tocado.** O pedido descreve "dígitos com opacidade
acinzentada ou traços nas células" como defeito de renderização a eliminar. É a
cobertura de obstáculo funcionando: gelo pinta véu azul translúcido com faixa
diagonal clara, vidro pinta uma faceta diagonal. Já está registrado no
`CLAUDE.md` como falso-positivo de um red team anterior. A translucidez é a razão
de ser da cobertura — o dígito por baixo tem de continuar legível, senão o
obstáculo é só um buraco no tabuleiro. Chapar aquelas células apagaria a mecânica
inteira. Se a leitura de "peça quebrada" persistir com jogadores reais, o remédio
é reforçar o contorno da cobertura, não remover o alfa.

## Fase A — Economia de moedas

### Constantes (`domain/economy.dart`, arquivo novo)

`kCoinsPerStar = 10`, `kHammerCoinPrice = 100`, `kChapterChestReward = 200`.
Nomeadas para a recalibragem não virar caça a número mágico. Com 30 estrelas na
campanha e dois baús, o teto é 300 + 400 = 700 moedas = 7 martelos para quem
zerar tudo com três estrelas. Escasso o bastante para o anúncio recompensado
continuar sendo o caminho principal de aquisição.

### Onde mora o saldo

Esta é a parte que estica uma decisão registrada do projeto, e por isso é a
primeira a ser implementada e revisada.

O `CLAUDE.md` registra que o estoque de martelos mora no `GameState` de
propósito: *"a UI lê o saldo do mesmo lugar de onde a regra o consome; duas
fontes de verdade divergiriam no primeiro anúncio assistido"*. O mapa da saga
**não tem `GameState`** — vive fora de qualquer fase —, então a barra de recursos
não alcança nem moeda nem martelo pelo caminho atual. O spec anterior já havia
chegado nesse mesmo impasse e proposto um `hammerInventoryProvider`.

Solução adotada: **`walletProvider`, dono único da leitura de disco** para moedas
e martelos, expondo `refresh()`. O `GameState.hammerCount` continua existindo e
continua sendo de onde a regra consome durante a fase; o que muda é que
`refreshHammers` passa a reconciliar contra o wallet em vez de ir ao disco
sozinho. Não são duas fontes de verdade: é uma fonte (o wallet) e um cache de
fase que já era relido a cada `startLevel`.

A regra de falha de leitura não muda — **falha vale como saldo vazio**. Perder o
saldo é ruim; travar o jogo é pior.

### Persistência (`GameStorage`)

Duas chaves novas: `wallet_coins` (int) e `campaign_chests_claimed` (lista de
números de capítulo). O `FakeGameStorage` ganha os mesmos campos.

### Torneira

`campaign_records.record()` já devolve `gained` — as estrelas **novas**, com as
que o jogador já tinha descontadas (`campaign_records.dart:66`). No caminho de
vitória, credita `gained * kCoinsPerStar`.

O desconto é o que impede o abuso óbvio: refazer a fase 1 repetidamente não
farma, porque a segunda vitória com as mesmas três estrelas tem `gained == 0`.
Nenhuma regra anti-farm nova precisa existir.

### Ralo

O `HammerOfferDialog` ganha uma segunda ação ao lado do botão de anúncio:
**"Comprar 🪙 100"**, desabilitada com saldo insuficiente. A compra debita o
saldo e credita um martelo na mesma transação.

Reusa o funil inteiro, incluindo o Modo Fantasma: quem entrou em mira com estoque
zero e escolheu o alvo agora tem dois caminhos para o mesmo golpe, e o alvo
guardado vale para os dois.

### Baú de fim de capítulo

O nó no fim da trilha mostra cadeado e o prêmio. Ao fechar todas as fases do
capítulo ele destranca; o toque anima a abertura e credita `kChapterChestReward`
**uma única vez**, com o capítulo pago persistido em `campaign_chests_claimed`.
Sem a persistência ele repagaria a cada visita ao mapa.

**Um baú só, no fim da trilha.** Um baú após a fase 6 exigiria abrir espaço no
meio da `SagaGeometry`, o que é reestruturação de trilha e não polimento. Fica
registrado como possível depois.

### Testes da Fase A

- Vencer de novo a mesma fase com as mesmas estrelas não credita moeda.
- Vencer com estrela a mais credita só a diferença.
- Compra com saldo curto não debita nem credita martelo.
- Compra com saldo suficiente debita exatamente o preço e credita um martelo.
- Baú reclamado duas vezes credita uma.
- Leitura de disco que falha deixa o saldo em zero em vez de propagar exceção.

## Fase B — UI

Depende da Fase A: a barra lê saldo real, sem dublê intermediário.

1. **`UserResourcesBar`** — 🪙 N e 🔨 N, lendo do `walletProvider`. O botão `+`
   fica **só no martelo** e abre o `HammerOfferDialog`. Moeda é status puro: não
   há atalho que gere moeda, e um `+` que não leva a lugar nenhum reproduz
   exatamente o contador inútil de que a decisão anterior fugia.
2. **Pílula do Endless**, fundo com gradiente e grade, badge de estrelas e as
   três camadas da trilha — conforme as seções 2 a 5 do spec de 2026-08-11, sem
   alteração. Gradiente `#0B0813 → #161129`, o valor daquele spec; o segundo
   pedido trazia `#0D0B18 → #1A152E`, e a diferença entre os dois é
   imperceptível ao lado do custo de divergir de um desenho já fechado.
3. **Nó de baú** substituindo o rótulo "Capítulo N: Em Breve!"
   (`saga_map.dart:211`). O texto localizado `chapterComingSoon` sai do uso; o
   estado travado passa a ser comunicado pelo cadeado e pelo prêmio visível.
4. **AppIcon** conforme a seção 1 do spec de 2026-08-11: correção da forma do
   `9`, anel como moldura externa, filtro `nine-glow`. Regeneração por
   `rsvg-convert -w 1024 -h 1024` seguida de `dart run flutter_launcher_icons`.
   O `pubspec` não muda — `image_path` e `adaptive_icon_foreground` seguem
   apontando para `assets/images/logo.png`.

### Partículas do fundo

O segundo pedido pede "suave transparência de partículas". Elas são **estáticas,
com semente fixa**, pintadas junto com a grade fosca e dentro do mesmo
`IgnorePointer`.

Nunca animadas em repetição. É a armadilha já registrada duas vezes no projeto:
animação infinita faz `pumpAndSettle` nunca terminar e derruba a suíte de widget
inteira — a mesma razão pela qual o aro da mira dá duas batidas e descansa, e
pela qual as trincas dos obstáculos têm semente fixa.

## Verificação

- `flutter analyze` sem achados.
- `flutter test` — atenção a `level_select_screen_test.dart`, `saga_map_test.dart`,
  `saga_map_pulse_test.dart`, `hammer_booster_test.dart` e
  `l10n/english_screens_test.dart`.
- **`test/features/game/presentation/goldens/saga_map.png` será regenerado**: o
  fundo, o header e a trilha mudam de propósito. A imagem nova é revisada a olho
  antes de ser aceita, não aprovada no escuro.
- Overflow: teste de widget montando o mapa em 320×568 (menor que o iPhone SE) e
  em 430×932 (Pro Max), afirmando ausência de overflow nos dois.
- Textos novos entram em `app_pt.arb` e `app_en.arb` juntos — o teste de telas em
  inglês pega o que faltar.
