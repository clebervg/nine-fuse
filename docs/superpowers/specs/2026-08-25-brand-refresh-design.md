# Refresh de identidade visual: marca, splash e ícone do app

## Problema

O ícone do app, a splash e o logo interno (`assets/images/logo.svg` →
`logo.png` → `logo_splash.png` → ícones nativos) mostram hoje o mesmo crachá
"9F" de vidro ciano com espirais roxa/laranja — uma arte com aparência de
banco de imagens genérico, sem relação com a paleta do jogo (o dígito 9 é
dourado, `AppColors.digit9`/`digit9Deep`) nem com a linguagem visual do resto
da UI (botões e diálogos usam profundidade sólida — degradê + aresta escura —,
não vidro translúcido).

**Causa raiz confirmada:** o `logo.svg` documentado em `CLAUDE.md` — um glifo
vetorial cuidadoso do dígito 9 (barriga + haste, três camadas via `<g
id="mark">`) — foi em algum momento substituído por uma imagem raster
(o crachá "9F"), sem o grupo `mark` que `tool/prepare_icons.dart` exige para
separar arte de fundo no ícone adaptativo do Android. O próprio
`flutter_launcher_icons.yaml` documenta o sintoma: sem o grupo `mark`, a
ferramenta caiu no fallback (zona segura por raio sobre o quadrado inteiro) e
alguém precisou editar `app_icon_foreground.png` **à mão** como contorno. O
pipeline documentado está quebrado silenciosamente; o defeito visual em todo
lugar é consequência disso, não três problemas separados.

## Escopo

Substituir a marca gráfica de ponta a ponta — um único SVG vetorial novo,
propagado pelo pipeline já existente — em três lugares que hoje mostram o
crachá quebrado:

1. Ícone do app (Android adaptativo + iOS + web), via
   `tool/prepare_icons.dart` → `flutter_launcher_icons`.
2. Splash nativa de cold-start (`flutter_native_splash`) e a `SplashScreen`
   animada em Dart.
3. Qualquer referência solta a `logo.png` dentro do app (buscar antes de
   assumir que são só esses dois consumidores).

Fora de escopo, por decisão já tomada nesta conversa:
- **Botões do jogo (`GameButton`)** — ficam como estão. Não eram o problema;
  pareciam deslocados só por estarem ao lado do logo quebrado.
- Qualquer nova biblioteca de fonte — a Nunito já empacotada
  (`assets/fonts/`, pesos 700/800/900) é a única usada, sem depender de rede
  (`AppFonts`).
- Animação da splash: a estrutura atual (`SplashScreen`, `AnimationController`
  único fatiado em estágios — entrada, nome aparecendo, idle com progresso,
  saída, 1800ms) é mantida. Só a arte do selo/wordmark muda.

## Direção visual (aprovada via mockup)

**Selo:** peça quadrada de cantos arredondados, degradê dourado sólido
(`AppColors.digit9` `#FFD700` → `digit9Deep` `#FF8C00`, claro no topo/escuro na
base), bisel sólido (sombra de aresta, brilho interno no topo) — a mesma
construção de profundidade que `GameButton` e `GameDialog` já usam em outros
elementos. **Sem vidro translúcido, sem espirais, sem partículas.** O dígito
"9" dentro do selo é tipográfico: o numeral da própria Nunito Black
(`assets/fonts/Nunito-Black.ttf`), não um traçado desenhado à mão. Isto por
decisão explícita: o histórico em `CLAUDE.md` registra **duas tentativas
anteriores** de desenhar o glifo do 9 à mão que saíram lendo como `g` e como
`a` — usar o numeral real da fonte do próprio jogo elimina essa classe de erro
por completo, e mantém a mesma família tipográfica que os dígitos do
tabuleiro já usam.

**Wordmark:** "NineFuse" em Nunito Black, tratamento em relevo — degradê
dourado claro→escuro com `background-clip` no texto + sombra de contorno
escura de 2px, o mesmo par degradê+aresta que os botões do jogo já usam. "Nine"
no degradê dourado, "Fuse" em branco sólido — o par de cores que separa as
duas metades do nome sem precisar de dois pesos de fonte.

**Fundo do ícone adaptativo:** mantém `#000028` (já configurado em
`flutter_launcher_icons.yaml`, `adaptive_icon_background`/`background_color_ios`)
— quase-preto, compatível com `AppColors.darkBackground`. Não é o quase-preto
antigo (`#090514`) porque aquele era o *stop* externo do gradiente do crachá
antigo, que deixa de existir; `#000028` já está configurado e não precisa
mudar.

## O que muda tecnicamente

1. **Novo `assets/images/logo.svg`**, desenhado como vetor puro (não raster
   embutido), com a estrutura que `tool/prepare_icons.dart` espera:
   - Um retângulo de fundo (`#000028`, ou o degradê equivalente já
     documentado) fora do grupo `mark`.
   - `<g id="mark">` contendo só o selo dourado + o numeral "9" — nada além
     disso, para a frente do ícone adaptativo derivar por recorte desse grupo
     (a régua já documentada: recortar pela caixa do conteúdo antes de
     escalar, ajustar pelo raio do círculo de 66%, não pelo lado).
   - O numeral como `<path>` exportado da glifo real da Nunito Black (via
     ferramenta de conversão fonte→path, ex. um script com `path_ops`/
     `fonttools` ou exportação manual de um editor vetorial), não desenhado à
     mão — é a decisão que evita repetir os dois becos sem saída já mapeados.
   - Sem `<image>`/raster embutido em lugar nenhum do arquivo.
2. **Regeneração pela pipeline existente, sem mudar a pipeline:**
   ```bash
   dart run tool/prepare_icons.dart   # SVG -> logo.png, mestres, fichas de loja
   dart run flutter_launcher_icons    # mestres -> Android, iOS, web
   dart run flutter_native_splash:create   # usa logo_splash.png derivado
   ```
   `app_icon_foreground.png` editado à mão (o contorno atual) é descartado —
   volta a ser derivado pela ferramenta, já que o `mark` group existe de
   novo.
3. **`logo_splash.png`** volta a ser derivado do SVG novo com fundo removido
   (flood-fill dos quatro cantos + pena de 4px, como já documentado), não
   recriado à mão.
4. **`SplashScreen` (Dart):** nenhuma mudança de estrutura ou timing — só o
   asset (`assets/images/logo.png`) muda de conteúdo. Revisar o comentário em
   `splash_screen.dart` que descreve o "cartão 9F de vidro" — está descrevendo
   o asset que deixa de existir, e precisa ser atualizado para não induzir o
   próximo leitor a erro.

## Verificação

Sem teste automatizado para a arte em si — mesma decisão já registrada no
`CLAUDE.md` para o ícone (`logo.svg` não é renderizado por nenhum widget;
nenhum golden depende dele). A verificação é visual, manual, feita a cada
regeneração:

- O glifo lê como "9" sem ambiguidade (não é o critério mais fácil — é o que
  já falhou duas vezes).
- Sob a máscara circular de 66% do ícone adaptativo, nada essencial é
  cortado.
- O ícone se separa tanto sobre fundo claro quanto escuro.
- A splash (`flutter run`, cold start) mostra o selo + wordmark sem o
  retângulo de fundo antigo vazando atrás.
- `flutter test test/features/game/presentation/splash_screen_test.dart`
  continua verde — o teste cobre estrutura/timing da animação, não a arte, e
  não deve precisar de golden novo (a splash animada não tem golden hoje).

## Riscos e decisões em aberto para a fase de implementação

- **Exportar o numeral "9" da Nunito Black como path SVG** é o passo com mais
  incerteza de ferramenta (depende de `fonttools`/editor vetorial disponível
  no ambiente). Se nenhuma ferramenta de conversão fonte→path estiver
  disponível, a alternativa é renderizar o glifo via `rsvg-convert`/Skia a
  partir de um `<text>` com `font-family: Nunito` embutido e comparar
  visualmente com o desenhado à mão antes de aceitar — nunca aceitar um
  glifo novo sem o mesmo escrutínio visual que os dois anteriores já
  provaram ser necessário.
- **Toda referência a `logo.png`/`logo_splash.png` no app precisa ser
  levantada antes da implementação** (não assumida como só a `SplashScreen`)
  — um `grep` simples resolve isso no início da implementação.
