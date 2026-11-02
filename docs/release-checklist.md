# Checklist de publicação (Semana 1: bloqueadores)

Origem: auditoria técnica de 2026-09-30. Branch de trabalho:
`fix/release-blockers-week1`. Atualize este arquivo a cada item fechado.

## Feito

- [x] **1.1 Manifest Android** (`28feea8`): `INTERNET` e `AD_ID` no manifest
  principal; `SCHEDULE_EXACT_ALARM` removida (o código só agenda com
  `inexactAllowWhileIdle`).
- [x] **1.2 Assinatura de release** (`7aad681`): o Gradle lê
  `android/key.properties` (template em `key.properties.example`).
- [x] **1.3 parcial, App ID Android** (`c802343`): `manifestPlaceholders` por
  build. Debug = ID de teste; release = `ca-app-pub-5525495238538539~6427370565`.
- [x] **1.4 IDs por `--dart-define`**: as unidades de produção saíram do código;
  `ad_ids.dart` lê `ADMOB_{HAMMER,MOVES,COINS,SPIN,BOMB,BRUSH,CONTINUE}_REWARDED` e
  `ADMOB_INTERSTITIAL`. Sem a variável:
  teste em debug/profile e vazio (sem anúncio) em release. Comando no README.
- [x] **1.4 Guard** `tool/check_admob_ids.sh` (`--strict` antes de enviar o iOS).

IDs de produção já criados no AdMob (Android), para passar no build:
- Martelo: `ca-app-pub-5525495238538539/6498774327`
- Roleta: `ca-app-pub-5525495238538539/1562142419`

## Pendente: bloqueia a publicação

- [x] **Keystore de release** criada (`~/upload-keystore.jks`) e
  `android/key.properties` apontando para ela; conferido em 2026-11-02 que o
  `app-release.aab` sai assinado com ela. Fazer backup fora do repositório.
- [ ] **Unidades de produção que faltam (Android):** *movimentos extras* e
  *moedas*. Criar em AdMob > NineFuse (Android) > Unidades de anúncio >
  Premiado e passar em `ADMOB_MOVES_REWARDED` / `ADMOB_COINS_REWARDED`.
  Sem elas, o release fica **sem anúncio** nesses dois funis.
- [ ] **Unidades da Bomba e do Pincel (Android):** criar duas unidades
  *Premiado* e passar em `ADMOB_BOMB_REWARDED` / `ADMOB_BRUSH_REWARDED`. Sem
  elas, esses dois funis ficam **sem anúncio** no release.
- [ ] **Unidade do resgate de derrota (Android):** criar uma unidade
  *Premiado* e passar em `ADMOB_CONTINUE_REWARDED`. Sem ela, o "+5 jogadas"
  por vídeo fica **sem anúncio** no release.
- [ ] **Unidade do intersticial (Android):** criar em AdMob > Unidades de
  anúncio > **Intersticial** e passar em `ADMOB_INTERSTITIAL`. Sem ela o
  release não mostra intersticial (o jogo segue normal).
- [ ] **iOS:** cadastrar o app iOS no AdMob (outro App ID + unidades) e trocar
  `GADApplicationIdentifier` em `ios/Runner/Info.plist:72-73` e as unidades
  iOS. Hoje tudo é ID de teste.
- [x] **Consentimento no código** (1.5): UMP + ATT antes de qualquer anúncio.
- [ ] **Publicar a mensagem do GDPR no AdMob** (Privacidade e mensagens) com os
  textos de `docs/consent-messages.md`; sem isso o formulário nunca abre.
- [ ] **Testar o formulário em aparelho** com `ConsentDebugSettings` (região UE).
- [ ] **Política de privacidade:** textos prontos (`docs/privacy_policy*.md` e
  `docs/privacy/*.html`). Falta preencher os campos entre colchetes, hospedar
  em URL público e passar `--dart-define=PRIVACY_POLICY_URL=...` no build.
- [ ] **Play Console:** declarar o uso do ID de publicidade (por causa de
  `AD_ID`); ativar o Play App Signing.
- [x] **Identificadores** (não mudam depois de publicar): Android e iOS agora
  usam `com.game.ninefuse` (antes `com.game.nine_fuse` e `com.game.nineFuse`).
  Falta só confirmar que o ID está livre ao criar o app no Play Console.

## Pendente: depois de publicar

- [ ] **Vincular o app à loja no AdMob** (Configurações do app > Vincular à
  loja), nas duas plataformas. App ID e unidades continuam os mesmos.
- [ ] **Profile build:** herda do release e leva o App ID de produção. Quando
  todas as unidades forem de produção, revisar para que profile não peça
  inventário real.

## Pendente: P0 de produto (não são bloqueios de build)

- [ ] Firebase (projeto próprio, separado do AdMob): analytics e crash
  reporting. Nada no `pubspec.yaml` ainda.
- [ ] Onboarding nas fases 1 a 3.

## Dívida conhecida, anterior ao trabalho

- 6 testes falham em `flutter test` (947 passam), todos golden/contraste:
  `board_golden_test`, `hud_golden_test` (3), `juice_golden_test`,
  `tile_contrast_test`. Confirmado que já falhavam sem as mudanças da
  Semana 1; causa não investigada (suspeita: paleta alterada sem regerar
  goldens; o `digit3` em `app_colors.dart` é `0xFF8BC34A`, diferente do
  CLAUDE.md).
- `flutter analyze`: 1 info, `avoid_print` em `tool_tmp/probe124.dart:6`
  (arquivo versionado que deveria sair do repositório).
- A auditoria do **loop de jogo** não foi concluída (agente interrompido).
