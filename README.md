# 🧩 Nine Fuse — 3D Casual Match-3 Puzzle Game

![Nine Fuse Banner](assets/images/app_icon.png)

**Nine Fuse** é um jogo mobile de puzzle casual desenvolvido em **Flutter** com arquitetura reativa moderna (**Riverpod**). O objetivo do jogo é combinar blocos numéricos em um tabuleiro $8 \times 8$ até alcançar e fundir os lendários **Blocos 9**, desimpedindo obstáculos e acumulando pontuações máximas em dois modos de jogo distintos.

---

## 🌟 Destaques & Qualidade Visual (AAA Casual Style)

* **Estética 3D Rich Glossy:** Interface com acabamento *Toy/Candy Glossy*, iluminação volumétrica, bordas chanfradas, efeito *Frosted Glass* e reflexos especulares estilo *Royal Match / Toy Blast*.
* **Mecânica de Fusão "Nova 9":** O ápice do jogo ocorre na combinação de 3 ou mais peças numéricas máximas (Blocos 9), ativando o evento **Supernova** com animações de implosão, limpeza de área no tabuleiro, recompensa em moedas e drops de boosters.
* **Feedback Sensorial Robusto (Juice FX):** Sistema de efeitos visuais e táteis com *screen shake*, partículas dinâmicas e vibração háptica em tempo real.

---

## 🎮 Modos de Jogo & Mecânicas

### 🗺️ Modo Campanha (Saga Map)
* Progressão baseada em níveis com objetivos específicos (ex: criar $N$ peças do valor $X$, eliminar obstáculos).
* Limite de jogadas por fase com sistema de pontuação até 3 estrelas.

### ♾️ Modo Recorde (Endless / Infinito)
* Modo de alta rejogabilidade com busca pela maior pontuação histórica.
* Curva de dificuldade dinâmica e gerenciamento constante do tabuleiro.

### 🧱 Obstáculos do Tabuleiro
* **Gelo (Ice):** Peça congelada que precisa de combinações adjacentes para ser libertada.
* **Vidro (Glass):** Placa translúcida com níveis de trinca até ser destruída.
* **Pedra (Stone):** Rocha opaca e resistente que exige múltiplos impactos ou uso de boosters.

---

## 🧰 Sistema de Boosters

 O jogo conta com 3 boosters integrados à arquitetura de estado e gerenciados por uma camada generalizada de mira/seleção:

1. **🔨 Martelo (Hammer):** Destrói uma única célula direcionada no tabuleiro (bloco ou obstáculo).
2. **💣 Bomba (Bomb):** Provoca uma explosão em área $3 \times 3$, limpando blocos e causando dano massivo em obstáculos.
3. **🖌️ Pincel (Brush):** Incrementa o valor de um bloco numérico em $+1$, permitindo fechar combos e fusões estratégicas.

---

## 🔁 Mecânicas de Retenção & Economia

* **🎡 Daily Spin (Roleta Diária):** Modal estilo *Frosted Glass* com 8 fatias de prêmios (moedas e boosters). Conta com 1 giro grátis a cada 24 horas e opção de giro extra via vídeo recompensado.
* **🔔 Notificações Locais (`flutter_local_notifications`):** Agendamento de lembretes automáticos para o giro diário disponível (+24h) e retorno por inatividade (+72h).
* **💰 AdMob & Unidades Recompensadas:** Sistema de anúncios integrado via portas testáveis (`AdMobRewardedPort`), garantindo recompensa em moedas e boosters.

---

## 🏗️ Arquitetura & Stack Tecnológica

* **Framework:** [Flutter](https://flutter.dev) (Dart)
* **Gerenciamento de Estado:** [Riverpod](https://riverpod.dev) (`StateNotifier` / `Providers`)
* **Persistência Local:** `GameStorage` (`SharedPreferences` em produção / `InMemory` para testes)
* **Assets & Rendering:** `TileSpriteManager` com carregamento otimizado de sprites em memória.
* **Ícones de Plataforma:** `flutter_launcher_icons` configurado para iOS e Android.

### 🏛️ Organização de Pastas
```text
lib/
├── core/                  # Serviços globais, notificações, áudio e anúncios
│   ├── ads/               # Providers e portas de integração AdMob
│   ├── assets/            # Gerenciador central de sprites e recursos
│   └── notifications/     # Serviço e portas de Notificações Locais
├── features/
│   └── game/
│       ├── domain/        # Regras puras de jogo, MatchEngine, modelos e enums
│       ├── presentation/  # Widgets de UI, tabuleiros, overlays e dialogs
│       └── providers/     # StateNotifiers (GameNotifier, EndlessNotifier, Wallet)
└── l10n/                  # Arquivos de internacionalização (ARBs PT/EN)