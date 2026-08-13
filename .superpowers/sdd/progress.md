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
- [ ] 5 Reconciliar a carteira ao voltar ao mapa
- [ ] 6 Fechamento (analyze, suíte, CLAUDE.md)

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
