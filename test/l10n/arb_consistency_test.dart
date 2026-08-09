import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifica os arquivos de tradução **como arquivos**, e não pela classe
/// gerada.
///
/// A classe gerada não serve para isto: uma chave que exista só no template
/// (inglês) compila e roda — o jogador de português simplesmente recebe a
/// frase em inglês, sem erro nenhum, em produção. Nenhum teste de widget veria
/// isso, porque a suíte roda em português com o texto que a tela mostra sendo
/// exatamente o que a asserção espera.
///
/// Estes dois testes são o que garante "nenhuma string quebrada ou nula".
void main() {
  /// As chaves traduzíveis de um ARB.
  ///
  /// As que começam com `@` são metadados (descrição e placeholders), e as
  /// `@@` são do arquivo (o locale). Nenhuma das duas é texto de jogador.
  Map<String, String> messagesOf(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync()) as Map;
    return {
      for (final entry in decoded.entries)
        if (!(entry.key as String).startsWith('@'))
          entry.key as String: entry.value as String,
    };
  }

  final en = messagesOf('lib/l10n/app_en.arb');
  final pt = messagesOf('lib/l10n/app_pt.arb');

  test('os dois idiomas têm exatamente as mesmas chaves', () {
    expect(
      pt.keys.toSet().difference(en.keys.toSet()),
      isEmpty,
      reason:
          'chave em pt sem contrapartida em en — o template é o inglês, '
          'então ela não existe para nenhum outro idioma',
    );

    expect(
      en.keys.toSet().difference(pt.keys.toSet()),
      isEmpty,
      reason:
          'chave sem tradução em pt: o jogador brasileiro veria a frase '
          'em inglês, sem erro nenhum e sem aviso',
    );
  });

  test('nenhuma mensagem é vazia ou só espaço', () {
    for (final bundle in {'en': en, 'pt': pt}.entries) {
      for (final message in bundle.value.entries) {
        expect(
          message.value.trim(),
          isNotEmpty,
          reason: '${bundle.key}: a chave "${message.key}" não tem texto',
        );
      }
    }
  });

  test('o inglês é o template, e portanto o fallback', () {
    final config = File('l10n.yaml').readAsStringSync();
    expect(config, contains('template-arb-file: app_en.arb'));
  });
}
