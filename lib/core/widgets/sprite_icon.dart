import 'package:flutter/material.dart';

/// Ícone de HUD com sprite opcional: tenta a imagem em [asset] e cai para o
/// [fallback] (o `IconData` de sempre) quando o arquivo ainda não existe.
///
/// Mesmo padrão do glifo de moeda em `CoinsHeaderBadge`: `assets/images/` já é
/// uma pasta inteira declarada no `pubspec.yaml`, então nenhum PNG novo aqui
/// precisa de entrada própria — só precisa existir em disco. `Image.asset`
/// resolve o fallback nativamente via `errorBuilder`, sem precisar do aparato
/// de cache do `TileSpriteManager` (que existe para os assets tentados em
/// **massa**, a cada dígito e cada estado de obstáculo — aqui é um ícone
/// isolado por vez).
///
/// A imagem não recebe [color]: a arte já traz cor própria (acabamento 3D),
/// e tingi-la devolveria um ícone monocromático. Só o fallback (`Icon`) usa a
/// cor, porque é ele quem precisa combinar com o resto do slot sem arte.
class SpriteIcon extends StatelessWidget {
  const SpriteIcon({
    super.key,
    required this.asset,
    required this.fallback,
    this.size = 26,
    this.color = Colors.white,
  });

  final String asset;
  final IconData fallback;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    errorBuilder: (context, error, stackTrace) =>
        Icon(fallback, size: size, color: color),
  );
}
