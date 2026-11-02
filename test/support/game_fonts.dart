import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:nine_fuse/core/theme/app_fonts.dart';

/// Carrega as fontes de título e de número da direção "Observatório Real".
///
/// Golden sem a fonte real desenha retângulos no lugar do texto — o teste
/// passaria comparando caixas, sem travar nada da tipografia que ele existe
/// para travar. A Nunito continua carregada por cada teste, como já era.
Future<void> loadNfFonts() async {
  final title = FontLoader(AppFonts.title)
    ..addFont(rootBundle.load('assets/fonts/LilitaOne-Regular.ttf'));
  final number = FontLoader(AppFonts.number)
    ..addFont(rootBundle.load('assets/fonts/Baloo2-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Baloo2-ExtraBold.ttf'));
  await Future.wait([title.load(), number.load()]);
}
