import 'package:flutter/material.dart';
import 'package:nine_fuse/features/game/domain/game_level.dart';
import 'package:nine_fuse/features/game/presentation/l10n_labels.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/l10n/app_localizations_en.dart';
import 'package:nine_fuse/l10n/app_localizations_pt.dart';

/// Idioma em que a suíte roda por padrão.
///
/// Fixado de propósito, em vez de herdado do sistema: as asserções escritas em
/// português continuam sendo regressão de texto de verdade. Sem isto, elas
/// passariam a afirmar algo sobre o **locale da máquina** — e a mesma suíte
/// passaria neste Mac e quebraria numa máquina de CI configurada em inglês,
/// sem que nada do jogo tivesse mudado.
const Locale kTestLocale = Locale('pt');

/// O outro idioma suportado, para os testes que verificam a tradução.
const Locale kTestLocaleEn = Locale('en');

/// Um `MaterialApp` já localizado, para os testes que não precisam de mais nada.
///
/// Os testes que montam o próprio `MaterialApp` (com tema, observador de
/// navegação ou `ProviderScope`) declaram os mesmos três parâmetros à mão —
/// sem eles, `AppLocalizations.of(context)` não acha delegate e o widget nem
/// constrói.
Widget localizedApp({required Widget home, Locale locale = kTestLocale}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// As traduções de um idioma, sem precisar de árvore de widgets.
///
/// Serve para o teste comparar contra a **mesma fonte** que a tela usa, no caso
/// dos textos montados com parâmetro ("Crie 3 peças 5"). Reescrever a frase à
/// mão no teste faria a asserção repetir a lógica de montagem — e ela passaria
/// mesmo com o widget montando errado, desde que errasse igual.
///
/// Para título fixo, o teste continua escrevendo o literal: ali a asserção é
/// justamente sobre o texto que o jogador lê.
AppLocalizations l10nFor([Locale locale = kTestLocale]) =>
    locale.languageCode == 'en' ? AppLocalizationsEn() : AppLocalizationsPt();

/// O objetivo como o jogador o lê, no idioma [locale].
String objectiveText(Objective objective, [Locale locale = kTestLocale]) =>
    l10nFor(locale).objectiveLabel(objective);
