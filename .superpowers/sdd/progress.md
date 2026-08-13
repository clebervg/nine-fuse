# Economia de moedas — progresso

Plano: docs/superpowers/plans/2026-08-12-economia-de-moedas.md
Spec: docs/superpowers/specs/2026-08-12-economia-de-moedas-e-polimento-aaa-design.md
Branch: feat/economia-de-moedas
Base: c446730 (camada de monetização com AdMob)

## Tarefas
- [x] 1 Persistência de moedas e baús reclamados — completa (commit 4367470, revisão limpa)
- [x] 2 Wallet (estado + notifier + provider) — completa (commit b2d7878, revisão limpa)
- [x] 3 Torneira: estrelas novas creditam moedas — completa (commit fd0bf24, revisão: 1 achado Menor)
- [x] 4 Ralo: comprar martelo com moedas — completa (commit 6ff28a1, revisão: 2 achados Menores)
- [x] 5 Reconciliar a carteira ao voltar ao mapa — completa (commit 1b20dad, revisão limpa)
- [x] 6 Fechamento (analyze, suíte, CLAUDE.md) — completa (commit c3faf2a, revisão limpa)

## Achados menores (para a revisão final triar)
- Menor (rev. T3): nenhum teste exercita a **fiação** em `game_screen.dart` — os
  4 testes da torneira compõem `record()` + `creditCoins()` fora da tela. Um erro
  de fiação (chamada fora da guarda de transição, por exemplo) não seria pego.
  Risco baixo: o código novo são duas linhas dentro da guarda `!won -> won` que
  já protegia `record()`, e a regra de verdade está coberta. A revisão final
  decide se vale um teste de widget.

## Notas de execução
- Estado antes da branch: 641 testes passando. Depois da Task 1: 644.
- Este arquivo é **rastreado no git** apesar do `.gitignore` local. Um subagente
  rodou `git reset` durante a Task 1 e o reverteu para o conteúdo do plano
  anterior. Por isso ele é commitado a cada task, e não deixado sujo.
- Dois subagentes implementadores abandonaram a Task 1 pela metade, retornando
  "vou aguardar a tarefa em segundo plano" sem ter terminado. O remédio que
  funcionou foi instruir explicitamente: não disparar comandos em segundo plano
  nem criar subtarefas; trabalhar em primeiro plano.
- Menor (rev. T4): `_buy()` checa `_waiting`, mas nunca o **liga** — só `_watch()`
  liga. Dois toques na compra processados antes do rebuild que reavalia
  `canAfford` debitariam duas vezes. O Flutter serializa toques em uso normal e
  `spendCoins` é síncrono, então é risco teórico; o caso ruim seria comprar dois
  martelos com saldo para um. Sem teste cobrindo.
- Menor (rev. T4): não há teste isolado do `GameButton` desabilitado (que ele não
  afunda ao toque). O efeito que importa está coberto de fora, pelo teste de
  saldo curto.

## Revisão final (opus): PRONTO PARA INTEGRAR
Nenhum achado Crítico ou Importante. Reparos aplicados em b5afc81:
- Reentrância na compra: `_buy()` checava `_waiting` mas nunca o ligava. O dano
  real não era saldo negativo (o revisor corrigiu a caracterização deste ledger):
  `spendCoins` checa `canAfford` contra o estado já debitado. Era cobrar 200 por
  2 martelos quando o jogador pediu 1 — e o segundo nem tem alvo, porque o
  primeiro golpe já limpou o `pendingTarget`. Vira estoque pago que ninguém quis.
- Ordem de gravação de `claimChapterChest`: baú antes da moeda. Se só uma
  gravação sobrevive a uma falha, o pior caso passa a ser "perdeu o prêmio" em
  vez de "o baú repaga toda sessão".
- CLAUDE.md: a frase dos "três gestos" descrevia o que o código não faz (só
  `onTapDown` checa; com `_pressed` já falso, up e cancel são no-op).
- CLAUDE.md: registrado que `refreshHammers` continua lendo o disco em vez de
  reconciliar contra o Wallet, contrariando o spec — e por que está certo.

E um defeito introduzido pelo próprio reparo, corrigido em ebedd1e:
- `_buy()` retornava com `_waiting` ligado quando `spendCoins` falhava. Como
  `_watch()` também começa com `if (_waiting) return;`, o convite inteiro
  congelava: nem comprar, nem assistir, só recusar.

Estado verificado pelo controlador: flutter analyze limpo, 662/662 testes
(eram 641 quando a branch começou).

## Dívida registrada, fora desta branch
- **Obrigatório antes da UI do baú (Fase B):** nada mais — a ordem de gravação
  já foi corrigida aqui.
- Sem teste da fiação da torneira em `game_screen.dart` (a regra tem 4 testes, e
  a guarda de transição `!won -> won` é a mesma que já protegia `record()`).
- Sem teste isolado do `GameButton` desabilitado; o efeito está coberto de fora.
- Os quatro `_BrokenStorage` duplicados pelos arquivos de teste — padrão
  pré-existente, agravado por esta branch. Um fake compartilhado pagaria no
  próximo método de `GameStorage`.
- Corrida teórica: `CampaignRecords._load()` é assíncrono, e uma vitória
  registrada antes de o disco responder pagaria estrelas já conquistadas. Exige
  vencer uma fase antes do SharedPreferences responder — inalcançável na
  prática, mas agora tem consequência monetária, e antes não tinha.
