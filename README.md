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

---

## 🚀 Build de release (Android)

### Pré-requisitos
1. **Keystore de upload** e `android/key.properties` preenchido (modelo em `android/key.properties.example`). Sem ele o release cai na chave de **debug**, que a Play Store recusa.
2. **IDs das unidades de anúncio de produção**, uma por funil, criados no AdMob (tipo *Premiado*, e uma do tipo *Intersticial*).

### Comando
```bash
flutter build appbundle --release \
  --dart-define=ADMOB_HAMMER_REWARDED=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_MOVES_REWARDED=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_COINS_REWARDED=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_SPIN_REWARDED=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_INTERSTITIAL=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
```
O build de iOS usa os mesmos nomes de variável, com as unidades da app iOS.

> **Esquecer uma variável não quebra o build**: o funil correspondente fica sem anúncio (ID vazio) no release. Por isso rode o guard abaixo e confira a assinatura antes de enviar.

### Antes de enviar
```bash
tool/check_admob_ids.sh            # falha se houver ID de teste onde não deve
tool/check_admob_ids.sh --strict   # também falha com pendências (ex.: iOS em teste)
tool/check_admob_ids.sh --defines "$BUILD_FLAGS"  # falha se alguma unidade ficou sem --dart-define
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```
O `Owner` da assinatura não pode ser `CN=Android Debug`.

### App ID (não passa por `--dart-define`)
O SDK lê o **App ID** do manifesto nativo, não do Dart:
- **Android:** `manifestPlaceholders["admobAppId"]` em `android/app/build.gradle.kts` (debug = ID de teste, release = ID de produção).
- **iOS:** `GADApplicationIdentifier` em `ios/Runner/Info.plist` (hoje ainda é o ID de teste).

### Debug e profile
Sem as variáveis, debug e profile usam os IDs de **teste** do Google. Nunca use unidades de produção em build de desenvolvimento: conta como tráfego inválido.

---

## 🔒 Política de privacidade

O texto-base está em `docs/privacy_policy.md` (PT) e `docs/privacy_policy.en.md` (EN), e as versões web prontas para hospedar em `docs/privacy/index.html` e `docs/privacy/en.html`. **Preencha os campos entre colchetes** (nome, e-mail de contato, data) antes de publicar, e revise com um advogado se o app crescer: o texto descreve o app como está hoje (somente AdMob).

A Play Store exige uma **página web pública com HTTPS** (não PDF, sem login), e o mesmo link dentro do app.

### Onde hospedar
- **GitHub Pages** (recomendado): repositório **público** de uma organização do estúdio, `ORG.github.io`, uma pasta por app (`/ninefuse/privacy/`). Mantém histórico e aceita domínio próprio depois.
- **Google Sites** / **Notion** (publicar na web): sem código, porém cada atualização é manual.

O URL não deve mudar depois de publicado: ele fica gravado no Play Console, na App Store e no app.

### Ligar o link no app
O endereço entra no build, junto com os IDs de anúncio:
```bash
--dart-define=PRIVACY_POLICY_URL=https://ORG.github.io/ninefuse/privacy/
```
Sem a variável, o item "Política de Privacidade" não aparece na caixa de privacidade (ícone na barra do mapa), e o release **não é publicável**.

Os textos de consentimento (UMP/ATT) e as declarações do Play Console estão em `docs/consent-messages.md`.
