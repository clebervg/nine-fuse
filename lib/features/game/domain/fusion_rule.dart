/// O que uma combinação produz ao fundir.
///
/// Existe para que a economia do jogo possa ser trocada e medida sem mexer no
/// motor. O primeiro valor devolvido nasce na posição da fusão (o ponto de
/// interação, ou o centro nas cascatas); os seguintes ocupam outras posições
/// da própria combinação, e as que sobrarem ficam vazias.
///
/// A referência para ler os números: uma peça de valor V+1 "vale" três peças
/// de valor V, porque é o que custa produzi-la. Então o match-3 clássico
/// (3 peças de V → 1 de V+1) é **neutro** — não cria valor, só converte. É daí
/// que vem a dificuldade de alcançar dígitos altos.
abstract class FusionRule {
  const FusionRule();

  /// Valores gerados por uma combinação de [length] peças de valor [value].
  List<int> outcome({required int length, required int value});

  /// Nome curto para relatórios de simulação.
  String get label;

  /// Valor criado por uma combinação de [length] peças, em múltiplos do valor
  /// consumido. 1,0 significa neutra: nada é criado, só convertido.
  double valueMultiplier(int length) {
    final produced = outcome(
      length: length,
      value: 0,
    ).fold<double>(0, (sum, value) => sum + _relativeWeight(value));
    return produced / length;
  }

  /// Peso de uma peça de valor [value] em unidades de peça de valor 0: 3^value.
  static double _relativeWeight(int value) {
    var weight = 1.0;
    for (int i = 0; i < value; i++) {
      weight *= 3;
    }
    return weight;
  }
}

/// Regra atual: qualquer combinação gera uma única peça de V+1.
///
/// - match-3 → 1,00x (neutro)
/// - match-4 → 0,75x
/// - match-5 → 0,60x
///
/// Acima de 3 a regra destrói valor: as peças extras somem sem compensação.
/// O design de hoje não deixa de premiar combinações grandes, ele as **pune**.
class NeutralFusion extends FusionRule {
  const NeutralFusion();

  @override
  String get label => 'neutra (qualquer tamanho -> V+1)';

  @override
  List<int> outcome({required int length, required int value}) => [value + 1];
}

/// Proposta contida: premia combinação grande sem explodir a curva.
///
/// - match-3  → 1 peça de V+1 ............ 1,00x (como hoje)
/// - match-4  → 1 peça de V+1 + 1 de V ... 1,00x
/// - match-5+ → 1 peça de V+2 ............ 1,80x
class TieredFusion extends FusionRule {
  const TieredFusion();

  @override
  String get label => 'graduada (4 -> V+1 e V, 5 -> V+2)';

  @override
  List<int> outcome({required int length, required int value}) {
    if (length >= 5) return [value + 2];
    if (length == 4) return [value + 1, value];
    return [value + 1];
  }
}

/// Recomendação original dos especialistas, ao pé da letra.
///
/// - match-4 → 1 peça de V+2 ...... 2,25x
/// - match-5 → 2 peças de V+2 ..... 3,60x
///
/// Está aqui para ser medida, não necessariamente usada: o brief a descrevia
/// como "20% mais eficiente que dois matches de 3", o que subestima o efeito
/// em mais de uma ordem de grandeza.
class AggressiveFusion extends FusionRule {
  const AggressiveFusion();

  @override
  String get label => 'agressiva (4 -> V+2, 5 -> 2x V+2)';

  @override
  List<int> outcome({required int length, required int value}) {
    if (length >= 5) return [value + 2, value + 2];
    if (length == 4) return [value + 2];
    return [value + 1];
  }
}
