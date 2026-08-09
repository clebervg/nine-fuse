import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';

void main() {
  group('fonte empacotada', () {
    // O ponto de empacotar é não depender de rede: se a fonte sumir dos
    // assets, o app cai no padrão do sistema silenciosamente e ninguém nota
    // até ver a tela. Estes testes fazem barulho antes disso.

    test('os arquivos da fonte existem no projeto', () {
      for (final name in const [
        'Nunito-Bold.ttf',
        'Nunito-ExtraBold.ttf',
        'Nunito-Black.ttf',
      ]) {
        final file = File('assets/fonts/$name');
        expect(file.existsSync(), isTrue, reason: '$name não está em assets');
        expect(
          file.lengthSync(),
          greaterThan(10000),
          reason: '$name parece truncado',
        );
      }
    });

    test('a licença acompanha a fonte, como a OFL exige', () {
      final license = File('assets/fonts/OFL.txt');

      expect(license.existsSync(), isTrue);
      expect(license.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });

    test('a fonte está declarada no pubspec com os três pesos', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('family: Nunito'));
      for (final weight in const ['700', '800', '900']) {
        expect(pubspec, contains('weight: $weight'));
      }
    });

    test('nada depende de baixar fonte em runtime', () {
      // google_fonts busca da rede na primeira execução; foi removido de
      // propósito quando a fonte passou a ser empacotada.
      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('google_fonts')),
      );
    });
  });

  testWidgets('a licença fica registrada para a tela de licenças', (
    tester,
  ) async {
    AppFonts.registerLicense();

    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Nunito'))
        .toList();

    expect(
      entries,
      isNotEmpty,
      reason: 'sem registro, estaríamos distribuindo a fonte fora dos termos',
    );
    expect(
      entries.first.paragraphs.map((p) => p.text).join(),
      contains('SIL OPEN FONT LICENSE'),
    );
  });
}
