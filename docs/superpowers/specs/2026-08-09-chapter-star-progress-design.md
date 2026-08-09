# Barra de estrelas do capítulo no cartão de vitória

Data: 2026-08-09

## Problema

`CampaignChapter.starTotal` e `CampaignRecords.starsInChapter` existem no código
e **nenhum caminho de produção os usa** — só testes. Foram escritos para uma
leitura por capítulo que ficou no meio do caminho, e o CLAUDE.md registra isso
como ponta solta na seção "23/30 ao lado de Capítulo 2".

Do lado do jogador, o cartão de fim de fase premia a partida (três estrelas) e
não diz nada sobre o acumulado. A maestria por capítulo é o motivo de rejogar
uma fase já vencida, e hoje ela é invisível no momento exato em que o jogador
está olhando para a nota que acabou de tirar.

## O que será construído

Uma barra de progresso de estrelas do capítulo no ramo de **vitória** do cartão
de fim de fase, preenchendo-se do valor anterior até o novo.

Fora de escopo, de propósito: o modal de game over do Modo Recorde, o
`RetentionManager` (`consecutiveDays`, `totalNinesCreated`) e o gradiente
dourado no botão primário. São outros trabalhos.

## Arquitetura

### 1. `CampaignRecords.record()` devolve o ganho

Assinatura passa de `void` para `int`, retornando `max(0, novas - anteriores)`.

O motivo é que **não existe "antes" no momento em que o cartão renderiza**:
`record()` é chamado no `ref.listen` de `game_screen.dart`, no instante da
vitória, antes de o cartão ser construído. Quando a barra desenha,
`starsInChapter` já inclui as estrelas novas.

E o ganho não é dedutível do resultado da partida. O merge guarda o melhor de
cada grandeza, então rejogar uma fase com nota igual ou pior ganha **zero**
estrela de capítulo mesmo tirando três — só o notifier enxerga os dois lados da
conta. Devolver o delta de lá mantém a regra testável sem árvore de widgets.

### 2. `presentation/widgets/victory_dialog.dart` — `ChapterStarProgress`

Widget novo, único no arquivo, sem Riverpod:

```dart
ChapterStarProgress({
  required CampaignChapter chapter,
  required int starsInChapter, // total, já incluindo o ganho
  required int starsGained,    // quanto acabou de entrar
})
```

Desenha:

- o título do capítulo, via `chapterTitle(chapter)` de `l10n_labels.dart`, que
  já existe e já é traduzido;
- a trilha, com `TweenAnimationBuilder` indo de
  `(starsInChapter - starsGained) / chapter.starTotal` até
  `starsInChapter / chapter.starTotal`;
- o indicador `12/18` com o ícone de estrela.

Arquivo separado, e não mais um trecho de `level_outcome_card.dart`: aquele já
tem 435 linhas com estrelas, confetes e botões. O nome `victory_dialog.dart`
descreve o que o widget é — uma barra de capítulo só faz sentido na vitória —
sem renomear `LevelOutcomeCard`, que anuncia também "TABULEIRO TRAVADO" e
"MOVIMENTOS ESGOTADOS".

Três regras do projeto que se aplicam aqui:

- **A animação toca uma vez e para.** Repetição deixa `pumpAndSettle` sem fim e
  derruba a suíte de widget — a mesma armadilha já registrada no brilho da dica,
  no pulso do mapa e no selo do maior bloco.
- **`FractionallySizedBox` precisa de `heightFactor: 1`.** Sem ele um
  `DecoratedBox` sem filho colapsa para altura zero e a barra some, como
  aconteceu com a barra do objetivo no HUD.
- **`Semantics` do par número/total leva `excludeSemantics: true`.** Sem isso o
  leitor de tela anuncia a frase e depois "12/18" solto, defeito já corrigido no
  cabeçalho do mapa.

### 3. Ligação

`LevelOutcomeCard` ganha dois parâmetros **opcionais**, `starsInChapter` e
`starsGained`; o capítulo sai de `chapterOf(state.level.number)`. Opcionais
porque obrigatórios quebrariam a compilação de seis arquivos de teste que
constroem o cartão diretamente. Nulos, a barra não é desenhada.

`game_screen.dart` guarda o retorno de `record()` num campo do `State` e passa
os dois valores adiante. O cartão segue `StatelessWidget` sem acesso a provider,
que é o que permite testá-lo sem `ProviderScope`.

**Posição:** abaixo das estrelas da fase, acima do placar. A ordem vai do
imediato (o que esta partida rendeu) para o acumulado (o que o capítulo já tem),
e não empurra "PRÓXIMA FASE" para fora da dobra.

### 4. Textos

Chave nova no ARB para o rótulo semântico do par estrelas/total do capítulo, em
`app_en.arb` (template) e `app_pt.arb`. O template é o inglês porque é o
fallback: uma chave que exista só em português apareceria em português para
jogador de qualquer país.

## Testes

- `campaign_records_test.dart`: o retorno de `record()` — primeira vitória
  devolve as estrelas todas; rejogar melhor devolve só a diferença; rejogar
  igual ou pior devolve zero.
- `victory_dialog_test.dart` (novo): renderiza o título do capítulo e `12/18`; a
  barra parte da fração antiga e chega na nova, avançando o relógio à mão, sem
  `pumpAndSettle`.
- `level_outcome_card_test.dart`: com os parâmetros, a barra aparece; sem eles,
  não aparece.
- `english_screens_test.dart`: o par de asserções da chave nova — o texto inglês
  aparece **e** o português não.
- `hud_golden_test.dart`: o cartão passa a ser construído com os parâmetros, e
  `goldens/level_outcome.png` é **regravado**, conferindo o `isolatedDiff` antes
  de aceitar. Altura, degradê e espaçamento da barra são exatamente o que só
  golden pega.

## Registros

O parágrafo da ponta solta em "23/30 ao lado de Capítulo 2" sai do CLAUDE.md,
substituído pela descrição do que passou a usar os dois campos.

## Validação

`flutter analyze` e `flutter test` com aprovação integral.

## Nota

O diretório não é um repositório git, então este documento não pôde ser
commitado.
