import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/daily_ad_count.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Conta os Martelos ganhos por vídeo no dia e diz quando o teto chegou.
///
/// Regra 4 da monetização: no máximo [kMaxHammerAdsPerDay] por dia (data
/// local). Só o vídeo conta — a compra com moeda segue livre.
class HammerAdCap extends StateNotifier<DailyAdCount> {
  HammerAdCap({GameStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const PrefsGameStorage(),
      _now = now ?? DateTime.now,
      super(DailyAdCount.empty) {
    unawaited(refresh());
  }

  final GameStorage _storage;

  /// Injetável: é o que deixa o teste virar o dia sem esperar a meia-noite.
  final DateTime Function() _now;

  String get _today => localDayKey(_now());

  /// Martelos ganhos por vídeo hoje.
  int get usedToday => state.countOn(_today);

  /// O teto do dia chegou? Lido na hora, e não guardado: o dia pode virar com
  /// o app aberto, e um booleano calculado ontem continuaria travando hoje.
  bool get reachedToday => usedToday >= kMaxHammerAdsPerDay;

  /// Relê o disco. Falha de leitura vale como **zero**: travar o vídeo por um
  /// disco ilegível tiraria do jogador o caminho principal do item.
  Future<void> refresh() async {
    DailyAdCount saved;
    try {
      saved = await _storage.readHammerAdGrants();
    } catch (error, stack) {
      debugPrint('Falha ao ler o teto de martelos por vídeo: $error\n$stack');
      return;
    }
    if (!mounted) return;
    // Nunca regride dentro do mesmo dia: uma leitura que chega depois de um
    // crédito em memória está velha, e adotá-la devolveria um vídeo ao teto.
    final today = _today;
    if (saved.countOn(today) > state.countOn(today)) state = saved;
  }

  /// Um martelo acabou de ser pago por vídeo.
  void recordGrant() {
    final today = _today;
    state = DailyAdCount(day: today, count: state.countOn(today) + 1);
    unawaited(_persist(state));
  }

  Future<void> _persist(DailyAdCount value) async {
    try {
      await _storage.writeHammerAdGrants(value);
    } catch (error, stack) {
      debugPrint(
        'Falha ao gravar o teto de martelos por vídeo: $error\n$stack',
      );
    }
  }
}

final hammerAdCapProvider = StateNotifierProvider<HammerAdCap, DailyAdCount>(
  (ref) => HammerAdCap(),
);
