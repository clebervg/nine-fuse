# Áudio do NineFuse

O jogo **já toca** qualquer arquivo colocado aqui com o nome certo — não há
código a mudar. O `AudioService` (`lib/core/audio/audio_service.dart`) lê o
AssetManifest no primeiro som pedido e fica mudo para o que não existe.
Depois de soltar arquivos novos, **reinstale o app** (`flutter run` de novo):
hot reload não reempacota assets.

Este README não é empacotado: só `sfx/` e `music/` estão declarados no
`pubspec.yaml`.

## Formato

- **Use `.mp3`** (44,1 kHz, estéreo ou mono, 128–192 kbps). Funciona em iOS e
  Android.
- `.ogg` (Vorbis) é aceito **só no Android**: o iOS não decodifica Vorbis, e o
  serviço ignora `.ogg` lá. Se quiser `.ogg` no Android, mande também o `.mp3`
  com o mesmo nome — no Android o `.ogg` tem preferência, no iOS o `.mp3`.
- `.m4a` e `.wav` também são aceitos (o `.wav` pesa: só para efeitos curtos).
- Sem silêncio no começo do arquivo: o efeito tem de sair no quadro da ação.
- Normalize em torno de **-14 LUFS** para música e **-12 LUFS** para efeitos,
  com pico abaixo de -1 dBTP. O peso relativo de cada efeito já é aplicado em
  código (`SoundEvent.gain`), então não abaixe à mão os sons frequentes.

## Efeitos — `assets/audio/sfx/<nome>.mp3`

| arquivo              | quando toca                                         | duração   |
|----------------------|-----------------------------------------------------|-----------|
| `select.mp3`         | peça selecionada; mira de booster engajada          | 40–80 ms  |
| `invalid_swap.mp3`   | troca recusada; mira de booster errada              | 150–250 ms|
| `fusion.mp3`         | fusão comum (3+ peças iguais)                       | 200–350 ms|
| `combo.mp3`          | fusão em cascata (2ª em diante na mesma jogada)     | 250–400 ms|
| `nine_born.mp3`      | nasce um 9 (Bloco 9)                                | 0,6–1 s   |
| `super_nine.mp3`     | Super 9 criado ou ativado                           | 0,8–1,2 s |
| `nova.mp3`           | evento Nova (3+ peças 9)                            | 1–1,5 s   |
| `obstacle_break.mp3` | gelo, vidro ou pedra quebrados                      | 200–400 ms|
| `hammer.mp3`         | golpe do Martelo de Fusão                           | 300–500 ms|
| `bomb.mp3`           | estouro da Bomba                                    | 400–700 ms|
| `brush.mp3`          | Pincel pinta uma peça                               | 200–400 ms|
| `spin_tick.mp3`      | roleta passa por uma divisória                      | 20–50 ms  |
| `spin_prize.mp3`     | roleta para no prêmio                               | 0,6–1 s   |
| `victory.mp3`        | fase vencida                                        | 1,5–3 s   |
| `defeat.mp3`         | fase perdida / corrida do Modo Recorde encerrada    | 1–2 s     |
| `button_tap.mp3`     | toque em botão do jogo e em fase do mapa            | 30–80 ms  |
| `coins.mp3`          | moedas creditadas                                   | 300–600 ms|

Enquanto `select`, `invalid_swap` e `button_tap` não existirem, o jogo usa o
clique e o alerta do próprio sistema nesses pontos — quando o arquivo chegar,
o som do sistema sai sozinho (não tocam os dois).

## Música — `assets/audio/music/<nome>.mp3`

| arquivo     | onde toca                          | duração / laço                     |
|-------------|------------------------------------|------------------------------------|
| `menu.mp3`  | menu, mapa e loja                  | 1–2 min, laço sem emenda audível   |
| `game.mp3`  | dentro da fase e do Modo Recorde   | 1,5–3 min, laço sem emenda audível |

A música toca a 45% do volume dos efeitos (`kMusicVolume`) e para quando o app
vai para o segundo plano.

## Licença

Só arquivos com licença que permita uso comercial e redistribuição dentro do
app. Registre a origem e a licença de cada arquivo nos Créditos
(`creditsBody` em `lib/l10n/app_*.arb`).

## Origem dos efeitos atuais

**Do Kenney.nl (CC0, domínio público)**: oito efeitos de interface e impacto.
Convertidos de `.ogg` com silêncio inicial cortado, mono 44,1 kHz, pico
normalizado em -1,5 dBFS, MP3 160 kbps.

| arquivo              | pacote Kenney      | arquivo original           |
|----------------------|--------------------|----------------------------|
| `select.mp3`         | Interface Sounds   | `select_001.ogg`           |
| `invalid_swap.mp3`   | Interface Sounds   | `error_007.ogg`            |
| `button_tap.mp3`     | Interface Sounds   | `click_001.ogg`            |
| `brush.mp3`          | Interface Sounds   | `scratch_002.ogg`          |
| `spin_tick.mp3`      | Interface Sounds   | `tick_002.ogg`             |
| `obstacle_break.mp3` | Impact Sounds      | `impactGlass_light_002.ogg`|
| `hammer.mp3`         | Impact Sounds      | `impactPunch_heavy_001.ogg`|
| `coins.mp3`          | Casino Audio       | `chips-collide-2.ogg`      |

**Sintéticos (protótipo)**: os outros nove — `fusion`, `combo`, `nine_born`,
`super_nine`, `nova`, `bomb`, `spin_prize`, `victory`, `defeat`. São os sons
musicais e a explosão, que os três pacotes acima não cobrem (o candidato é o
pacote Kenney **Music Jingles**). Foram gerados por `tool/gen_sfx.py` (ondas e
ruído filtrado, sem amostra externa) e convertidos com
`ffmpeg -codec:a libmp3lame -b:a 128k -ac 1`. Mapeamento dos nomes do gerador:
`nine→nine_born`, `win→victory`, `lose→defeat`; os demais têm o mesmo nome.
Rodar o gerador de novo sobrescreveria os do Kenney: converta só os nove.

A música (`music/`) continua vazia.
