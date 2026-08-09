# Internacionalização (pt/en) — NineFuse

Data: 2026-08-08

## Objetivo

Suportar português e inglês, com inglês como idioma padrão (fallback), sem
seletor manual: o idioma vem do sistema.

## Mecanismo: `flutter_localizations` + `gen-l10n`

Escolhido sobre `easy_localization` e sobre um mapa em Dart puro porque as
chaves viram getters tipados: chave inexistente é erro de compilação, não
texto sumido na tela do jogador. O projeto já prefere invariantes que o
compilador ou o teste pegam (`assert` de `kSpawnWidth`, `LossReason` em vez
de deduzir pelo saldo). Também não acrescenta dependência de terceiro.

Arquivos: `l10n.yaml`, `lib/l10n/app_en.arb` (template, é o fallback) e
`lib/l10n/app_pt.arb`.

## O domínio não importa l10n

`AppLocalizations` exige `BuildContext`, e a camada `domain` é testada sem
árvore de widgets. O domínio expõe dado estruturado; a apresentação formata.

| antes (domain) | depois |
|---|---|
| `Objective.description` | some; UI usa `digit`/`count` com plural ICU |
| `GameLevel.teaches` (frase) | `LevelTip?` (enum), traduzido na apresentação |
| `CampaignChapter.title`/`label` | `ChapterName` (enum); `label` sai do domínio |
| `EndlessProgression` rótulo de faixa | UI monta de `spawnMinFor`/`spawnMaxFor` |

`toString()` de debug e mensagens de `debugPrint` ficam em português: não são
texto de jogador.

## Resolução de locale

`supportedLocales: [en, pt]`, com `en` primeiro. O algoritmo padrão do Flutter
resolve `pt_BR` → `pt` e qualquer desconhecido → `en`, então não há
`localeResolutionCallback`. Título via `onGenerateTitle`.

Plural em ICU (`{count, plural, ...}`) — concatenação quebraria em inglês.

## Testes

- Helper `pumpLocalized` embrulha o widget num `MaterialApp` com os delegates.
- Os testes existentes passam a fixar `pt` explicitamente: as asserções em
  português continuam sendo regressão real, em vez de depender do locale da
  máquina de CI.
- Testes novos sob `en` para as telas com texto.
- Dois testes leem os próprios ARB: os dois arquivos têm o mesmo conjunto de
  chaves, e nenhum valor é vazio. Chave faltando em `pt` cairia em silêncio no
  inglês em produção — é o que garante "nenhuma string quebrada ou nula".
- Os goldens fixam `pt`; a arte não muda, não precisam ser regravados.

## Mudança de UI incluída

`chapterComingSoon` ("Capítulo 2: Em Breve!" / "Chapter 2: Coming Soon!") não
existia no código. Passa a ser exibida sobre os nós projetados do mapa, que
hoje são só cadeados decorativos.
