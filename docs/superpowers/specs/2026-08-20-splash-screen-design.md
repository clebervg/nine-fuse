# Splash Screen Animada — Design

Data: 2026-08-20

## Contexto

O app hoje já tem uma splash **nativa** estática (`flutter_native_splash`,
mantida via `FlutterNativeSplash.preserve`/`.remove` em `main.dart`) que cobre
o tempo de boot do engine antes do primeiro frame Flutter. Ela permanece
intacta — este trabalho não a toca.

O pedido é uma splash **animada em Flutter**, exibida entre o fim da nativa e
a tela de seleção de fase (`LevelSelectScreen`), usando staging (animação em
etapas) para transmitir polimento em vez de travamento.

## Decisões

- **Identidade visual**: reaproveita o ícone já existente do app (a peça 9
  dourada, `assets/images/logo.png`), não o "9F" glassmorphism sugerido no
  briefing original — mantém consistência com o ícone do app já calibrado.
- **Posição no fluxo**: tela extra em Flutter, depois da splash nativa e antes
  de `LevelSelectScreen`. Não substitui nem reduz a nativa.
- **Estágio "power up"**: como não há card de vidro nem texto "9F" para
  piscar, o efeito liga/desliga é feito pulsando o glow (sombra dourada) atrás
  do logo.
- **Texto**: inclui o nome "NineFuse" abaixo do logo, com fade-in.
- **Sem partículas de fundo**: custo de performance/teste desproporcional ao
  ganho numa tela de ~1.8s.

## Componente

Arquivo novo: `lib/features/game/presentation/screens/splash_screen.dart`.

`SplashScreen` é um `StatefulWidget` com um único `AnimationController`
(duração ~1800ms) e um `VoidCallback? onSplashComplete` opcional (default:
`Navigator.of(context).pushReplacement` para `LevelSelectScreen`, com a
transição padrão do Flutter — o próprio fade-out do conteúdo da splash já
revela a tela por trás sem corte seco).

`main.dart`: `MaterialApp.home` passa a ser `const SplashScreen()` em vez de
`const LevelSelectScreen()`.

### Camadas (trás para frente)

1. Fundo: gradiente radial estático em tons de `AppColors.darkBackground` /
   `darkSurface`.
2. Anéis de energia: 2 anéis (`CustomPaint` ou `Container` com borda em
   gradiente), cores `AppColors.digit5` (roxo) e `AppColors.digit4` (laranja),
   girando com rotação decelerando ao longo da timeline — animação de
   duração **finita**, presa à janela da splash (não em loop infinito, para
   não travar `pumpAndSettle` em teste — convenção já registrada no projeto
   para o aro de mira do martelo e o pulso do dígito 9).
3. Logo: `Image.asset('assets/images/logo.png')`, `Transform.scale` +
   `Opacity` dirigidos pela timeline.
4. Glow: sombra dourada (`AppColors.digit9`) atrás do logo, com opacidade que
   pisca 2x rápido e assenta acesa.
5. Texto "NineFuse", fonte `AppFonts.display`, fade-in.
6. Barra de progresso fina no rodapé, preenchendo durante o estágio "idle".

### Timeline (frações do controller de 1800ms)

| Intervalo       | Estágio      | O que acontece |
|-----------------|--------------|-----------------|
| 0.0 – 0.22 (0–400ms)   | Entrance   | Logo: scale 0.7→1.0 + fade-in, `Curves.easeOut`. |
| 0.22 – 0.44 (400–800ms) | Power Up   | Anéis giram e desaceleram; glow pisca 2x e assenta aceso; texto "NineFuse" faz fade-in. |
| 0.44 – 0.78 (800–1400ms) | Idle Pulse | Shimmer diagonal cruza o logo (`ShaderMask`/gradiente animado); barra de progresso preenche 0→1. |
| 0.78 – 1.0 (1400–1800ms) | Exit       | Todo o `Stack` (logo+anéis+texto) escala até 1.15 com fade-out simultâneo. |

Ao fim do controller (`AnimationStatus.completed`), chama `onSplashComplete`.

### Responsividade

Tamanhos relativos ao `MediaQuery`/`LayoutBuilder` (ex.: logo = 40% da menor
dimensão da tela), sem valores fixos em pixel — mesma prática de
`BoardGeometry`. Único layout: portrait/mobile (o jogo já não tem layout
landscape em nenhuma outra tela).

### Fora de escopo (YAGNI)

- Partículas de poeira/brilho flutuando no fundo.
- Qualquer alteração na splash nativa (`flutter_native_splash`).
- `onSplashComplete` carregando assets pesados de forma assíncrona — hoje não
  há nada a pré-carregar que justifique isso; é uma `VoidCallback` de
  navegação.
- Suporte a landscape/tablet.

## Testes

- Widget test em `test/.../splash_screen_test.dart`:
  - `pumpAndSettle` completa (prova que a animação tem duração finita, nenhum
    `AnimationController` fica repetindo).
  - Após a animação, `LevelSelectScreen` está na árvore (navegação ocorreu).
  - Um teste que passa `onSplashComplete` customizado confirma que o callback
    é chamado em vez da navegação padrão.
