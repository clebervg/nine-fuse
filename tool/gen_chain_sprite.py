"""Gera o SVG do obstáculo Corrente (256x256, encaixe na face da peça).

Reserva: o sprite em uso desde 2026-11-03 veio do Claude Design. Rodar
isto sobrescreve a arte final com a versão vetorial antiga.

Uso (o rsvg-convert é o mesmo do pipeline de ícones: `brew install librsvg`):

    python3 tool/gen_chain_sprite.py docs/brand/obstacle_chain.svg
    rsvg-convert -w 256 -h 256 docs/brand/obstacle_chain.svg \
        -o assets/sprites/obstacles/obstacle_chain_1.png

A corrente contorna a borda da face em vez de cruzar em X: o X passaria
exatamente pelo centro, onde mora o número, e a peça acorrentada **combina** —
o jogador precisa ler o valor para montar o trio que a solta. O cadeado fica
no canto inferior direito pelo mesmo motivo.

A fonte vetorial fica em docs/brand/, e não em assets/sprites/obstacles/: tudo
naquela pasta vai para o bundle do app.
"""
import math, sys

# Face da peça no canvas 256 (manifest): x=20 y=12 w=216 h=204 r=56.
FX, FY, FW, FH, FR = 20, 12, 216, 204, 56
INSET = 13
X0, Y0 = FX + INSET, FY + INSET
W, H = FW - 2 * INSET, FH - 2 * INSET
R = FR - INSET

def perimeter_points(n):
    """n pontos equidistantes no retângulo arredondado, com ângulo da tangente."""
    straight_h = W - 2 * R
    straight_v = H - 2 * R
    arc = math.pi * R / 2
    segs = [
        ('line', (X0 + R, Y0), (1, 0), straight_h),
        ('arc', (X0 + W - R, Y0 + R), -math.pi / 2, arc),
        ('line', (X0 + W, Y0 + R), (0, 1), straight_v),
        ('arc', (X0 + W - R, Y0 + H - R), 0, arc),
        ('line', (X0 + W - R, Y0 + H), (-1, 0), straight_h),
        ('arc', (X0 + R, Y0 + H - R), math.pi / 2, arc),
        ('line', (X0, Y0 + H - R), (0, -1), straight_v),
        ('arc', (X0 + R, Y0 + R), math.pi, arc),
    ]
    total = sum(s[3] for s in segs)
    pts = []
    for i in range(n):
        d = (i + 0.5) * total / n
        for kind, a, b, length in segs:
            if d <= length:
                if kind == 'line':
                    (x, y), (dx, dy) = a, b
                    pts.append((x + dx * d, y + dy * d, math.degrees(math.atan2(dy, dx))))
                else:
                    (cx, cy), start = a, b
                    t = start + d / R
                    pts.append((cx + R * math.cos(t), cy + R * math.sin(t),
                                math.degrees(t + math.pi / 2)))
                break
            d -= length
    return pts, total

N = 30
pts, total = perimeter_points(N)
step = total / N

links = []
for i, (x, y, ang) in enumerate(pts):
    # O cadeado tapa o trecho do canto inferior direito; os elos ali sairiam
    # por baixo dele, então nem são desenhados.
    if x > 180 and y > 160:
        continue
    flat = i % 2 == 0
    if flat:
        rx, ry, sw = step * 0.62, step * 0.44, 5.8
    else:
        rx, ry, sw = step * 0.62, step * 0.10, 5.4
    links.append((flat, x, y, ang, rx, ry, sw))

def link_svg(flat, x, y, ang, rx, ry, sw):
    t = f'translate({x:.2f} {y:.2f}) rotate({ang:.2f})'
    if flat:
        return (f'<g transform="{t}">'
                f'<ellipse rx="{rx:.2f}" ry="{ry:.2f}" fill="none" stroke="#4A2A05" stroke-width="{sw + 2.6:.2f}" opacity="0.75"/>'
                f'<ellipse rx="{rx:.2f}" ry="{ry:.2f}" fill="none" stroke="url(#gold)" stroke-width="{sw:.2f}"/>'
                f'<path d="M {-rx * 0.62:.2f} {-ry * 0.78:.2f} Q 0 {-ry * 1.18:.2f} {rx * 0.62:.2f} {-ry * 0.78:.2f}" fill="none" stroke="#FFF8D6" stroke-width="1.8" stroke-linecap="round" opacity="0.9"/>'
                f'</g>')
    # Elo de pé: visto de lado, uma cápsula cheia.
    return (f'<g transform="{t}">'
            f'<rect x="{-rx:.2f}" y="{-ry - sw / 2:.2f}" width="{2 * rx:.2f}" height="{2 * ry + sw:.2f}" rx="{ry + sw / 2:.2f}" fill="#4A2A05" opacity="0.75" transform="scale(1.06 1.3)"/>'
            f'<rect x="{-rx:.2f}" y="{-ry - sw / 2:.2f}" width="{2 * rx:.2f}" height="{2 * ry + sw:.2f}" rx="{ry + sw / 2:.2f}" fill="url(#goldSide)"/>'
            f'<line x1="{-rx * 0.6:.2f}" y1="{-ry * 0.4:.2f}" x2="{rx * 0.6:.2f}" y2="{-ry * 0.4:.2f}" stroke="#FFF8D6" stroke-width="1.4" stroke-linecap="round" opacity="0.85"/>'
            f'</g>')

# Desenha primeiro os elos de pé (ficam "por baixo" dos deitados que os prendem).
body = ''.join(link_svg(*l) for l in links if not l[0])
body += ''.join(link_svg(*l) for l in links if l[0])

# Cadeado pendurado no canto inferior direito.
LX, LY = 198, 176
lock = f'''
<g transform="translate({LX} {LY})">
  <ellipse cx="2" cy="31" rx="27" ry="6" fill="#000" opacity="0.28"/>
  <path d="M -15 -2 L -15 -16 A 15 15 0 0 1 15 -16 L 15 -2" fill="none" stroke="#4A2A05" stroke-width="11" stroke-linecap="round"/>
  <path d="M -15 -2 L -15 -16 A 15 15 0 0 1 15 -16 L 15 -2" fill="none" stroke="url(#steel)" stroke-width="7" stroke-linecap="round"/>
  <path d="M -11 -18 A 11 11 0 0 1 2 -27" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" opacity="0.8"/>
  <rect x="-25" y="-6" width="50" height="38" rx="11" fill="#4A2A05"/>
  <rect x="-23" y="-5" width="46" height="35" rx="10" fill="url(#lockBody)"/>
  <rect x="-23" y="-5" width="46" height="35" rx="10" fill="none" stroke="#FFF3B0" stroke-width="1.5" opacity="0.7"/>
  <path d="M -18 0 Q 0 -4 18 0 L 18 5 Q 0 1 -18 5 Z" fill="#FFFBE6" opacity="0.55"/>
  <circle cx="0" cy="10" r="5.2" fill="#3A2004"/>
  <path d="M -2.6 12 L 2.6 12 L 3.6 21 L -3.6 21 Z" fill="#3A2004"/>
</g>'''

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<defs>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF1A8"/>
    <stop offset="0.45" stop-color="#FFC93C"/>
    <stop offset="1" stop-color="#C47A12"/>
  </linearGradient>
  <linearGradient id="goldSide" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFE27A"/>
    <stop offset="0.5" stop-color="#E9A526"/>
    <stop offset="1" stop-color="#9A5A0C"/>
  </linearGradient>
  <linearGradient id="lockBody" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFE680"/>
    <stop offset="0.5" stop-color="#FFB627"/>
    <stop offset="1" stop-color="#C46A0A"/>
  </linearGradient>
  <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#F4F6FA"/>
    <stop offset="0.5" stop-color="#AEB6C4"/>
    <stop offset="1" stop-color="#6B7385"/>
  </linearGradient>
  <filter id="drop" x="-10%" y="-10%" width="120%" height="125%">
    <feDropShadow dx="0" dy="2.5" stdDeviation="2" flood-color="#000" flood-opacity="0.45"/>
  </filter>
</defs>
<!-- Véu âmbar levíssimo na face: diz "presa" sem apagar a cor da peça. -->
<rect x="{FX}" y="{FY}" width="{FW}" height="{FH}" rx="{FR}" fill="#FFC93C" opacity="0.10"/>
<rect x="{FX + 2}" y="{FY + 2}" width="{FW - 4}" height="{FH - 4}" rx="{FR - 2}" fill="none" stroke="#FFD24A" stroke-width="3" opacity="0.55"/>
<g filter="url(#drop)">{body}</g>
<g filter="url(#drop)">{lock}</g>
</svg>'''
open(sys.argv[1], 'w').write(svg)
