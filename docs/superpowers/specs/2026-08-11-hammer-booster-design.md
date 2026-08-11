# Booster "Martelo de Fusão" (`HammerBooster`) — Design

Data: 2026-08-11

## Objetivo

Dar ao jogador uma saída paga para o tabuleiro que não colabora: um golpe que
oblitera uma célula inteira — peça **e** cobertura de obstáculo — sem gastar
movimento. É o primeiro booster do NineFuse e, por isso, também é o primeiro
funil de conversão do jogo.

## Regra mecânica

O golpe é do motor, não do notifier:

```dart
/// Oblitera a célula inteira (peça + cobertura) e reassenta o tabuleiro.
/// Nulo se a posição é inválida ou vazia — o notifier usa isso como recusa.
Resolution? smash(Board board, Position at)
```

Sequência: limpa a célula → `applyGravity` → `refill` → `resolve()`.

**O golpe não funde nada.** O dígito destruído não evolui, não pontua e não
conta como fusão. Mas a queda que ele provoca pode formar combinações por
acidente, e essas **resolvem normalmente** — pontuam e contam para o objetivo.
Deixá-las paradas no tabuleiro criaria um estado que o motor não permite em
nenhum outro caminho: três peças alinhadas e inertes, esperando o jogador
tocar em qualquer coisa. O jogador leria isso como bug, não como regra.

**O golpe não gasta movimento.** `movesLeft` é intocado — é o que o jogador
está comprando. Como consequência, o desfecho da fase é reavaliado depois do
golpe pelas mesmas regras de sempre (vitória antes das derrotas), porque uma
cascata incidental pode cumprir o objetivo, e a queda pode travar o tabuleiro.

**Recusa não cobra.** Posição fora do tabuleiro ou célula vazia devolve
`null`, e o notifier faz early-return com feedback tátil sem consumir o
martelo. Mira também é recusada com a fase encerrada ou durante a encenação
(`isResolving`) — pelo mesmo motivo que `swapTiles` recusa: jogar por cima da
animação embaralha o que o jogador está vendo com o que já aconteceu.

## Estado

`GameState` ganha três campos:

- `hammerCount` (int) — inventário. Vive no estado da fase, e não num notifier
  separado, para não haver duas fontes de verdade: a UI lê o saldo do mesmo
  lugar de onde a regra o consome.
- `isHammerTargeting` (bool) — modo de mira ativo.
- `hammerStrike` (`(Position, int)?`) — onde o golpe caiu e **qual dígito
  morreu**. O dígito precisa viajar no estado porque, quando a UI desenha o
  efeito, a peça já não está no tabuleiro para ser consultada.
- `pendingHammerTarget` (`Position?`) — alvo pré-selecionado no Modo Fantasma,
  aguardando a aquisição.

## Persistência

`GameStorage` ganha `readHammerCount()` / `writeHammerCount(int)`. O
`GameNotifier` carrega no construtor (falha de leitura vale como "zero
martelos", pelo mesmo princípio do progresso de campanha: perder inventário é
ruim, travar o jogo é pior) e grava a cada mudança de saldo.

O saldo **sobrevive a `startLevel`**: é inventário do jogador, não da fase.

## Ações do notifier

- `toggleHammerTargeting()` — liga/desliga a mira, com
  `HapticFeedback.selectionClick()` ao ligar (injetável, como
  `explosionFeedback` já é, para a suíte não depender de canal nativo).
- `cancelHammerTargeting()` — desliga a mira e descarta o alvo pendente.
- `useHammer(Position)` — aplica o golpe conforme a regra acima.
- `grantHammer()` — credita 1 martelo e, se havia alvo pendente, aplica o
  golpe nele imediatamente.

## Funil de monetização (zero martelos)

Tocar o martelo com `hammerCount == 0` entra no **Modo Fantasma**: a mira
funciona igual. Ao tocar uma peça, o alvo é guardado em
`pendingHammerTarget` e a tela abre o `HammerOfferDialog`.

O anúncio é uma costura injetável (`Future<bool> Function()`), porque o projeto
não tem SDK de anúncio. O modal tem **um** caminho — "Assistir Ad para ganhar 1
Martelo". Não há botão de moedas: o jogo não tem economia de moedas, e um botão
desabilitado na tela comunica menos do que sua ausência.

Se o anúncio conclui, `grantHammer()` credita e aplica no alvo já destacado —
o jogador vê a peça que escolheu quebrar sem ter que mirar de novo.

## UI

- **Botão no `LevelBanner`**, junto das métricas de movimento e objetivo — o
  HUD que já está no campo de visão de quem joga. Reusa `GameButton`.
- Durante a mira o botão vira **"CANCELAR (X)"** em vermelho.
- **Scrim escurecido** sobre a tela durante a mira, tocável para cancelar, com
  o tabuleiro recortado fora dele — cancelamento explícito por dois caminhos.
- **`ShatterEffect`** novo em `juice_overlay.dart`, reusando o
  `_ParticlePainter` (que já aceita `tint`) na cor do dígito destruído,
  alimentado por `state.hammerStrike`.

### Armadilhas herdadas

- **Nada de `Opacity` nem `FadeTransition`** dentro do `TileWidget`: os testes
  de saída de peça e de clarão usam esses tipos como marcadores.
- **Semente fixa nas partículas**, senão nenhum golden se sustenta.

## Testes

Em `game_notifier_test.dart`:

1. Martelo em coordenada inválida ou célula vazia não consome `hammerCount`.
2. Martelo destrói peça **e** cobertura, dispara a gravidade, e **não**
   decrementa `movesLeft` nem conta fusão do dígito destruído.
3. Nenhum limite artificial: com `hammerCount = 3`, três golpes na mesma
   partida funcionam.
4. Mira recusada com a fase encerrada e durante `isResolving`.
5. Modo Fantasma: tocar com saldo zero guarda o alvo e não destrói nada;
   `grantHammer()` então aplica no alvo guardado.
6. Persistência: o saldo é lido no construtor e gravado a cada consumo.
