# NineFuse: levantamento completo do jogo (atualizado em 2026-11-02)

Documento de passagem para outra IA ajudar na finalização. Descreve **o que
existe hoje no código**, com os números reais, e no fim **o que falta**,
priorizado. Fontes complementares: `CLAUDE.md` na raiz (histórico de
decisões, longo, uma subseção por entrega) e `docs/release-checklist.md`
(bloqueadores de publicação).

> **Estado do repositório:**
> - Branch `feat/observatorio-real-ui`, tudo commitado localmente, sem push e
>   ainda não juntado à `main`. São 11 commits, do redesign à unidade de
>   anúncio do resgate de derrota (ver §16).
> - `flutter analyze` sem nenhum problema; `flutter test` com **1130 testes
>   passando**.
> - O redesign rodou no simulador iOS (iPhone 16 Pro, iOS 18.2) sem erro de
>   log. As etapas seguintes (§16) ainda não foram abertas em simulador nem em
>   aparelho.

---

## 1. Visão geral

| Item | Valor |
|---|---|
| Nome | NineFuse (`com.game.ninefuse`, Android e iOS) |
| Gênero | Puzzle / match-3 lógico com números (Candy Crush + 2048) |
| Versão | `1.0.0+1`, ainda não publicado |
| Plataformas | Android e iOS (macOS/web compilam, mas não são alvo) |
| Idiomas | Português (BR) e Inglês (`lib/l10n/*.arb`); o idioma pode ser escolhido nas Configurações |
| Monetização | Anúncio premiado (8 funis) e intersticial (AdMob). Sem compra in-app |
| Sem trava | Não há sistema de vidas: perdeu, tenta de novo na hora |

**A ideia central:** alinhar 3+ peças iguais faz a peça do meio (a do toque)
**evoluir** para o número seguinte; as outras somem e o topo repõe. O clímax é
chegar ao **9**.

## 2. Stack e arquitetura

- **Flutter / Dart** (SDK ^3.12), **Riverpod 2** (`StateNotifier`).
- Persistência: `SharedPreferences` atrás de `GameStorage` (há
  `InMemoryGameStorage` para testes). Leitura com falha volta ao valor padrão,
  sem travar o jogo.
- Pacotes principais:
  - `flutter_riverpod`, `flutter_animate`, `shared_preferences`,
    `flutter_svg`, `intl`, `url_launcher`;
  - `google_mobile_ads` **9.0.0 pinado** (a 9.1.0 quebra o build iOS);
  - `audioplayers` **6.8.1 pinado**;
  - `flutter_native_splash`;
  - `flutter_local_notifications` + `timezone`;
  - `app_tracking_transparency`.
- Pastas:
  - `lib/core/`: anúncios, consentimento, áudio, vibração (`feedback/`),
    notificações, privacidade, tema (`nf_tokens.dart`, `app_fonts.dart`),
    cores dos dígitos, widgets base.
  - `lib/features/game/domain/`: regras puras em Dart (tabuleiro, motor de
    combinação, fases, gerador, economia, roleta, obstáculos, objetivos,
    configurações, passos do tutorial).
  - `lib/features/game/providers/`: estado (`GameNotifier`, `EndlessNotifier`,
    `Wallet`, recordes da campanha, configurações, tutorial, boosters como
    mixins, armazenamento).
  - `lib/features/game/presentation/`: telas, widgets e efeitos ("juice").
- **Padrão de serviços externos** (anúncios, áudio, tutorial, notificações):
  - uma porta fina para o plugin e um serviço com a decisão, testável em Dart
    puro;
  - em teste, o padrão é desligado ou mudo;
  - quem liga o real é o `main` (ex.: `admobOverrides()`).
- Ferramentas em `tool/`:
  - `simulate_economy.dart`: bot guloso que mede a taxa de vitória por fase,
    com os modos `phases`, `obstacles`, `generated`, `hard`, `efficiency` e
    `both`;
  - `check_admob_ids.sh`: barra ID de teste no release e confere se toda
    unidade está no comando de build do README;
  - `gen_sfx.py`: gera os efeitos sonoros sintéticos;
  - `prepare_icons.dart` e `export_glyph_path.py`: ícones.

**Regras de código do projeto (respeitar):**
- Tabuleiro e peças imutáveis.
- Regra de jogo só em `domain`/`providers`.
- `AnimationController` em vez de `Future.delayed` na UI.
- Toda animação nova tem de ser **finita**, senão `pumpAndSettle` trava a suíte.
- Nada de `Opacity`/`FadeTransition` dentro do `TileWidget` (os testes usam
  esses tipos como marcador).
- Sem sombra de texto dentro de `Transform` animado (bug do Impeller).
- Todo `BackdropFilter` dentro de um `ClipRect`.

## 3. Fluxo de telas

`Splash nativa` → `SplashScreen` (barra de carregamento real, pré-carrega
sprites) → **Menu (Home)** → **Mapa (Saga)** → **Fase**. A Loja, a Roleta e as
Configurações saem do Menu.

1. **Menu inicial** (`home_screen.dart`):
   - logo NINE/FUSE e o medalhão do 9 com peças em órbita;
   - pílulas de moedas (com "+" para a Loja) e de estrelas, e a engrenagem
     das Configurações;
   - LOJA, ROLETA (selo vermelho quando há giro grátis), a pílula
     "Capítulo X · Fase Y / MAPA" e o JOGAR (abre o mapa, que abre a fase
     atual);
   - toca a música do menu.
   - A roleta diária abre sozinha quando o giro está liberado, e o lembrete
     de inatividade é reagendado aqui.
2. **Mapa / trilha** (`level_select_screen.dart`, `saga_map.dart`):
   - **janela deslizante**: monta só 30 fases antes e 8 depois da atual, com
     o marcador "Fases 1–N concluídas" no pé da trilha;
   - caminho dourado no que já foi vencido;
   - fase atual em gema roxa com "VOCÊ ESTÁ AQUI";
   - **baú no fim de cada capítulo** (capítulos 1 a 20), em três estados:
     trancado, pronto (dourado) ou aberto. Tocar no pronto paga 200 moedas
     uma única vez;
   - cabeçalho do capítulo com a barra de estrelas do capítulo;
   - aviso de obstáculo novo quando ele estreia nas próximas 3 fases;
   - destaque do Modo Recorde, liberado após a fase 5;
   - botão fixo "JOGAR FASE N" com o objetivo.
3. **Início de fase** (`level_start_dialog.dart`): objetivo, limite de
   jogadas, dica em texto (8 dicas) e mini-loja de boosters.
4. **Fase** (`game_screen.dart`):
   - HUD numa placa só (pontos com estrelas parciais, medalhão de jogadas no
     centro, objetivo com a peça-alvo);
   - tabuleiro com moldura de ouro e dock de boosters embaixo dele;
   - alerta de jogadas com 5 ou menos;
   - tutorial por cima, nas fases que o têm (§3.1);
   - toca a música da partida.
5. **Vitória** (`level_outcome_card.dart`): raios, 1 a 3 estrelas, pontos e
   moedas ganhas (só por estrela nova). O "Próxima fase" pode mostrar um
   intersticial antes (§9).
6. **Derrota** (`continue_offer_dialog.dart`): "SEM JOGADAS", o que faltou,
   "+5 jogadas" por 100 moedas ou por vídeo, e DESISTIR.
7. **Loja** (`shop_screen.dart`): Martelo, Bomba e Pincel por moeda, e vídeo
   que dá moedas.
8. **Roleta diária** (`daily_spin_dialog.dart`, `prize_wheel.dart`): 8
   fatias, giro de 4,2 s com `Curves.decelerate`, popup de prêmio e contagem
   para o próximo giro.
9. **Configurações** (`settings_screen.dart`):
   - som com volume, música, vibração e idioma (aparelho, pt ou en), tudo
     persistido;
   - "Gerenciar privacidade", que abre o formulário de opções do UMP e só
     aparece onde a lei exige;
   - política de privacidade;
   - "Rever tutorial";
   - créditos e licenças (`showLicensePage`).
10. **Modo Recorde / Endless** (`endless_screen.dart`): partida sem limite de
    jogadas, com recorde salvo.
11. **Modais auxiliares:**
    - convites de Martelo, Bomba e Pincel sem estoque;
    - convite pre-churn de jogadas extras;
    - sugestão de ir ao Modo Recorde após 3 derrotas seguidas;
    - caixa de moedas;
    - popups do baú (recompensa e trancado);
    - política de privacidade.

### 3.1 Tutorial (`tutorial_layer.dart`, `domain/tutorial.dart`)

| Quando | O que mostra |
|---|---|
| Fase 1, primeira jogada | véu com recorte nas duas células, mão animada e balão "Troque estas duas peças". A troca sai das jogadas válidas do tabuleiro sorteado, mas qualquer troca válida é aceita |
| Fase 1, após a fusão | "três 3 viram um 4!" com os valores reais; depois, um lembrete do objetivo apontando o HUD |
| Fase 2 | aponta o medalhão de jogadas; na primeira troca sem trio, avisa que ela não gastou jogada |
| Fase 3, ou a primeira fase com booster nunca usado | aponta o dock e explica o Martelo, sem obrigar a usar |
| Estreia de gelo, vidro e pedra (fases 8, 9 e 10) | balão apontando uma célula coberta |

- Cada passo aparece uma vez por instalação e é marcado como visto quando
  aparece. Fica salvo na chave `tutorial_seen_steps`.
- Todo balão tem "Pular tutorial"; "Rever tutorial" fica nas Configurações.
- A mão faz o gesto algumas vezes e para (animação finita).

## 4. Regras de jogo

### 4.1 Tabuleiro e fusão
- Grade 8x8 de dígitos de 0 a 9, cada um com sua cor (`app_colors.dart`).
- A troca entre vizinhas ortogonais só vale se formar combinação. Troca
  inválida **não gasta** jogada.
- Uma combinação de 3+ faz a peça do toque evoluir (+1) e esvazia as demais;
  depois vem a gravidade e o topo repõe.
- A fusão em "tiers" (`TieredFusion`) faz combinações de 4 ou 5 renderem mais.
- Cascatas: no máximo **4 por jogada** (`CascadeBudget`, regra de jogo).
- **Janela de sorteio**: o topo só gera dígitos dentro de uma faixa de 4
  valores. Ela sobe ao longo da campanha.
- Pontuação com combos ("COMBO x2", "INCRÍVEL xN", "SUPER FUSÃO").
- O fim por falta de troca possível é detectado e explicado (`LossReason`).

### 4.2 Os três clímax
- **Bloco 9:** nasce da fusão de 3 ou 4 peças 8. Fica no tabuleiro e limpa as
  coberturas na vizinhança 3x3, sem remover peças. A fusão de 4 dá bônus de
  pontos.
- **Super 9:** nasce da fusão de 5+ peças 8, no máximo um por vez.
  - Trocado com um vizinho de 0 a 8, converte **todo** aquele valor do
    tabuleiro no valor seguinte.
  - Volta a ser 9 comum depois de 3 jogadas sem uso.
  - Visual próprio: aro roxo e dourado, halo e um selo com as jogadas
    restantes (3, 2, 1).
- **Nova:** run de 3+ peças 9 já existentes. Escala em três tiers:

  | Tier | Peças 9 | Efeito | Pontos extras | Moedas |
  |---|---|---|---|---|
  | 1 | 3 | núcleo 3x3 destrói + anel 5x5 promove +1 | 500 | 10 |
  | 2 | 4 | núcleo 3x3 destrói + anel 7x7 promove +1 | 1000 | 20 |
  | 3 | 5+ | o tabuleiro inteiro | 2000 | 40 |

  - A Nova também dá **+1 Bomba ou Pincel** sorteado, respeitando o teto de 5
    (excedente vira +50 moedas).
  - Limite de 1 Nova por jogada.
  - Peças especiais são imunes à Nova.
- **Tipo reservado e não usado:** `SpecialTileType.wildcard` ("Curinga").

### 4.3 Obstáculos (coberturas)
- **Gelo** cede com 1 fusão encostada, **Vidro** com 2 e **Pedra** com 3 (ou
  com a limpeza 3x3 do 9).
- A peça coberta continua visível, mas não combina e não pode ser trocada.
- O dano é ortogonal, um impacto por passo.
- Coberturas nunca nascem encostadas umas nas outras e nunca são postas se
  tirarem a última jogada possível.
- **Gelo, vidro e pedra caem com a gravidade.** A **Corrente** (desde a fase 31)
  é a cobertura ancorada: a peça combina, mas não troca e não cai; cede a uma
  fusão encostada ou a entrar numa combinação.
- **Formatos de tabuleiro** (desde a fase 12): 8 formatos com casas fora do
  tabuleiro, que quebram sequência e por cima das quais as peças caem.

### 4.4 Objetivos de fase
- `reachDigit`: crie N peças de dígito X.
- `clearObstacles`: quebre N gelos, vidros ou pedras.
- `clearAllObstacles`: limpe toda a cobertura de um tipo.
- `collectDigit`: funda N peças de dígito X (conta a peça que entra na fusão).
- Se a jogada final cumpre o objetivo, isso vale como vitória mesmo zerando
  as jogadas.

### 4.5 Estrelas
- 1 a 3 estrelas por fase.
- Cada **estrela nova** paga 10 moedas. Rejogar uma fase não farma moedas.

## 5. Campanha

- **10 fases feitas à mão** (`game_level.dart`):

  | Fase | Objetivo | Jogadas | Janela | Obstáculos |
  |---|---|---|---|---|
  | 1 | um 4 | 6 | padrão | nenhum |
  | 2 | três 4 | 10 | padrão | nenhum |
  | 3 | um 5 | 10 | padrão | nenhum |
  | 4 | dois 5 | 15 | padrão | nenhum |
  | 5 | três 5 | 21 | padrão | nenhum |
  | 6 | um 6 | 45 | padrão | nenhum |
  | 7 | dois 6 | 14 | 1-4 | nenhum |
  | 8 | um 7 | 45 | 1-4 | 3 gelos |
  | 9 | um 8 | 45 | 2-5 | 2 gelos, 2 vidros |
  | 10 | um 9 | 45 | 3-6 | 2 vidros, 2 pedras |

- **Campanha infinita** a partir da fase 11 (`level_generator.dart`). Cada fase
  é função pura do número dela, e o tabuleiro é sorteado a cada tentativa.
  - Blocos de 10 fases = 1 capítulo.
  - Contagem do objetivo até 6; até 7 obstáculos.
  - Movimentos calculados pela distância até a janela, com piso de 10 (ou de
    16 nas fases de dígito pesado).
  - Aperto de 2% por bloco, com piso de 75%, e pacing alternado (±12%).
  - Anti-repetição: nenhuma fase repete o objetivo das 2 anteriores.
  - Formato recortado nas posições 1, 4, 7 e no fecho; "Funda N" nas posições
    3 e 6; fecho de capítulo rotativo (limpe tudo, coleta, dez 9, coleta acima
    da janela); Corrente a partir da fase 31. Fases 200-1000: 118 contratos
    distintos (eram 31).
  - **Fases "hard"** a partir da fase 30 (penúltima de cada bloco): 25% menos
    jogadas e o dobro de obstáculos.
- **Capítulos:** fases 1-6 = cap. 1, 7-10 = cap. 2, e depois de 10 em 10.
- Para não crescer sem fim, o histórico de recordes é podado; a marca
  `prunedBelow` impede ganhar duas vezes as moedas de uma fase podada.

## 6. Modo Recorde (Endless)

- Liberado depois da **fase 5**.
- Sem limite de jogadas: a corrida acaba quando não há troca possível.
- A janela de sorteio sobe por habilidade (ao criar uma peça 2 níveis acima do
  topo), com 4 degraus, e os obstáculos entram ao subir de degrau.
- O recorde é persistido.
- Depois de **3 derrotas seguidas** na mesma fase, o jogo sugere o Modo
  Recorde (a contagem fica só em memória).
- Não mostra intersticial: o fim da corrida conta como derrota.

## 7. Boosters

O estoque fica no `GameState`, é persistido e é compartilhado entre Campanha e
Endless.

| Booster | Efeito | Preço (moedas) | Outras fontes |
|---|---|---|---|
| **Martelo** | destrói 1 célula (peça + cobertura); não gasta jogada | 100 | vídeo (máx. 3 por dia), roleta |
| **Bomba** | destrói uma área 3x3 | 150 | vídeo, roleta, Nova |
| **Pincel** | +1 no valor de uma peça | 100 | vídeo, roleta, Nova |

- Cada booster tem modo de mira:
  - véu com blur e célula destacada;
  - o golpe sai ao levantar o dedo, e tocar fora cancela;
  - erro de mira não cobra.
- Os efeitos são tranco de 100 ms, partículas na cor da peça e som próprio.
- **Modo Fantasma:** sem estoque, o jogador mira primeiro e depois abre o
  convite (vídeo ou moeda) com o alvo guardado.
- **Teto de 5 por booster em prêmio grátis** (roleta e Nova). O excedente vira
  +50 moedas por unidade. Compra e anúncio não têm teto. Estoque antigo acima
  de 5 não é cortado.
- **Martelo por vídeo:** no máximo 3 por dia, pela data local, persistido.
  Depois disso o botão de vídeo fica apagado ("Volte amanhã para mais
  vídeos") e a compra com moeda continua.

## 8. Economia de moedas (`domain/economy.dart`)

| Constante | Valor | Significado |
|---|---|---|
| `kCoinsPerStar` | 10 | por estrela nova |
| `kChapterChestReward` | 200 | baú por capítulo, capítulos 1-20, uma vez cada |
| `kCoinsPerRewardedAd` | 25 | vídeo de moedas |
| `kHammerCoinPrice` / `kBrushCoinPrice` | 100 | preço |
| `kBombCoinPrice` | 150 | preço |
| `kContinueCoinPrice` / `kContinueBonusMoves` | 100 / +5 | resgate na derrota |
| Pre-churn (DEM) | 4 a 10 jogadas | 3 por alvo restante; abre com 2 jogadas restantes, uma vez por tentativa |
| `kMaxBoosterStock` / `kCoinsPerOverflowBooster` | 5 / 50 | teto de prêmio grátis |
| `kMaxHammerAdsPerDay` | 3 | martelos por vídeo por dia |
| Nova | 10 / 20 / 40 | moedas por tier |

- **Roleta diária:** um giro a cada 24 h. As 8 fatias são:
  10, Martelo, 25, Bomba, 50, Pincel, 100 e 200 moedas.
- **Teto de moeda vitalícia via baú:** 20 × 200 = 4000.

## 9. Anúncios, consentimento, notificações e privacidade

- **AdMob premiado**, com 8 unidades, cada uma com a sua variável de build:

  | Funil | Variável |
  |---|---|
  | Martelo | `ADMOB_HAMMER_REWARDED` |
  | Jogadas pre-churn | `ADMOB_MOVES_REWARDED` |
  | Moedas | `ADMOB_COINS_REWARDED` |
  | Roleta | `ADMOB_SPIN_REWARDED` |
  | Bomba | `ADMOB_BOMB_REWARDED` |
  | Pincel | `ADMOB_BRUSH_REWARDED` |
  | Resgate de derrota | `ADMOB_CONTINUE_REWARDED` |
  | Intersticial | `ADMOB_INTERSTITIAL` |

  - O jogo fala com o SDK por `RewardedAdPort`. O `RewardedAdService` faz
    preload no início da fase e repõe o estoque de anúncios.
  - Fechar o vídeo antes do fim não paga.
  - Sem a variável, o debug usa o ID de teste oficial do Google e o release
    fica sem anúncio naquele funil.
  - Até esta rodada, Bomba, Pincel e o resgate de derrota **não passavam pelo
    AdMob** e pagavam sem anúncio no release. Corrigido.
- **Intersticial** (`interstitial_ad_service.dart`):
  - aparece só no "Próxima fase" da vitória ou na saída de uma fase para o
    mapa;
  - **nunca na derrota**, nunca no meio da partida e nunca antes de o jogador
    vencer a fase 3;
  - exige 45 s de **jogo** desde o último (o relógio só corre com a partida
    rolando e o app visível);
  - sem anúncio carregado, pula a oportunidade sem segurar a navegação;
  - `adsRemovedProvider` (hoje sempre falso) é o gancho para o futuro
    No-Ads Pass.
- A música pausa durante qualquer anúncio de tela cheia.
- **Consentimento:** UMP (GDPR) e, no iOS, ATT **antes** de inicializar o SDK.
  O jogador pode revê-lo nas Configurações.
- **Notificações locais:**
  - lembrete da roleta 24 h depois do giro;
  - lembrete de inatividade 72 h depois da última abertura.
- **Privacidade:** política em `docs/privacy_policy*.md` e
  `docs/privacy/*.html`, com diálogo no app. A URL é passada por
  `--dart-define=PRIVACY_POLICY_URL`.

## 10. Visual, arte e áudio

- **Direção "Observatório Real"**, das 7 telas do Claude Design:
  - céu azul-noite com estrelas paradas;
  - ouro marca o que é tocável, roxo marca o que é mágico;
  - os tokens ficam em `nf_tokens.dart`;
  - botão de vídeo premiado sempre roxo (gema), verde reservado para dinheiro
    real.
- **Fontes:** Lilita One (títulos), Baloo 2 (números) e Nunito (texto). Todas
  vêm empacotadas.
- **Sprites "candy pop":** peças 0-9 e obstáculos por HP, ícones dos boosters
  e moeda, splash 1290x2796 e ícone adaptativo.
- **O baú usa ícone Material**, porque não há arte de baú.
- **Juice:**
  - pulo/squash da peça, partículas, estilhaços por material, combos e pontos
    flutuantes;
  - celebração da fusão máxima, tranco de tela, hitstop da Nova;
  - prioridade dos efeitos via `JuiceDirector`.
- **Áudio** (`lib/core/audio/`, `audioplayers`):
  - 17 efeitos ligados aos eventos do jogo: seleção, troca inválida, fusão,
    combo, 9, Super 9, Nova, quebra de obstáculo, Martelo, Bomba, Pincel,
    tique e prêmio da roleta, vitória, derrota, botão e moedas;
  - na cascata, só um som por passo, escolhido por prioridade;
  - **os efeitos atuais são sintéticos, de protótipo** (`tool/gen_sfx.py`,
    MP3 mono, cerca de 170 KB no total);
  - **não há música:** `assets/audio/music/` está vazio. O código já toca
    `menu.mp3` e `game.mp3` quando existirem;
  - nomes, formato e volume esperados em `assets/audio/README.md`; arquivo
    ausente fica mudo, sem erro.
- **Vibração** centralizada em `lib/core/feedback/haptics.dart`, obedecendo
  ao interruptor das Configurações.

## 11. Qualidade

- 1130 testes passando: unidade (motor, gerador, economia, anúncios, áudio,
  tutorial), widget e golden.
- São 6 goldens: board, hud, hud_urgent, juice_fusion, level_outcome e
  saga_map. Os sprites aparecem em branco nos goldens (limitação conhecida e
  aceita).
- A calibragem de dificuldade é **medida** com o simulador, nunca escolhida
  "no olho". As tabelas estão no `CLAUDE.md`.
- Compilaram nesta rodada: iOS debug (simulador), APK debug,
  **`app-release.aab` (63,7 MB)**, assinado com a chave de upload, e
  **iOS release sem assinatura** (`Runner.app`, 38,1 MB).
- O `.aab` gerado foi compilado **sem** as variáveis `--dart-define` dos
  anúncios, então está sem anúncio em todos os funis. Para subir na loja,
  recompile com o comando do `README.md`.

## 12. Estado de publicação (`docs/release-checklist.md`)

**Feito:**
- manifest Android;
- assinatura via `key.properties`, **com a keystore de upload já criada**
  (fora do repositório, em `~/upload-keystore.jks`; faça backup);
- App ID de produção do Android;
- IDs de anúncio por `--dart-define`, com guard (`tool/check_admob_ids.sh`);
- consentimento UMP e ATT no código, com revisão pelo jogador;
- identificador `com.game.ninefuse`;
- descrição real no `pubspec.yaml`.

**IDs de produção que já existem (Android):** Martelo e Roleta.

**Bloqueia a publicação (só o dono pode fazer):**
1. Criar no AdMob (Android) as unidades premiadas de **jogadas, moedas,
   bomba, pincel e resgate**, e a unidade **intersticial**. Sem elas, esses
   funis ficam sem anúncio no release, mas o jogo funciona.
2. iOS: cadastrar o app no AdMob, trocar o `GADApplicationIdentifier` no
   `Info.plist` e criar as unidades. **Hoje o iOS só tem IDs de teste.**
3. Publicar a mensagem GDPR no AdMob e testar o formulário em aparelho (UE).
4. Política de privacidade: preencher os campos entre colchetes, hospedar em
   URL público e passar a URL no build.
5. Play Console:
   - criar o app e ativar o Play App Signing (a chave de upload já existe);
   - classificação etária, segurança de dados e declaração do ID de
     publicidade;
   - capturas de tela e textos da ficha (os textos já estão no ARB:
     `storeSubtitle`, `storeFullDescription`...).
6. **Atenção ao prazo:** conta pessoal do Google Play criada depois de
   nov/2023 exige teste fechado com 12+ testadores por 14 dias antes da
   produção. A trilha de teste interno não tem essa exigência. A revisão da
   App Store leva de 24 a 48 h.
7. Depois de publicar: vincular o app à loja no AdMob.

## 13. O que falta ou está incompleto (priorizado)

### P0: antes de publicar
1. **Bloqueadores da §12** (dependem do dono).
2. **Testar em aparelho real** (iPhone e Android, incluindo um de entrada):
   - desempenho do blur dos modais, da mira e do tutorial;
   - posição dos balões e da mão do tutorial;
   - os sons tocando de fato (o caminho nativo do `audioplayers` só foi
     compilado, nunca ouvido);
   - intersticial e premiados reais com IDs de teste;
   - o aro do Super 9 sobre o sprite real da peça.
3. **Juntar a branch na `main`** depois da revisão.

### P1: esperado de um jogo publicado
4. **Áudio definitivo:** trocar os 17 efeitos sintéticos por efeitos de
   verdade (ex.: Kenney.nl, CC0) e criar ou licenciar as duas músicas, com os
   nomes de `assets/audio/README.md`.
5. **Analytics e crash reporting** (Firebase Analytics + Crashlytics). Não há
   nada. Precisa de projeto Firebase próprio, `google-services.json` e
   `GoogleService-Info.plist`. Sem isso não dá para calibrar com jogadores
   reais (funil por fase, uso de boosters, conversão de anúncio).
6. **Salvamento na nuvem / conta:** o progresso vive só no
   `SharedPreferences` e se perde ao desinstalar. Opções: Play Games Services /
   Game Center (que também dão placar e conquistas) ou backend próprio.
7. **Arte do baú** (hoje é um ícone Material).
8. **Versão do app nos Créditos:** não aparece, porque o projeto não tem
   `package_info_plus`.

### P2: monetização
9. **Compra in-app (billing):**
   - No-Ads Pass (gancho `adsRemovedProvider` já existe), com o bônus diário
     VIP de +50 moedas por dia;
   - pacotes de moedas e o "Baú Real" do design;
   - a Loja já tem o espaço, e o verde (`NfColors.buyGreen`) está reservado.
   - Precisa de produtos cadastrados nas lojas.
10. ~~Recompensa diária de login~~: feita (2026-11-03), com sequência de 7
    dias e três missões diárias. Ver `CLAUDE.md`.

### P3: conteúdo, balanceamento e dívida técnica
11. ~~Obstáculo ancorado~~: feito como a Corrente (2026-11-03), com sprite próprio.
12. **Peça Curinga** (`wildcard`): reservada, sem efeito.
13. **Fases de pedra em janela alta** (ex.: fases 108 e 1000) ficaram com
    35-40% de vitória para o bot depois da troca para o Bloco 9. Avaliar
    subir `kObstacleMovesPerUnit`.
14. **Gerador:** os objetivos `digit = spawnMax + 2` (posições ímpares do
    bloco) têm custo cerca de 5x maior que os de `+1`. A fórmula do objetivo
    precisa de revisão.
15. **Conteúdo novo:** eventos, missões diárias, conquistas, placar global do
    Modo Recorde, novos obstáculos e novos boosters. Nada disso existe.
16. **Acessibilidade:** há `Semantics` em vários pontos, mas nunca houve
    auditoria com VoiceOver/TalkBack. Faltam alto contraste/daltonismo,
    escala de fonte e redução de movimento.
17. **"Rever tutorial"** só traz os balões das fases 1 a 3 se o jogador
    rejogar essas fases.

## 14. Decisões de produto que não devem ser desfeitas sem conversar

- Preços e prêmios valem os do código; os números do design eram
  placeholder.
- Botão de vídeo premiado é sempre roxo (gema); verde só para dinheiro real.
- O "+" das moedas abre a Loja no menu e no mapa, e a caixa de moedas dentro
  da partida. A Loja grava estoque direto no disco, e dentro da partida a
  autoridade é o `GameState`.
- O JOGAR do menu abre o mapa, não a fase, para "Voltar às fases" cair na
  trilha.
- Modo Fantasma no estoque zero (mirar antes de pagar).
- O 9 não se consome (Bloco 9); só a Nova consome peças 9.
- Sem vidas e sem espera para jogar.
- Fase é função pura do número; o tabuleiro é sorteado a cada tentativa, para
  que não dê para decorar a solução.
- Intersticial nunca na derrota nem no onboarding.
- Teto de booster só em prêmio grátis; o que o jogador pagou nunca é recusado.
- O tutorial nunca recusa uma jogada válida.

## 15. Como rodar

```bash
flutter pub get
flutter run                     # simulador/aparelho (reinstale ao trocar assets de áudio)
flutter analyze                 # deve ficar limpo
flutter test                    # 1130 testes
dart run tool/simulate_economy.dart --mode=both   # calibragem
bash tool/check_admob_ids.sh    # guarda dos IDs de anúncio
```

O comando completo de release, com todas as variáveis `--dart-define`, está no
`README.md`.

## 16. Histórico desta rodada (branch `feat/observatorio-real-ui`)

| Commit | O que entrou |
|---|---|
| `8f28b44` | redesign das 7 telas, roleta nova, teto de booster na roleta |
| `228eadf` | baú de capítulo pago na trilha, teto na Nova, visual do Super 9 |
| `d35d1c5` | tela de Configurações, serviço de áudio, vibração centralizada |
| `afdccd6` | 17 efeitos sonoros sintéticos |
| `f8b9c9e` | intersticial com as regras de monetização |
| `6312559` | limite de 3 martelos por vídeo ao dia |
| `279e245` | unidades de anúncio da Bomba e do Pincel |
| `ecfdb53` | mapa em janela deslizante |
| `068a7fc` | descrição real no `pubspec.yaml` |
| `c635eab` | tutorial interativo das fases 1-3 e estreias de obstáculo |
| `918a88e` | merge das duas frentes paralelas |
| `afef4c2` | unidade de anúncio do resgate de derrota |
