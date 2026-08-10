# Barra de estrelas do capítulo — progresso

Plano: docs/superpowers/plans/2026-08-09-chapter-star-progress.md
Branch: feat/chapter-star-progress
Base: 0dabefe (estado inicial sob controle de versão)

## Tarefas
- [x] 1 record() devolve o ganho — completa (commits 1607326..796aac8, revisão limpa)
- [x] 2 chave de tradução chapterStarsSemantics — completa (commit c6d1550, revisão limpa)
- [x] 3 widget ChapterStarProgress — completa (commit 54d956b, revisão limpa)
- [x] 4 LevelOutcomeCard desenha a barra — completa (commit bb03b9e, revisão limpa)
- [x] 5 GameScreen alimenta a barra — completa (commit 02d0454, revisão limpa)
- [x] 6 inglês, golden e CLAUDE.md — completa (commit a1e79af, revisão limpa)

## Achados menores (para a revisão final triar)
- Menor (rev. T4): `ChapterStarProgress` não tem assert de coerência — starsGained > starsInChapter, ou starsInChapter > starTotal, renderiza "23/18" em vez de falhar. Quem alimenta é a Task 5; RESOLVIDO na revisão da T5: nenhum caminho real produz esse estado (record() é capado por starRating e o consumo é condicionado a _won).

## Revisão final (opus): PRONTO PARA INTEGRAR
Achados reparados no commit 7908a52:
- Importante: o teste e2e usava a fase 43 (fora da campanha), então starsInChapter
  excluía a própria fase vencida e a barra saía "0/12" — e o teste só afirmava que
  a chave existia. Agora usa fase da campanha e afirma o texto; um segundo teste
  preserva "fase fora de capítulo não quebra a tela".
- Menor: o teste de cobertura dos capítulos usava o literal 10; agora percorre kCampaign.
- Menor: rótulo pt "estrelas no Capítulo 1" (era "em Capítulo 1").
- Menor: dupla leitura do provider — extraída CampaignRecords.starsInChapterOf.
- Menor: victory_dialog.dart renomeado para chapter_star_progress.dart (não continha
  nenhuma classe VictoryDialog).

Estado final verificado pelo controlador: flutter analyze limpo, 476/476 testes.

## PENDENTE, fora desta branch
O CLAUDE.md na árvore de trabalho foi truncado de 1409 para 78 linhas por edição
não commitada de outra sessão (trabalho de "Sistema de Obstáculos"). A versão
íntegra está no git em HEAD. A citação do caminho antigo victory_dialog.dart no
CLAUDE.md não pôde ser corrigida por isso.
