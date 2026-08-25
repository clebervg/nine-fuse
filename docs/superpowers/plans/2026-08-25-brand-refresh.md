# Refresh de identidade visual (marca, splash, ícone) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o crachá "9F" de vidro (ícone do app, splash e logo interno) por uma marca vetorial limpa — selo dourado com o dígito 9 tipográfico — e alinhar o wordmark "NineFuse" da splash ao mesmo acabamento visual dos botões do jogo.

**Architecture:** Um novo `assets/images/logo.svg` vetorial (com o grupo `<g id="mark">` que `tool/prepare_icons.dart` já espera) substitui o raster atual; o pipeline existente (`prepare_icons.dart` → `flutter_launcher_icons` → `flutter_native_splash`) deriva todos os mestres sem mudança de código nele. O dígito "9" do selo vem de um `<path>` exportado da fonte Nunito Black via `fontTools` (script novo, `tool/export_glyph_path.py`), não de um traçado desenhado à mão — decisão que evita repetir as duas tentativas manuais já registradas em `CLAUDE.md` que saíram lendo como "g" e "a". O wordmark "NineFuse" na `SplashScreen` (Dart) ganha o acabamento em relevo já aprovado, via `ShaderMask` + uma cópia de texto escura por baixo (não `TextStyle.shadows`, que é documentadamente inseguro dentro do `Transform.scale` que envolve esse texto).

**Tech Stack:** Flutter/Dart, SVG, Python 3 + `fontTools` (ferramenta de build, não dependência do app), `rsvg-convert` (já exigido pelo pipeline existente).

## Global Constraints

- Nenhuma fonte nova: só a Nunito já empacotada (`assets/fonts/Nunito-Black.ttf`), sem depender de rede.
- `GameButton` não muda (decisão já tomada na fase de design).
- Estrutura e timing da animação de `SplashScreen` (`kSplashDuration`, estágios `_entranceEnd`/`_powerUpEnd`/`_idleEnd`) não mudam — só a arte do ícone e o tratamento do texto.
- Cor de fundo do ícone adaptativo continua `#000028` (já configurada em `flutter_launcher_icons.yaml`) — o novo SVG usa esse valor exato para o retângulo de fundo, para o pipeline não pedir mudança de configuração.
- Nenhum golden test novo — nem `logo.svg`/ícones nem a splash animada têm golden hoje; a verificação de arte é visual/manual (mesma decisão já registrada em `CLAUDE.md`).

---

### Task 1: Script de exportação do glifo "9" da fonte

**Files:**
- Create: `tool/export_glyph_path.py`

**Interfaces:**
- Produces: um script de linha de comando `python3 tool/export_glyph_path.py <fonte.ttf> <caractere>` que imprime em stdout a linha `d="..."` (atributo pronto para um `<path>` SVG, coordenadas já invertidas para Y-para-baixo) e as linhas de metadados (`unitsPerEm=`, `bounds (Y-down, após flip)=`, `width=`/`height=`). A Task 2 consome a linha `d="..."` diretamente.

- [ ] **Step 1: Instalar a dependência de build (não entra no `pubspec.yaml` — é ferramenta de desenvolvimento, roda fora do app)**

```bash
python3 -m pip install --quiet fonttools
```

Verifique que instalou:

```bash
python3 -c "import fontTools; print(fontTools.version)"
```

Esperado: imprime um número de versão (ex. `4.63.0`), sem `ModuleNotFoundError`.

- [ ] **Step 2: Escrever o script**

Crie `tool/export_glyph_path.py` com este conteúdo exato:

```python
#!/usr/bin/env python3
"""Exporta o glifo de um caractere de uma fonte TTF como <path> SVG.

Usa a Nunito Black (a mesma fonte já empacotada no app, `AppFonts.display`)
para o dígito do selo do logo, em vez de um traçado desenhado à mão — o
histórico do projeto (ver CLAUDE.md, seção "AppIcon") registra duas
tentativas de desenho manual que saíram lendo como "g" e como "a".

As coordenadas da fonte são Y-para-cima (origem na linha de base); SVG é
Y-para-baixo. O path sai com o Y já invertido nos comandos, para poder ser
colado direto num `<path d="...">` sem precisar de atributo de transform
adicional para a inversão de eixo.

Uso:
    python3 tool/export_glyph_path.py <fonte.ttf> <caractere>

Imprime, em stdout:
    d="..."            — atributo pronto para colar num <path>
    metadados de bounds/unitsPerEm — para posicionar o path no selo
"""
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    font_path, char = sys.argv[1], sys.argv[2]
    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    glyph_name = font.getBestCmap()[ord(char)]
    glyph = glyph_set[glyph_name]

    bounds_pen = BoundsPen(glyph_set)
    glyph.draw(bounds_pen)
    x_min, y_min, x_max, y_max = bounds_pen.bounds

    svg_pen = SVGPathPen(glyph_set)
    # Inverte Y na origem do pen: (x, y) -> (x, -y). Resultado sai já em
    # coordenadas Y-para-baixo, sem precisar de transform no SVG final.
    flipping_pen = TransformPen(svg_pen, (1, 0, 0, -1, 0, 0))
    glyph.draw(flipping_pen)

    units_per_em = font["head"].unitsPerEm

    print(f'd="{svg_pen.getCommands()}"')
    print(f"unitsPerEm={units_per_em}")
    print(f"bounds (Y-up, original)={x_min},{y_min},{x_max},{y_max}")
    print(f"bounds (Y-down, após flip)={x_min},{-y_max},{x_max},{-y_min}")
    print(f"width={x_max - x_min} height={y_max - y_min}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Rodar e conferir a saída**

```bash
python3 tool/export_glyph_path.py assets/fonts/Nunito-Black.ttf 9
```

Esperado, exatamente (a fonte já está no repositório, o resultado é determinístico):

```
d="M238 11Q197 11 155.0 1.0Q113 -9 75 -29Q51 -41 42.0 -61.5Q33 -82 35.5 -104.5Q38 -127 51.0 -144.5Q64 -162 85.5 -169.0Q107 -176 134 -164Q164 -150 190.0 -145.0Q216 -140 240 -140Q290 -140 323.5 -160.5Q357 -181 373.5 -222.5Q390 -264 390 -326V-378H405Q397 -336 372.5 -305.0Q348 -274 312.5 -258.0Q277 -242 233 -242Q175 -242 128.5 -271.5Q82 -301 55.0 -353.5Q28 -406 28 -471Q28 -543 59.0 -598.0Q90 -653 145.5 -684.5Q201 -716 272 -716Q365 -716 429.5 -674.0Q494 -632 528.0 -552.5Q562 -473 562 -359Q562 -272 540.0 -203.0Q518 -134 476.0 -86.5Q434 -39 374.0 -14.0Q314 11 238 11ZM282 -382Q308 -382 327.5 -394.5Q347 -407 357.5 -428.5Q368 -450 368 -479Q368 -509 357.5 -531.0Q347 -553 327.5 -564.5Q308 -576 282 -576Q256 -576 237.0 -564.5Q218 -553 207.0 -531.0Q196 -509 196 -479Q196 -450 207.0 -428.5Q218 -407 237.0 -394.5Q256 -382 282 -382Z"
unitsPerEm=1000
bounds (Y-up, original)=28,-11,562,716
bounds (Y-down, após flip)=28,-716,562,11
width=534 height=727
```

Se o `d="..."` sair diferente, a fonte empacotada mudou desde este plano — use a saída real da Task 3 em diante em vez da copiada aqui.

- [ ] **Step 4: Commit**

```bash
git add tool/export_glyph_path.py
git commit -m "build: script de exportação de glifo TTF para path SVG"
```

---

### Task 2: Novo `assets/images/logo.svg` vetorial

**Files:**
- Modify: `assets/images/logo.svg` (substituição completa do conteúdo — hoje é um raster embutido em `<image>`, vira vetor puro)

**Interfaces:**
- Consumes: a linha `d="..."` produzida pela Task 1.
- Produces: um SVG com `<g id="mark">` contendo só o selo (sem o retângulo de fundo) — é o contrato que `tool/prepare_icons.dart` (`_markOnlySvg`, procura literalmente a string `<g id="mark">`) espera para separar arte de fundo no ícone adaptativo do Android.

- [ ] **Step 1: Escrever o novo `assets/images/logo.svg`**

Substitua o conteúdo inteiro do arquivo por (o `d="..."` abaixo é o exato validado na Task 1 — se a Task 1 imprimiu um valor diferente, use aquele):

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="badgeGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFE680"/>
      <stop offset="0.55" stop-color="#FFD700"/>
      <stop offset="1" stop-color="#FF8C00"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="1024" height="1024" fill="#000028"/>
  <g id="mark">
    <rect x="156" y="156" width="712" height="712" rx="160" ry="160" fill="url(#badgeGrad)"/>
    <rect x="156" y="156" width="712" height="712" rx="160" ry="160" fill="none" stroke="#FFFFFF" stroke-opacity="0.30" stroke-width="6"/>
    <path transform="translate(512 512) scale(0.5876) translate(-295 352.5)" fill="#15150F" d="M238 11Q197 11 155.0 1.0Q113 -9 75 -29Q51 -41 42.0 -61.5Q33 -82 35.5 -104.5Q38 -127 51.0 -144.5Q64 -162 85.5 -169.0Q107 -176 134 -164Q164 -150 190.0 -145.0Q216 -140 240 -140Q290 -140 323.5 -160.5Q357 -181 373.5 -222.5Q390 -264 390 -326V-378H405Q397 -336 372.5 -305.0Q348 -274 312.5 -258.0Q277 -242 233 -242Q175 -242 128.5 -271.5Q82 -301 55.0 -353.5Q28 -406 28 -471Q28 -543 59.0 -598.0Q90 -653 145.5 -684.5Q201 -716 272 -716Q365 -716 429.5 -674.0Q494 -632 528.0 -552.5Q562 -473 562 -359Q562 -272 540.0 -203.0Q518 -134 476.0 -86.5Q434 -39 374.0 -14.0Q314 11 238 11ZM282 -382Q308 -382 327.5 -394.5Q347 -407 357.5 -428.5Q368 -450 368 -479Q368 -509 357.5 -531.0Q347 -553 327.5 -564.5Q308 -576 282 -576Q256 -576 237.0 -564.5Q218 -553 207.0 -531.0Q196 -509 196 -479Q196 -450 207.0 -428.5Q218 -407 237.0 -394.5Q256 -382 282 -382Z"/>
  </g>
</svg>
```

Notas sobre os números (para quem revisar ou precisar recalcular com outro caractere):
- O selo ocupa `712/1024 ≈ 69.5%` do canvas, centrado (`156 = (1024-712)/2`).
- `0.5876` é o fator de escala do glifo: glifo tem `height=727` unidades (Task 1), e o alvo é 60% da altura do selo (`0.6 * 712 = 427.2`; `427.2 / 727 ≈ 0.5876`).
- `translate(-295 352.5)` centraliza o glifo antes de escalar: `295 = (28+562)/2` (centro X dos bounds Y-down) e `352.5 = -(-716+11)/2` (centro Y, com sinal invertido porque a translação precisa cancelar o deslocamento do centro).
- `#15150F` é a mesma cor de texto escuro que `GameButton` já usa sobre fundo dourado (`game_dialog.dart`) — reaproveitada aqui para o dígito, não uma cor nova.

- [ ] **Step 2: Renderizar e conferir visualmente antes de seguir**

```bash
rsvg-convert -w 512 -h 512 assets/images/logo.svg -o /tmp/logo_preview.png
```

Abra `/tmp/logo_preview.png` e confirme visualmente:
- O selo é um quadrado de cantos arredondados, degradê dourado (claro no topo, laranja na base), sem vidro/espirais/partículas.
- O "9" lê como "9" sem ambiguidade, dentro do selo, com boa margem para as bordas.

Se o glifo estiver descentralizado ou grande/pequeno demais, ajuste os números de `scale`/`translate` do Step 1 e renderize de novo — não segue para o Step 3 sem essa confirmação visual.

- [ ] **Step 3: Commit**

```bash
git add assets/images/logo.svg
git commit -m "feat: substitui o crachá 9F por um selo dourado vetorial"
```

---

### Task 3: Regenerar ícones e splash a partir do novo SVG

**Files:**
- Modify (gerados pela ferramenta, não à mão): `assets/images/logo.png`, `assets/images/logo_splash.png`, `assets/icon/app_icon.png`, `assets/icon/app_icon_foreground.png`, `dist/store/play_store_icon_512.png`, `dist/store/app_store_icon_1024.png`, e todos os ícones nativos sob `android/app/src/main/res/`, `ios/Runner/Assets.xcassets/`.

**Interfaces:**
- Consumes: `assets/images/logo.svg` da Task 2.

- [ ] **Step 1: Rodar `prepare_icons.dart`**

```bash
dart run tool/prepare_icons.dart
```

Esperado: uma linha `gerado ...` por arquivo (sem `AVISO: ... não tem <g id="mark">`, já que a Task 2 incluiu o grupo), e ao final:

```
cor de fundo detectada: #000028
```

(Confirma o "Global Constraints": nenhuma mudança em `flutter_launcher_icons.yaml` é necessária porque a cor detectada já é a configurada.)

Se a cor detectada vier diferente de `#000028`, pare e investigue antes de continuar — significa que o retângulo de fundo do SVG da Task 2 não saiu como o especificado.

- [ ] **Step 2: Conferir visualmente `assets/icon/app_icon_foreground.png` (a frente do ícone adaptativo)**

Abra o arquivo gerado. Confirme que o selo aparece **sem** o retângulo de fundo (canto transparente), centralizado, e que a arte cabe dentro de uma máscara circular imaginária (não encoste nos quatro cantos do quadro).

- [ ] **Step 3: Rodar `flutter_launcher_icons`**

```bash
dart run flutter_launcher_icons
```

Esperado: termina sem erro, regenerando os ícones sob `android/app/src/main/res/mipmap-*` e `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

- [ ] **Step 4: Conferir visualmente o ícone final do Android**

Abra `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` e confirme: selo dourado limpo, sem vidro/espirais, "9" legível, contra o fundo `#000028`.

- [ ] **Step 5: Regenerar a splash nativa**

```bash
dart run flutter_native_splash:create
```

Esperado: termina sem erro, regenerando `android/app/src/main/res/drawable*/splash.png` e `android12splash.png`, e os assets equivalentes de iOS.

- [ ] **Step 6: Commit**

```bash
git add assets/images/logo.png assets/images/logo_splash.png assets/icon/ dist/store/ android/app/src/main/res ios/Runner/Assets.xcassets
git commit -m "chore: regenera ícones e splash a partir do novo selo"
```

---

### Task 4: Wordmark "NineFuse" em relevo na `SplashScreen`

**Files:**
- Modify: `lib/features/game/presentation/screens/splash_screen.dart`

**Interfaces:**
- Consumes: `AppColors.digit9` (`#FFD700`), `AppColors.digit9Deep` (`#FF8C00`) de `lib/core/constants/app_colors.dart`; `AppFonts.display` de `lib/core/theme/app_fonts.dart`.

Contexto do porquê **não** usar `TextStyle(shadows: kGameTextShadow)` aqui: o comentário em `lib/features/game/presentation/widgets/game_dialog.dart` (linhas 20-26) documenta que o Impeller rasteriza sombra de texto **fora** de qualquer `Transform`/`ScaleTransition`/`AnimatedPositioned` ancestral, acumulando sombras borradas num canto da tela — e o wordmark desta tela vive dentro do `Transform.scale(scale: exitScale, ...)` que envolve toda a `Column` (ver `_buildContent`). A sombra aqui é simulada com uma cópia de texto escura, deslocada, desenhada por baixo — a mesma técnica que evita o bug sem depender de `shadows:`.

- [ ] **Step 1: Atualizar o import e o comentário de cabeçalho do arquivo**

Em `lib/features/game/presentation/screens/splash_screen.dart`, substitua o import de cores (adicione, se não vier já importado — confira antes de duplicar) e troque o parágrafo do comentário de classe que descreve o asset antigo:

Substitua:

```dart
/// O design original previa anéis de energia girando e um glow dourado por
/// trás do logo durante o estágio power-up. O `assets/images/logo.png`
/// reaproveitado não é a peça `9` dourada isolada: é um cartão "9F" de vidro
/// ciano/magenta com um redemoinho de energia roxo/laranja já pintado na
/// própria imagem. Sobrepor os anéis sintéticos duplicava esse redemoinho, e
/// o glow dourado destoava das cores do cartão — por isso ambos foram
/// removidos, mantendo o texto "NineFuse" surgindo no mesmo estágio.
```

Por:

```dart
/// O design original previa anéis de energia girando e um glow dourado por
/// trás do logo durante o estágio power-up. Removidos: com o selo dourado
/// atual (`assets/images/logo.png`, ver
/// `docs/superpowers/specs/2026-08-25-brand-refresh-design.md`) o glow
/// duplicaria o brilho que o próprio degradê do selo já sugere. O texto
/// "NineFuse" continua surgindo no estágio power-up, agora em relevo
/// (degradê dourado + sombra), no mesmo acabamento dos botões do jogo.
```

- [ ] **Step 2: Trocar o `Text` do wordmark por uma versão em relevo**

Localize este bloco (dentro de `_buildContent`):

```dart
              Opacity(
                opacity: powerUp.clamp(0.0, 1.0),
                child: const Text(
                  'NineFuse',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
```

Substitua por:

```dart
              Opacity(
                opacity: powerUp.clamp(0.0, 1.0),
                child: const _WordmarkNineFuse(),
              ),
```

- [ ] **Step 3: Adicionar o widget `_WordmarkNineFuse`**

Adicione esta classe privada no final do arquivo, depois de `_SplashScreenState` (antes ou depois de `_shimmer` não importa — é um widget novo, não um método):

```dart
/// Wordmark "NineFuse" em relevo: "Nine" no degradê dourado do dígito 9
/// (`AppColors.digit9` → `digit9Deep`), "Fuse" em branco sólido.
///
/// Não usa `TextStyle(shadows: ...)` porque este widget vive dentro do
/// `Transform.scale` de saída da splash, e sombra de texto sob `Transform`
/// se acumula fora de lugar no Impeller (ver o mesmo aviso em
/// `game_dialog.dart`, `kGameTextShadow`). A sombra aqui é uma cópia do
/// texto em cinza-escuro, deslocada 2px para baixo, por trás da cópia
/// colorida — sombra "desenhada", não sombra de framework.
///
/// Duas peças de texto (`Row`), não um `Text.rich` com `ShaderMask` único:
/// um único `Shader` teria de cobrir "NineFuse" inteiro, tingindo "Fuse" com
/// o mesmo degradê dourado — o mockup aprovado pede "Fuse" branco sólido.
class _WordmarkNineFuse extends StatelessWidget {
  const _WordmarkNineFuse();

  static const TextStyle _style = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 2,
          child: Text('NineFuse', style: _style.copyWith(color: const Color(0x66000000))),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.digit9, AppColors.digit9Deep],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: const Text('Nine', style: _style),
            ),
            const Text('Fuse', style: _style),
          ],
        ),
      ],
    );
  }
}
```

Import necessário no topo do arquivo (adicione se ainda não estiver):

```dart
import 'package:nine_fuse/core/constants/app_colors.dart';
```

(Já está importado — confira a linha 4 do arquivo atual, `import 'package:nine_fuse/core/constants/app_colors.dart';` — se estiver lá, não duplique.)

- [ ] **Step 4: Rodar os testes da splash**

```bash
flutter test test/features/game/presentation/splash_screen_test.dart
```

Esperado: `All tests passed!` (os dois testes existentes não verificam o conteúdo visual do texto, só o fluxo de navegação/callback — não deveriam quebrar).

- [ ] **Step 5: Rodar o app e conferir visualmente**

```bash
flutter run -d <seu-dispositivo-ou-emulador>
```

Confirme na tela de splash: selo dourado limpo acima, "Nine" em degradê dourado + "Fuse" em branco abaixo, com uma sombra escura sutil por trás do texto (não um halo, não um recorte visível). Encerre o app depois de conferir.

- [ ] **Step 6: Commit**

```bash
git add lib/features/game/presentation/screens/splash_screen.dart
git commit -m "feat: wordmark NineFuse em relevo na splash"
```

---

### Task 5: Verificação final

**Files:** nenhum arquivo novo — só comandos de verificação.

- [ ] **Step 1: Confirmar que nenhuma outra referência a `logo.png`/`logo.svg`/`logo_splash.png` ficou de fora**

```bash
grep -rn "logo\.png\|logo_splash\.png\|logo\.svg" lib test tool pubspec.yaml flutter_native_splash.yaml flutter_launcher_icons.yaml
```

Esperado: as mesmas ocorrências já mapeadas no spec (comentários + `splash_screen.dart` + os três arquivos de configuração do pipeline) — nenhuma referência nova e nenhuma órfã. Se aparecer alguma tela/widget não coberta pelas Tasks 1-4, trate como escopo adicional antes de encerrar (o spec exige levantar isso, não assumir).

- [ ] **Step 2: Suíte de testes completa**

```bash
flutter test
```

Esperado: `All tests passed!`, mesma contagem de testes de antes do plano (nenhum teste novo foi pedido — a verificação de arte é visual, conforme o spec).

- [ ] **Step 3: `flutter analyze`**

```bash
flutter analyze
```

Esperado: `No issues found!`.

- [ ] **Step 4: Registrar a mudança no `CLAUDE.md`**

Adicione esta seção ao final do `CLAUDE.md` (mantendo o padrão de registro do arquivo: fato, depois o porquê):

```markdown
### Refresh de identidade visual: selo vetorial substitui o crachá "9F" (2026-08-25)

**`assets/images/logo.svg` voltou a ser vetor puro, com o grupo `<g
id="mark">` que `tool/prepare_icons.dart` sempre esperou.** Em algum ponto
depois da seção "AppIcon" (peça 3D com o glifo desenhado à mão) o arquivo
tinha virado uma imagem raster embutida — um crachá "9F" de vidro com
espirais, sem o grupo `mark` — e o pipeline vinha caindo no fallback
documentado em `flutter_launcher_icons.yaml` (frente do adaptativo = logo
inteiro, sem separar fundo) com um `app_icon_foreground.png` remendado à
mão por cima. Ver `docs/superpowers/specs/2026-08-25-brand-refresh-design.md`
e `docs/superpowers/plans/2026-08-25-brand-refresh.md` para a investigação e
a reconstrução completas.

**O dígito "9" do selo é um `<path>` exportado da Nunito Black, não mais
desenhado à mão.** As duas tentativas anteriores registradas na seção
"AppIcon" leram como `g` e como `a`. `tool/export_glyph_path.py` (novo,
depende de `fontTools`, só em tempo de build) extrai o contorno real do
glifo direto da fonte que o próprio jogo já usa — elimina essa classe de erro
por construção, em vez de calibrar right à mão de novo.

**Fundo do ícone adaptativo continua `#000028`** — não mudou, só passou a
ser o valor literal do retângulo de fundo do SVG (antes era o *stop* externo
de um gradiente que não existe mais).
```

Antes de comitar, confira que o `d="..."` real usado na Task 2 corresponde ao que está descrito aqui (esta seção não repete o path — só registra a decisão).

- [ ] **Step 5: Commit final**

```bash
git add CLAUDE.md
git commit -m "docs: registra o refresh de identidade visual no CLAUDE.md"
```
