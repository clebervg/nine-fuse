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
- [x] **1.3 parcial, unidades Android** (`bf657d7`, `b14567a`): produção só em
  release para **martelo** (`.../6498774327`) e **roleta** (`.../1562142419`).

## Pendente: bloqueia a publicação

- [ ] **Gerar a keystore de release** e criar `android/key.properties`
  (passos no `key.properties.example`). Fazer backup fora do repositório.
  Sem ela o release cai na chave de debug, que a Play Store recusa.
- [ ] **Unidades de produção que faltam (Android):** *movimentos extras* e
  *moedas*. Criar em AdMob > NineFuse (Android) > Unidades de anúncio >
  Premiado, e preencher `movesRewarded` e `coinsRewarded` em
  `lib/core/ads/ad_ids.dart` (mesmo padrão `_unit(androidProd: ...)`).
  Enquanto faltarem, o release mostra anúncio de **teste** nesses dois funis.
- [ ] **Guard contra ID de teste em release** (parte 3 do Bloco 1.3): falhar o
  build/CI de release se restar o prefixo `3940256099942544`, nas unidades e
  no manifest mesclado.
- [ ] **iOS:** cadastrar o app iOS no AdMob (outro App ID + unidades) e trocar
  `GADApplicationIdentifier` em `ios/Runner/Info.plist:72-73` e as unidades
  iOS. Hoje tudo é ID de teste.
- [ ] **Consentimento:** UMP (`ConsentInformation`) antes do primeiro
  `preload`; ATT no iOS (`NSUserTrackingUsageDescription` +
  `app_tracking_transparency`) ou só anúncios não personalizados.
- [ ] **Política de privacidade:** não existe arquivo nem link no app.
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
