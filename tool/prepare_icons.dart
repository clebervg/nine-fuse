// Prepara os mestres de ícone a partir de assets/images/logo.png.
//
// O logo tem cantos arredondados e transparentes, o que serve para a UI mas
// não para as lojas:
//
//   - **iOS não aceita transparência** em ícone de app. A Apple rejeita o
//     envio, e mesmo que passasse o sistema desenharia preto nos cantos. O
//     ícone precisa ser um quadrado opaco; o arredondamento quem aplica é o
//     iOS.
//   - **Android 8+ usa ícone adaptativo**, com frente e fundo separados. O
//     sistema recorta a frente em círculo, quadrado ou outras máscaras
//     conforme o aparelho, então a arte tem de caber na zona segura central —
//     66% do quadro. Mandar o logo inteiro faria o recorte comer as bordas.
//
// Uso: dart run tool/prepare_icons.dart
//
// Depois: dart run flutter_launcher_icons

// Ferramenta de linha de comando: aqui o print é a saída do programa.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart';

/// Zona segura do ícone adaptativo: o sistema pode recortar tudo fora dela.
const double _adaptiveSafeFraction = 0.66;

void main() {
  final source = File('assets/images/logo.png');
  if (!source.existsSync()) {
    print('ERRO: assets/images/logo.png não encontrado.');
    exit(1);
  }

  final logo = decodePng(source.readAsBytesSync());
  if (logo == null) {
    print('ERRO: não consegui decodificar o logo.');
    exit(1);
  }

  print('logo: ${logo.width}x${logo.height}');

  final background = _dominantOpaqueColor(logo);
  final hex = '#${_hex(background.r)}${_hex(background.g)}${_hex(background.b)}';
  print('cor de fundo detectada: $hex');

  _write(
    'assets/icon/app_icon.png',
    _flatten(logo, background),
    'quadrado opaco (iOS e loja)',
  );

  _write(
    'assets/icon/app_icon_foreground.png',
    _insetForAdaptive(logo),
    'frente do adaptativo (Android)',
  );

  // A ficha da Play Store pede um 512x512 enviado à parte — ele não vai dentro
  // do APK, então nenhuma ferramenta de build o produz.
  _write(
    'dist/store/play_store_icon_512.png',
    copyResize(
      _flatten(logo, background),
      width: 512,
      height: 512,
      interpolation: Interpolation.cubic,
    ),
    'ficha da Play Store',
  );

  // A App Store lê o 1024 do catálogo de assets, mas ter uma cópia solta
  // ajuda em pré-visualizações e material de divulgação.
  _write(
    'dist/store/app_store_icon_1024.png',
    _flatten(logo, background),
    'ficha da App Store',
  );

  // A cor entra na configuração do flutter_launcher_icons; imprimir aqui
  // evita que ela seja adivinhada à mão e fique fora de sintonia com o logo.
  print('');
  print('Use esta cor em flutter_launcher_icons:');
  print('  background_color_ios: "$hex"');
  print('  adaptive_icon_background: "$hex"');
}

/// A cor opaca mais frequente da imagem — o fundo do logo.
///
/// Adivinhar essa cor à mão deixaria uma emenda visível entre o canto
/// preenchido e o fundo original.
ColorRgb8 _dominantOpaqueColor(Image image) {
  final tally = <int, int>{};

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a < 250) continue;

      // Agrupa em faixas de 8 para o degradê do fundo não virar milhares de
      // cores distintas, cada uma com contagem 1.
      final key = ((pixel.r ~/ 8) << 16) |
          ((pixel.g ~/ 8) << 8) |
          (pixel.b ~/ 8);
      tally[key] = (tally[key] ?? 0) + 1;
    }
  }

  final top = tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  return ColorRgb8(
    ((top >> 16) & 0xFF) * 8,
    ((top >> 8) & 0xFF) * 8,
    (top & 0xFF) * 8,
  );
}

/// Preenche os cantos transparentes, devolvendo um quadrado opaco.
Image _flatten(Image logo, ColorRgb8 background) {
  final canvas = Image(width: logo.width, height: logo.height, numChannels: 3);
  fill(canvas, color: background);
  compositeImage(canvas, logo);
  return canvas;
}

/// Encolhe o logo para a zona segura, centralizado em fundo transparente.
Image _insetForAdaptive(Image logo) {
  final side = logo.width;
  final inner = (side * _adaptiveSafeFraction).round();
  final offset = ((side - inner) / 2).round();

  final canvas = Image(width: side, height: side, numChannels: 4);
  fill(canvas, color: ColorRgba8(0, 0, 0, 0));

  compositeImage(
    canvas,
    copyResize(logo, width: inner, height: inner, interpolation: Interpolation.cubic),
    dstX: offset,
    dstY: offset,
  );

  return canvas;
}

void _write(String path, Image image, String label) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(image));
  print('gerado $path  (${image.width}x${image.height})  $label');
}

String _hex(num channel) =>
    channel.toInt().toRadixString(16).padLeft(2, '0').toUpperCase();
