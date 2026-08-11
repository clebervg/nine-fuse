# Reformulação do AppIcon e redesign do menu (mapa da campanha)

Data: 2026-08-11

## Objetivo

Duas frentes independentes que compartilham a mesma queixa — o jogo não se
apresenta bem antes de o jogador tocar no tabuleiro:

1. O ícone do app tem margem interna excessiva e desaparece em papel de parede
   escuro.
2. O mapa da campanha gasta ~190pt de altura em dois cartões empilhados antes de
   a trilha começar, e o fundo preto chapado não tem atmosfera nenhuma.

## Decisões de escopo tomadas antes de começar

**Sem moedas.** O pedido original pedia um contador de moedas no topo. O jogo
não tem moeda: não há campo em `GameState`, nem persistência, nem fonte de
ganho — apenas uma regra futura de AdMob registrada no `CLAUDE.md`. Um contador
travado em zero comunica menos do que a sua ausência, e é a mesma régua já
aplicada ao botão do martelo no HUD. A `UserResourcesBar` nasce mostrando só o
martelo, e abre espaço para a moeda quando existir economia que a alimente.

**O `9` do logo lê como `g`.** Descoberto ao renderizar as variantes: a perna do
glifo atual varre de cima-direita para baixo-esquerda, que é a cauda de um `g`,
não o descendente de um `9`. No tamanho atual passa como ambiguidade; ampliar
160% torna o erro inequívoco. Corrigir a forma não estava no pedido, mas escalar
sem corrigir só amplia o defeito — então a correção entra.

**Escalar só o símbolo central era geometricamente impossível.** O `9` a 160%
mede 352px de altura; o anel de fusão tem 290px de diâmetro. O símbolo
transbordaria o anel e desfaria a composição. O anel passa a moldura externa
(r=212, junto à borda) e o `9` domina o interior — as duas mudanças são uma só
decisão.

**As regras de AdMob ficam fora.** Preload, cap diário de martelo e intersticial
pós-vitória não são visual de menu, e o projeto não tem SDK de anúncio.

## 1. AppIcon

O SVG segue como fonte da verdade, como o `pubspec` documenta. `logo.svg` não é
renderizado em lugar nenhum do app (`grep` por `SvgPicture` em `lib/` volta
vazio) — é exclusivamente a origem do ícone, então a mudança não afeta nenhum
golden.

### Forma do `9`

`9` geométrico: bowl de r=92 centrado em (250,186), contra-forma de r=38 aberta
com `fill-rule="evenodd"`, e descendente reto de 50px de largura descendo pela
borda direita do bowl até y=424, com pé quase quadrado (r=10).

A proporção não é arbitrária. Duas tentativas descartadas, ambas verificadas
renderizando:

- Bowl grande (r=104) com descendente curto lê como **`q`** — o descendente
  parece uma perna solta em vez da continuação do bowl.
- Descendente com flexão para a esquerda no pé volta a ler como **`g`**, que é
  exatamente o defeito que se está corrigindo.

O que resolve é bowl compacto com descendente proporcionalmente longo, e a
contra-forma pequena o bastante para o traço do bowl ter peso.

### Composição

Anel de fusão em r=212 com traço de 18, próximo à borda, funcionando como
moldura em vez de contorno do símbolo. Três partículas nos cantos que a moldura
deixa livres. A margem interna some sem que nada essencial seja cortado pela
máscara circular do ícone adaptativo do Android — verificado renderizando cada
variante sob um recorte circular de 66%.

### Glow

Filtro novo, `nine-glow`, empilhando três efeitos:

1. `feMorphology` dilata o alfa do `9` em 6px.
2. `feGaussianBlur` + `feFlood` ciano compõem um halo colorido por fora da
   silhueta.
3. `feDropShadow` preto continua embaixo, dando assentamento.

Os dois últimos são complementares e nenhum é dispensável: o halo colorido é o
que salva o ícone em papel de parede **escuro** — o caso que o `drop-shadow`
atual não cobre, porque sombra sobre fundo escuro é invisível —, e a sombra é o
que salva em papel de parede **claro**. Um só dos dois falharia em metade dos
aparelhos.

### Regeneração

`rsvg-convert -w 1024 -h 1024` produz `logo.png`; `dart run
flutter_launcher_icons` produz os ícones nativos. O `pubspec` não muda:
`image_path` e `adaptive_icon_foreground` continuam apontando para o mesmo PNG,
já que a composição foi escolhida contra a máscara circular.

## 2. Fundo e atmosfera

`LevelSelectScreen` troca `backgroundColor: AppColors.darkBackground` por um
`Container` com gradiente vertical `#0B0813 → #161129`, e por cima um
`CustomPaint` de grade fosca — linhas a cada 32px em branco com alfa 0.022,
dentro de um `IgnorePointer`.

A grade é pintada atrás da rolagem e **fixa**. Rolando junto com a trilha ela
viraria movimento parasita competindo com o único elemento que deve puxar o olho,
que é o pin da fase da vez.

O `AppBar` passa a transparente com `elevation: 0`. Mantê-lo em
`AppColors.darkSurface` cortaria o gradiente em dois logo no topo.

## 3. Header

Três widgets no lugar do cartão único:

### `UserResourcesBar` (arquivo novo)

Ícone do martelo e a contagem, à esquerda. Lê de um `hammerInventoryProvider`
novo: um `StateNotifierProvider<int>` que lê `GameStorage.readHammerCount()` e
expõe `refresh()`.

O provider é necessário, não conveniência. `GameState.hammerCount` só é
carregado do disco em `startLevel` (via `HammerBooster.loadInventory`), então
ler `gameProvider` no mapa mostraria zero para quem tem martelos guardados. É o
mesmo padrão de `endlessHighScoreProvider`, que existe pela mesma razão. Falha
de leitura vale como estoque vazio, seguindo a regra já registrada para o
martelo.

### Badge de estrelas

O `_Stat` de estrelas sai da linha do capítulo e vira uma pílula
(`StadiumBorder`) com gradiente `#3A2E12 → #6B5416`, borda dourada
(`AppColors.digit3`) e um `BoxShadow` dourado difuso, à direita da barra de
recursos.

Mantém `totalStarsKey` e a semântica atual, incluindo a legenda "CAMPANHA" —
ela existe para desambiguar o contador da campanha inteira do nome do capítulo ao
lado, e o problema que ela resolve não desapareceu com a mudança de forma.

### `CampaignHeader`

Fica com o nome do capítulo e a barra de progresso de estrelas, sem o contador.

## 4. Endless como pílula

`EndlessHighlight` passa de cartão de duas linhas com `GameButton` para uma
pílula de altura fixa (56pt): troféu, `RECORDE · 1.240` e um chevron. Travado,
vira a mesma pílula fosca com cadeado e o texto de desbloqueio.

As três chaves de teste sobrevivem: `endlessCardKey`, `endlessRecordKey` e
`endlessCallToActionKey`. A última migra do `GameButton` para o chevron tocável,
porque é por ela que o teste abre o Endless — sem a migração, uma mudança de
layout quebraria um teste de regra e a falha diria a coisa errada sobre o que
mudou.

## 5. Trilha

`_PathPainter` passa a desenhar o trecho conquistado em três camadas sobrepostas,
no lugar do traço único:

1. Traço de 22px com o gradiente `digit2 → digit7` e `MaskFilter.blur` — o
   neon, a luz que sangra no fundo.
2. Traço de 14px com o mesmo gradiente, opaco — o corpo da linha.
3. Traço de 4px em branco com alfa 0.5 — o brilho central, que é o que faz a
   linha parecer energizada em vez de pintada.

O trecho bloqueado deixa de ser um traço sólido de alfa 0.07 e passa a
pontilhado fosco, reusando o `_drawDashed` que já existe, com alfa 0.09. Isso
unifica a gramática: travado e projetado passam a se ler igual, e **só o
conquistado é sólido**. O ganho é subtrativo — hoje o traço cinza sólido percorre
o mapa inteiro concorrendo com o colorido, e é ele que faz o caminho parecer
apagado.

`shouldRepaint` não muda: as três camadas derivam dos mesmos campos que já
estavam declarados.

## 6. Telas compactas

O topo cai de ~190pt para ~120pt, então a folga vem de graça. Ainda assim, as
guardas explícitas:

- `UserResourcesBar` usa `Row` com o badge em `Flexible`.
- O texto do recorde na pílula é `Expanded` com `TextOverflow.ellipsis`.
- Teste de widget novo em `level_select_screen_test.dart` monta a tela em
  320×568 e afirma ausência de overflow.

## Verificação

- `flutter test` — a suíte inteira, com atenção a
  `level_select_screen_test.dart`, `saga_map_test.dart`,
  `saga_map_pulse_test.dart` e `l10n/english_screens_test.dart`.
- `test/features/game/presentation/goldens/saga_map.png` precisa ser
  regenerado: a trilha e o fundo mudam de propósito.
- `flutter analyze` sem achados.
