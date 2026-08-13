# Economia de moedas — progresso

Plano: docs/superpowers/plans/2026-08-12-economia-de-moedas.md
Spec: docs/superpowers/specs/2026-08-12-economia-de-moedas-e-polimento-aaa-design.md
Branch: feat/economia-de-moedas
Base: c446730 (camada de monetização com AdMob)

## Tarefas
- [x] 1 Persistência de moedas e baús reclamados — completa (commit 4367470, revisão limpa)
- [ ] 2 Wallet (estado + notifier + provider)
- [ ] 3 Torneira: estrelas novas creditam moedas
- [ ] 4 Ralo: comprar martelo com moedas
- [ ] 5 Reconciliar a carteira ao voltar ao mapa
- [ ] 6 Fechamento (analyze, suíte, CLAUDE.md)

## Achados menores (para a revisão final triar)
Nenhum até agora.

## Notas de execução
- Estado antes da branch: 641 testes passando. Depois da Task 1: 644.
- Este arquivo é **rastreado no git** apesar do `.gitignore` local. Um subagente
  rodou `git reset` durante a Task 1 e o reverteu para o conteúdo do plano
  anterior. Por isso ele é commitado a cada task, e não deixado sujo.
- Dois subagentes implementadores abandonaram a Task 1 pela metade, retornando
  "vou aguardar a tarefa em segundo plano" sem ter terminado. O remédio que
  funcionou foi instruir explicitamente: não disparar comandos em segundo plano
  nem criar subtarefas; trabalhar em primeiro plano.
