// Prepara TODOS os mestres de ícone a partir de assets/images/logo.svg.
//
// O SVG é a fonte da verdade única. Esta ferramenta faz as duas conversões e
// os dois recortes, porque cada plataforma recusa o mestre da outra:
//
//   - **iOS não aceita transparência** em ícone de app. A Apple rejeita o
//     envio, e mesmo que passasse o sistema desenharia preto nos cantos. O
//     ícone precisa ser um quadrado opaco; o arredondamento quem aplica é o
//     iOS.
//   - **Android 8+ usa ícone adaptativo**, com frente e fundo separados. O
//     sistema recorta a frente em círculo, quadrado ou outras máscaras
//     conforme o aparelho, então a arte tem de caber na zona segura central —
//     66% do quadro.
//
// A frente do Android sai de um render SEM o retângulo de fundo. Encolher o
// logo inteiro (com o fundo escuro arredondado junto) é o que produzia a marca
// minúscula numa ilha preta dentro da máscara — o fundo entra pelo
// `adaptive_icon_background`, não pela arte. A derivação é feita aqui, por
// recorte do grupo `mark`, e não à mão num segundo arquivo: dois SVGs
// divergiriam no primeiro ajuste de arte.
//
// `rsvg-convert -i mark` faria isso em uma linha e NÃO serve: esta versão do
// librsvg recorta pela bounding box do elemento (deformando a proporção) e
// perde o anel de energia pelo caminho. Foi tentado.
//
// Requer `rsvg-convert` no PATH (`brew install librsvg`).
//
// Uso: dart run tool/prepare_icons.dart
//
// Depois: dart run flutter_launcher_icons

// Ferramenta de linha de comando: aqui o print é a saída do programa.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

/// Zona segura do ícone adaptativo: o sistema pode recortar tudo fora dela.
const double _adaptiveSafeFraction = 0.66;

/// Lado dos mestres. 1024 é o que a App Store pede; tudo mais é recorte disso.
const int _masterSide = 1024;

const String _svgPath = 'assets/images/logo.svg';

/// Renderiza um SVG em PNG quadrado com o `rsvg-convert`.
Image _render(String svgPath, int side) {
  final out = File('${Directory.systemTemp.path}/nine_fuse_icon_render.png');
  final result = Process.runSync('rsvg-convert', [
    '-w', '$side', '-h', '$side', svgPath, '-o', out.path,
  ]);

  if (result.exitCode != 0) {
    print('ERRO: rsvg-convert falhou em $svgPath.');
    print(result.stderr);
    exit(1);
  }

  final image = decodePng(out.readAsBytesSync());
  out.deleteSync();

  if (image == null) {
    print('ERRO: não consegui decodificar o render de $svgPath.');
    exit(1);
  }
  return image;
}

/// Escreve um SVG temporário contendo os `defs` e só o grupo `mark` — a arte
/// sem o retângulo de fundo.
File _markOnlySvg(String source) {
  final svg = File(source).readAsStringSync();

  final markStart = svg.indexOf('<g id="mark">');
  final markEnd = svg.lastIndexOf('</g>');
  final defsEnd = svg.indexOf('</defs>');

  if (markStart < 0 || markEnd < markStart || defsEnd < 0) {
    print('ERRO: $source precisa ter <defs>...</defs> e <g id="mark">...</g>.');
    print('A frente do ícone adaptativo é derivada desse grupo.');
    exit(1);
  }

  final header = svg.substring(0, defsEnd + '</defs>'.length);
  final mark = svg.substring(markStart, markEnd + '</g>'.length);

  final file = File('${Directory.systemTemp.path}/nine_fuse_mark.svg');
  file.writeAsStringSync('$header\n$mark\n</svg>\n');
  return file;
}

void main() {
  if (!File(_svgPath).existsSync()) {
    print('ERRO: $_svgPath não encontrado.');
    exit(1);
  }

  final logo = _render(_svgPath, _masterSide);

  // `logo.png` continua sendo gravado porque é o asset declarado no pubspec e
  // o que se abre para conferir a arte a olho. Ele não é mais um passo manual
  // do pipeline: sai do mesmo render que alimenta os mestres, então não tem
  // como ficar velho em relação ao SVG.
  _write('assets/images/logo.png', logo, 'render do SVG (asset e conferência)');

  final markSvg = _markOnlySvg(_svgPath);
  final mark = _render(markSvg.path, _masterSide);
  markSvg.deleteSync();

  final background = _dominantOpaqueColor(logo);
  final hex = '#${_hex(background.r)}${_hex(background.g)}${_hex(background.b)}';
  print('cor de fundo detectada: $hex');

  _write(
    'assets/icon/app_icon.png',
    _flatten(logo, background),
    'quadrado opaco (iOS e loja)',
  );

  // A frente sai do `mark`, e não do `logo`: sem o retângulo de fundo, o que
  // a máscara recorta é a arte, e o escuro em volta vem do
  // `adaptive_icon_background`.
  _write(
    'assets/icon/app_icon_foreground.png',
    _insetForAdaptive(mark),
    'frente do adaptativo (Android, sem fundo)',
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

/// Ajusta a arte à zona segura do ícone adaptativo, centralizada em fundo
/// transparente.
///
/// O recorte pela caixa do conteúdo é o que impede o **encolhimento duplo**:
/// escalar o canvas inteiro a 66% encolhe junto a margem transparente que a
/// arte já tinha, e o resultado é a marca minúscula no meio da máscara. O que
/// tem de medir 66% é o desenho, não o quadro em volta dele.
Image _insetForAdaptive(Image art) {
  final side = art.width;
  final bounds = _contentBounds(art);

  // A escala é medida pelo RAIO do conteúdo, não pelo lado da sua caixa. A
  // máscara é redonda: arte que preenche um quadrado de 66% tem os cantos (e,
  // aqui, as pontas do anel) fora do círculo de 66%, e o recorte os come. Como
  // esta arte é aproximadamente circular, ajustar pelo raio cabe inteira e
  // ainda assim preenche muito mais do que caberia pela regra do quadrado.
  final scale = (side * _adaptiveSafeFraction / 2) / _contentRadius(art, bounds);

  final scaled = copyResize(
    copyCrop(
      art,
      x: bounds.left,
      y: bounds.top,
      width: bounds.width,
      height: bounds.height,
    ),
    width: (bounds.width * scale).round(),
    height: (bounds.height * scale).round(),
    interpolation: Interpolation.cubic,
  );

  final canvas = Image(width: side, height: side, numChannels: 4);
  fill(canvas, color: ColorRgba8(0, 0, 0, 0));

  compositeImage(
    canvas,
    scaled,
    dstX: ((side - scaled.width) / 2).round(),
    dstY: ((side - scaled.height) / 2).round(),
  );

  return canvas;
}

/// Distância do centro da caixa até o pixel visível mais distante.
double _contentRadius(Image image, _Bounds bounds, {int threshold = 16}) {
  final cx = bounds.left + bounds.width / 2;
  final cy = bounds.top + bounds.height / 2;
  double worst = 0;

  for (int y = bounds.top; y < bounds.top + bounds.height; y++) {
    for (int x = bounds.left; x < bounds.left + bounds.width; x++) {
      if (image.getPixel(x, y).a < threshold) continue;
      final dx = x - cx, dy = y - cy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > worst) worst = d;
    }
  }

  return worst;
}

/// Caixa do que é visível na imagem.
///
/// O limiar descarta o rastro quase transparente do brilho neon. Sem ele a
/// caixa cresce até quase o quadro inteiro por causa de pixels de alfa 1 ou 2,
/// e o recorte deixa de recortar coisa alguma — o defeito que ele existe para
/// evitar voltaria em silêncio.
_Bounds _contentBounds(Image image, {int threshold = 16}) {
  int left = image.width, top = image.height, right = -1, bottom = -1;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a < threshold) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  if (right < 0) {
    print('ERRO: a arte da frente do adaptativo saiu vazia.');
    exit(1);
  }

  return _Bounds(left, top, right - left + 1, bottom - top + 1);
}

class _Bounds {
  const _Bounds(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;
}

void _write(String path, Image image, String label) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(image));
  print('gerado $path  (${image.width}x${image.height})  $label');
}

String _hex(num channel) =>
    channel.toInt().toRadixString(16).padLeft(2, '0').toUpperCase();
