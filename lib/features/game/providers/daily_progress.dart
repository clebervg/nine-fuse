import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/daily_ad_count.dart';
import 'package:nine_fuse/features/game/domain/daily_missions.dart';
import 'package:nine_fuse/features/game/domain/daily_reward.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';
import 'package:nine_fuse/features/game/domain/match_engine.dart';
import 'package:nine_fuse/features/game/providers/game_notifier.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';
import 'package:nine_fuse/features/game/providers/prize_credit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde a sequência diária e as missões moram entre aberturas do app.
///
/// Interface própria, e não dois métodos a mais em [GameStorage]: nove
/// arquivos de teste implementam `GameStorage` à mão, e cada um teria de
/// ganhar dois dublês que nada têm a ver com o que testa.
abstract interface class DailyProgressStorage {
  Future<DailyStreak> readDailyStreak();
  Future<void> writeDailyStreak(DailyStreak streak);

  Future<DailyMissions> readDailyMissions();
  Future<void> writeDailyMissions(DailyMissions missions);
}

class PrefsDailyProgressStorage implements DailyProgressStorage {
  const PrefsDailyProgressStorage();

  static const String _streakDayKey = 'daily_reward_last_day';
  static const String _streakCountKey = 'daily_reward_streak';
  static const String _missionsKey = 'daily_missions';

  @override
  Future<DailyStreak> readDailyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyStreak(
      lastClaimDay: prefs.getString(_streakDayKey) ?? '',
      claimedDays: prefs.getInt(_streakCountKey) ?? 0,
    );
  }

  @override
  Future<void> writeDailyStreak(DailyStreak streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streakDayKey, streak.lastClaimDay);
    await prefs.setInt(_streakCountKey, streak.claimedDays);
  }

  @override
  Future<DailyMissions> readDailyMissions() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyMissions.decode(prefs.getString(_missionsKey));
  }

  @override
  Future<void> writeDailyMissions(DailyMissions missions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_missionsKey, missions.encode());
  }
}

/// Dublê em memória, para os testes.
class InMemoryDailyProgressStorage implements DailyProgressStorage {
  InMemoryDailyProgressStorage({
    this.streak = DailyStreak.none,
    this.missions = DailyMissions.empty,
  });

  DailyStreak streak;
  DailyMissions missions;

  @override
  Future<DailyStreak> readDailyStreak() async => streak;

  @override
  Future<void> writeDailyStreak(DailyStreak value) async => streak = value;

  @override
  Future<DailyMissions> readDailyMissions() async => missions;

  @override
  Future<void> writeDailyMissions(DailyMissions value) async =>
      missions = value;
}

/// Desligado por padrão (nulo), ligado no `main` — o mesmo desenho do
/// tutorial. Sem isso, toda a suíte de widget que monta a tela inicial ou uma
/// partida passaria a abrir a recompensa diária por cima do que testa.
final dailyProgressStorageProvider = Provider<DailyProgressStorage?>(
  (_) => null,
);

/// O relógio das regras diárias, trocável em teste.
final dailyClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

// ---------------------------------------------------------------------------
// Recompensa diária
// ---------------------------------------------------------------------------

@immutable
class DailyRewardState {
  const DailyRewardState({
    required this.enabled,
    required this.loaded,
    this.streak = DailyStreak.none,
  });

  static const off = DailyRewardState(enabled: false, loaded: true);

  final bool enabled;
  final bool loaded;
  final DailyStreak streak;

  /// Há prêmio esperando hoje. Falso enquanto o disco não respondeu: abrir o
  /// calendário com a sequência errada é pior do que abri-lo um quadro depois.
  bool availableAt(DateTime now) =>
      enabled && loaded && dailyRewardStatus(streak, now).available;
}

class DailyRewardNotifier extends StateNotifier<DailyRewardState> {
  DailyRewardNotifier({
    DailyProgressStorage? storage,
    required this._creditStorage,
    required this._clock,
  }) : _storage = storage,
       super(
         storage == null
             ? DailyRewardState.off
             : const DailyRewardState(enabled: true, loaded: false),
       ) {
    ready = storage == null ? Future.value() : _load();
  }

  final DailyProgressStorage? _storage;
  final GameStorage _creditStorage;
  final DateTime Function() _clock;

  late final Future<void> ready;

  Future<void> _load() async {
    var streak = DailyStreak.none;
    try {
      streak = await _storage!.readDailyStreak();
    } catch (error) {
      // Sequência ilegível vale como "nunca coletou": o jogador recomeça do
      // dia 1, o que é ruim mas não trava o jogo.
      debugPrint('Sequência diária ilegível: $error');
    }
    if (!mounted) return;
    state = DailyRewardState(enabled: true, loaded: true, streak: streak);
  }

  DailyRewardStatus get status => dailyRewardStatus(state.streak, _clock());

  /// Coleta o prêmio de hoje. Nulo quando não há o que coletar.
  ///
  /// A sequência é gravada **antes** do crédito: se o app morrer entre as
  /// duas escritas, o jogador perde um prêmio uma vez; na ordem inversa,
  /// ganharia o mesmo prêmio de novo a cada reabertura.
  Future<List<PrizePayout>?> claim() async {
    if (!state.enabled || !state.loaded) return null;
    final now = _clock();
    final next = claimDailyReward(state.streak, now);
    if (next == null) return null;

    final prizes =
        kDailyRewardCycle[dailyRewardStatus(state.streak, now).cycleDay];
    state = DailyRewardState(enabled: true, loaded: true, streak: next);
    try {
      await _storage!.writeDailyStreak(next);
    } catch (error) {
      debugPrint('Falha ao gravar a sequência diária: $error');
    }

    final payouts = <PrizePayout>[];
    for (final prize in prizes) {
      payouts.add(await creditPrize(_creditStorage, prize));
    }
    return payouts;
  }
}

/// O armazenamento que recebe os prêmios (moedas e boosters). É o mesmo da
/// roleta, para os testes trocarem os dois de uma vez.
final dailyCreditStorageProvider = Provider<GameStorage>(
  (_) => const PrefsGameStorage(),
);

final dailyRewardProvider =
    StateNotifierProvider<DailyRewardNotifier, DailyRewardState>(
      (ref) => DailyRewardNotifier(
        storage: ref.watch(dailyProgressStorageProvider),
        creditStorage: ref.watch(dailyCreditStorageProvider),
        clock: ref.watch(dailyClockProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Missões diárias
// ---------------------------------------------------------------------------

/// Quem conta progresso de missão: os notifiers de partida recebem isto e
/// chamam a cada acontecimento. Uma função, e não o notifier inteiro, para a
/// regra de partida continuar testável sem Riverpod.
typedef MissionSink = void Function(MissionKind kind, int amount);

/// O que uma jogada resolvida conta para as missões. Compartilhado pelos dois
/// modos, para "fusões" valerem a mesma coisa na campanha e no Recorde.
///
/// [boosterUsed] é a jogada de Martelo, Bomba ou Pincel — as únicas que não
/// contam como movimento.
void reportMissionResolution(
  MissionSink? sink,
  Resolution resolution, {
  required bool boosterUsed,
}) {
  if (sink == null) return;
  sink(MissionKind.fusions, resolution.fusions);
  sink(MissionKind.createNines, resolution.countProduced(kMaxDigit));
  sink(MissionKind.triggerNova, resolution.novaEvents.length);
  sink(MissionKind.breakObstacles, resolution.obstaclesCleared);
  if (boosterUsed) sink(MissionKind.useBoosters, 1);
}

class MissionsNotifier extends StateNotifier<DailyMissions> {
  MissionsNotifier({
    DailyProgressStorage? storage,
    required this._creditStorage,
    required this._clock,
    required this._campaignProgress,
  }) : _storage = storage,
       super(DailyMissions.empty) {
    ready = storage == null ? Future.value() : _load();
  }

  final DailyProgressStorage? _storage;
  final GameStorage _creditStorage;
  final DateTime Function() _clock;
  final int Function() _campaignProgress;

  late final Future<void> ready;
  bool _loaded = false;

  /// Acontecimentos que chegaram antes de o disco responder. São aplicados
  /// depois da leitura, sobre o que estava gravado — aplicá-los antes e
  /// gravar apagaria o progresso do dia.
  final List<(MissionKind, int)> _pending = [];

  bool get enabled => _storage != null;

  Future<void> _load() async {
    var saved = DailyMissions.empty;
    try {
      saved = await _storage!.readDailyMissions();
    } catch (error) {
      debugPrint('Missões ilegíveis, sorteando as do dia: $error');
    }
    if (!mounted) return;
    _loaded = true;
    state = saved;
    _rollOver();
    for (final (kind, amount) in _pending) {
      state = state.record(kind, amount);
    }
    if (_pending.isNotEmpty) unawaited(_persist());
    _pending.clear();
  }

  /// Troca as missões quando o dia virou (ou na primeira abertura).
  ///
  /// Público para a tela chamar ao abrir: o app pode passar a meia-noite
  /// aberto, e a lista de ontem não pode continuar no ar.
  void ensureToday() {
    if (!enabled || !_loaded) return;
    if (_rollOver()) unawaited(_persist());
  }

  bool _rollOver() {
    final today = localDayKey(_clock());
    if (state.day == today) return false;
    state = DailyMissions.forDay(today, campaignProgress: _campaignProgress());
    unawaited(_persist());
    return true;
  }

  /// Conta [amount] para as missões de [kind]. Silencioso quando desligado.
  void record(MissionKind kind, int amount) {
    if (!enabled || amount <= 0) return;
    if (!_loaded) {
      _pending.add((kind, amount));
      return;
    }
    _rollOver();
    final next = state.record(kind, amount);
    if (identical(next, state)) return;
    state = next;
    unawaited(_persist());
  }

  /// Coleta a missão [index]. Devolve as moedas pagas, ou nulo se não havia
  /// o que coletar. Marca antes de creditar, pela mesma razão da sequência.
  Future<int?> claim(int index) async {
    if (!enabled || !_loaded) return null;
    if (index < 0 || index >= state.missions.length) return null;
    if (!state.canClaim(index)) return null;

    final reward = state.missions[index].reward;
    state = state.claim(index);
    await _persist();
    await creditPrize(_creditStorage, SpinPrize(SpinPrizeType.coins, reward));
    return reward;
  }

  /// Coleta o prêmio das três missões. Nulo se ainda não há o que coletar.
  Future<PrizePayout?> claimBonus() async {
    if (!enabled || !_loaded || !state.canClaimBonus) return null;
    final prize = missionsBonusFor(state.day);
    state = state.claimBonus();
    await _persist();
    return creditPrize(_creditStorage, prize);
  }

  Future<void> _persist() async {
    try {
      await _storage?.writeDailyMissions(state);
    } catch (error) {
      debugPrint('Falha ao gravar as missões: $error');
    }
  }
}

final missionsProvider = StateNotifierProvider<MissionsNotifier, DailyMissions>(
  (ref) => MissionsNotifier(
    storage: ref.watch(dailyProgressStorageProvider),
    creditStorage: ref.watch(dailyCreditStorageProvider),
    clock: ref.watch(dailyClockProvider),
    // Lido na hora do sorteio, e não observado: as missões do dia já
    // escolhidas não podem mudar porque o jogador venceu uma fase.
    campaignProgress: () => ref.read(campaignProgressProvider),
  ),
);
