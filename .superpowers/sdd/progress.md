# Refresh de identidade visual — progresso

Plano: docs/superpowers/plans/2026-08-25-brand-refresh.md
Spec: docs/superpowers/specs/2026-08-25-brand-refresh-design.md
Worktree: /Users/cleber/projects/nine_fuse/.worktrees/brand-refresh
Branch: brand-refresh
Base: ce3154e

Baseline: `flutter test` completo — 760 testes passando.

## Tarefas
- [x] 1 Script de exportação do glifo "9" da fonte — completa (commit ce3154e..c59441e, revisão aprovada). O grosso do código já existia desde o commit do plano (67b3052); esta task só corrigiu um trecho impreciso da docstring.
- [x] 2 Novo `assets/images/logo.svg` vetorial — completa (commit c59441e..3e22e3e, revisão aprovada, sem achados)
- [x] 3 Regenerar ícones e splash a partir do novo SVG — completa (commit c59441e..b1275d5, revisão aprovada). Achado real no meio do caminho: `logo_splash.png` nunca foi automatizado pelo pipeline (recorte manual antigo); com aprovação do usuário, `tool/prepare_icons.dart` passou a gerá-lo também (render do grupo `mark`, sem o inset de 66% da máscara do ícone).
- [x] 4 Wordmark "NineFuse" em relevo na SplashScreen — completa (commit b1275d5..6708faa, revisão aprovada). Verificação visual feita pelo controlador via golden descartável (fora do commit): confirma divisão de cor Nine/Fuse e sombra desenhada corretas; fonte não shapeia em headless test, limitação do ambiente, não bug.
- [x] 5 Verificação final — completa (commit 6708faa..82c6da9, revisão aprovada). `flutter analyze` achou 1 `info` pré-existente (tool_tmp/probe124.dart, commit ff10aab, anterior à base do worktree) — confirmado fora de escopo, registrado no CLAUDE.md, não corrigido.

Todas as 5 tasks do plano completas.

## Revisão final da branch (ce3154e..82c6da9)

Achados Important: 2 comentários obsoletos (`flutter_launcher_icons.yaml`,
`tool/prepare_icons.dart`) e 1 achado real confirmado visualmente pelo
coordenador — a splash do Android 12 usava a mesma arte cheia da splash legada
(70% do canvas) sem o recorte pela zona de segurança circular de 66%, cortando
os cantos do selo sob a máscara circular do Android 12+.

Fix (commit 39d4691): comentários corrigidos; `android_12.image` passou a
apontar para `assets/icon/app_icon_foreground.png` (o mesmo render já recortado
pela zona segura, reaproveitado — nenhum arquivo novo). Re-revisão confirmou
numericamente: `app_icon_foreground.png` tem raio máximo 0.660 do meio-lado
(exatamente dentro do círculo de 66%), contra 0.862 do `logo_splash.png` antigo
(seria cortado). **Ready to merge: Yes.** Achado menor remanescente, não
bloqueante: `flutter_launcher_icons.yaml` ainda descreve a cor de fundo como
"stop externo do gradiente", mas o fundo do SVG atual é `<rect>` chapado — vale
corrigir numa próxima passada, não nesta branch.

Próximo passo: `superpowers:finishing-a-development-branch`.

## Notas de execução
- Ledger anterior deste arquivo (Bloco 9/Super 9, já mergeado) sobrescrito para
  começar este trabalho do zero — histórico completo preservado em `git log`.
- Trabalhando em worktree isolado — não mergear/dar push sem autorização explícita.
