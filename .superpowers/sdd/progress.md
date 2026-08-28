# Teto no baú de capítulo — progresso

Plano: docs/superpowers/plans/2026-08-28-chest-chapter-cap.md
Spec: docs/superpowers/specs/2026-08-28-chest-chapter-cap-design.md
Branch: main (direto, sem worktree — confirmado com o usuário)
Base: 9c9e1c3

## Tarefas
- [x] 1 Constante kChapterChestPayableCount — completa (commit 3362b8a..aa3cde0, revisão aprovada, sem achados)
- [x] 2 Guarda em claimChapterChest — completa (commit aa3cde0..ab5479a, revisão aprovada, sem achados; 787/787 na suíte completa)

Todas as 2 tasks do plano completas.

## Revisão final da branch (9c9e1c3..ab5479a)

Revisão final (Opus): sem achados Críticos/Importantes. 3 Minor:
- Guarda de `claimChapterChest` era de mão única (`chapter < 1` não travado).
- CLAUDE.md ainda descrevia o baú como dívida aberta, contradizendo o código.
- (Só observação, sem fix) `refresh()` adota o que vier do disco sem filtrar
  pelo teto — hoje inofensivo (jogo não lançado, sem capítulo >20 persistido
  em conta real), mas a premissa expira no primeiro lançamento.

Achados 1 e 2 corrigidos em commit 87061bb (12/12 em wallet_test.dart,
788/788 na suíte completa, analyzer limpo).

**Ready to merge: Yes.**

## Notas de execução
- Ledger anterior (Evento Nova, já mergeado) sobrescrito para começar este
  trabalho do zero — histórico completo preservado em `git log`.
