#!/usr/bin/env python3
"""Exporta o glifo de um caractere de uma fonte TTF como <path> SVG.

Usa a Nunito Black (a mesma fonte já empacotada no app, `AppFonts.display`)
para o dígito do selo do logo, em vez de um traçado desenhado à mão — o
histórico do projeto (ver CLAUDE.md, seção "AppIcon") registra duas
tentativas de desenho manual que saíram lendo como "g" e como "a".

As coordenadas da fonte são Y-para-cima (origem na linha de base); SVG é
Y-para-baixo. O path sai com um `transform="scale(1,-1)"` já embutido nas
coordenadas (Y invertido diretamente nos comandos), para poder ser colado
direto num `<path d="...">` sem precisar de atributo de transform adicional.

Uso:
    python3 tool/export_glyph_path.py <fonte.ttf> <caractere>

Imprime, em stdout:
    d="..."            — atributo pronto para colar num <path>
    viewBox equivalente — unitsPerEm e bounds, para posicionar o path no selo
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
