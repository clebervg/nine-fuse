import 'package:flutter/foundation.dart';

/// Chave do dia **local** de [moment], no formato `AAAA-MM-DD`.
///
/// Local, e não UTC, porque "volte amanhã" é o amanhã do relógio do jogador:
/// em UTC o dia viraria no meio da tarde para quem joga nas Américas.
String localDayKey(DateTime moment) {
  final local = moment.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}';
}

/// Quantas vezes algo aconteceu num dia — hoje, os martelos ganhos por vídeo.
///
/// Guarda o dia junto do número, em vez de zerar o contador à meia-noite: não
/// há quem rode à meia-noite com o app fechado, e um contador sem data não
/// sabe se é de hoje. Lido num dia diferente, vale zero.
@immutable
class DailyAdCount {
  const DailyAdCount({required this.day, required this.count});

  /// Nada registrado ainda.
  static const empty = DailyAdCount(day: '', count: 0);

  /// Dia (ver [localDayKey]) em que [count] foi contado.
  final String day;
  final int count;

  /// O contador visto no dia [today]: o de outro dia não vale mais.
  int countOn(String today) => day == today ? count : 0;

  @override
  bool operator ==(Object other) =>
      other is DailyAdCount && other.day == day && other.count == count;

  @override
  int get hashCode => Object.hash(day, count);
}
