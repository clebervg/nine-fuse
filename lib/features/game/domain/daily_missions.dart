/// Missões diárias: três metas por dia, sorteadas pela data.
///
/// Regra pura. O sorteio usa a própria data como semente, então abrir e
/// fechar o app no mesmo dia nunca troca as missões — e o teste não depende
/// de relógio. As missões escolhidas são **gravadas** ao virar o dia (ver
/// `MissionsNotifier`), e não recalculadas a cada leitura: a escolha depende
/// do progresso na campanha, que muda no meio do dia, e uma missão que some
/// enquanto o jogador está quase terminando é o pior defeito possível aqui.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nine_fuse/features/game/domain/daily_spin.dart';

/// O que uma missão conta. Cada valor é um acontecimento que o jogo já
/// produz numa jogada; quem informa é o notifier da partida, nos dois modos.
enum MissionKind {
  /// Vencer fases da campanha.
  winLevels,

  /// Fazer fusões (cada combinação resolvida conta uma, cascatas incluídas).
  fusions,

  /// Fazer nascer peças 9 por fusão.
  createNines,

  /// Quebrar coberturas (gelo, vidro, pedra, corrente).
  breakObstacles,

  /// Usar boosters (Martelo, Bomba ou Pincel).
  useBoosters,

  /// Ganhar estrelas ao vencer fases (conta as estrelas da vitória, mesmo em
  /// fase já vencida antes — é jogar bem, não progredir).
  earnStars,

  /// Disparar uma Nova (alinhar três ou mais 9).
  triggerNova,
}

/// Uma missão: o que contar, quanto, e o que paga.
@immutable
class Mission {
  const Mission(this.kind, this.target, this.reward);

  final MissionKind kind;
  final int target;

  /// Moedas pagas ao coletar.
  final int reward;

  Map<String, Object> toJson() => {'k': kind.name, 't': target, 'r': reward};

  static Mission? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = MissionKind.values.where((k) => k.name == json['k']);
    final target = json['t'];
    final reward = json['r'];
    if (kind.isEmpty || target is! int || reward is! int || target < 1) {
      return null;
    }
    return Mission(kind.first, target, reward);
  }

  @override
  bool operator ==(Object other) =>
      other is Mission &&
      other.kind == kind &&
      other.target == target &&
      other.reward == reward;

  @override
  int get hashCode => Object.hash(kind, target, reward);

  @override
  String toString() => 'Mission(${kind.name} $target → $reward)';
}

/// Missões fáceis, médias e difíceis. O dia sempre tem uma de cada: a fácil
/// garante que ninguém fecha o app com zero missões, a difícil é o motivo
/// para jogar mais uma fase.
///
/// Recompensas pequenas de propósito: a missão existe para dar um motivo de
/// jogar hoje, não para ser a fonte de moeda. As três somam ~50 moedas, mais 20
/// pelas três juntas — um terço de Martelo por dia.
const List<Mission> _easy = [
  Mission(MissionKind.fusions, 25, 10),
  Mission(MissionKind.winLevels, 1, 10),
  Mission(MissionKind.useBoosters, 1, 10),
];

const List<Mission> _medium = [
  Mission(MissionKind.fusions, 60, 15),
  Mission(MissionKind.winLevels, 3, 15),
  Mission(MissionKind.earnStars, 5, 15),
  Mission(MissionKind.createNines, 3, 15),
  Mission(MissionKind.breakObstacles, 10, 15),
];

const List<Mission> _hard = [
  Mission(MissionKind.triggerNova, 1, 25),
  Mission(MissionKind.createNines, 8, 25),
  Mission(MissionKind.breakObstacles, 25, 25),
  Mission(MissionKind.winLevels, 5, 25),
  Mission(MissionKind.earnStars, 10, 25),
];

/// A partir de qual fase vencida as missões de 9, Nova e cobertura entram no
/// sorteio. O primeiro 9 da campanha nasce na fase 10 e as coberturas
/// estreiam na 8: pedir antes disso seria pedir algo que o jogador ainda não
/// viu.
const int kAdvancedMissionsFromProgress = 10;

const Set<MissionKind> _advancedKinds = {
  MissionKind.createNines,
  MissionKind.triggerNova,
  MissionKind.breakObstacles,
};

/// O prêmio por coletar as três missões do dia: moedas, e não um booster. Um
/// booster grátis por dia, somado à roleta e à recompensa diária, era a maior
/// torneira de booster do jogo (recalibragem de 2026-11-03).
const int kMissionsBonusCoins = 20;

SpinPrize missionsBonusFor(String day) =>
    const SpinPrize(SpinPrizeType.coins, kMissionsBonusCoins);

/// Semente estável da data. Não usa `String.hashCode`, que o Dart não promete
/// estável entre execuções.
int _seedOf(String day) =>
    day.codeUnits.fold(17, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);

/// As três missões do dia [day] (chave de `localDayKey`), para quem já venceu
/// [campaignProgress] fases.
List<Mission> missionsForDay(String day, {required int campaignProgress}) {
  final random = Random(_seedOf(day));
  final advanced = campaignProgress >= kAdvancedMissionsFromProgress;

  List<Mission> eligible(List<Mission> pool, Set<MissionKind> taken) => [
    for (final mission in pool)
      if (!taken.contains(mission.kind) &&
          (advanced || !_advancedKinds.contains(mission.kind)))
        mission,
  ];

  final chosen = <Mission>[];
  final taken = <MissionKind>{};
  for (final pool in [_easy, _medium, _hard]) {
    var options = eligible(pool, taken);
    // Sem nada elegível no nível (início de campanha, tudo avançado ou já
    // escolhido), cai para o nível anterior ainda livre: o dia nunca fica
    // com menos de três missões.
    if (options.isEmpty) options = eligible([..._medium, ..._easy], taken);
    final mission = options[random.nextInt(options.length)];
    chosen.add(mission);
    taken.add(mission.kind);
  }
  return chosen;
}

/// As missões de um dia e o que o jogador já fez nelas.
@immutable
class DailyMissions {
  const DailyMissions({
    required this.day,
    required this.missions,
    required this.progress,
    required this.claimed,
    this.bonusClaimed = false,
  });

  /// Estado vazio, antes de o disco responder ou de o primeiro dia começar.
  static const DailyMissions empty = DailyMissions(
    day: '',
    missions: [],
    progress: [],
    claimed: [],
  );

  /// As missões novas de [day].
  factory DailyMissions.forDay(String day, {required int campaignProgress}) {
    final missions = missionsForDay(day, campaignProgress: campaignProgress);
    return DailyMissions(
      day: day,
      missions: missions,
      progress: List.filled(missions.length, 0),
      claimed: List.filled(missions.length, false),
    );
  }

  final String day;
  final List<Mission> missions;
  final List<int> progress;
  final List<bool> claimed;
  final bool bonusClaimed;

  bool isComplete(int index) => progress[index] >= missions[index].target;

  /// Missão cumprida e ainda não coletada.
  bool canClaim(int index) => isComplete(index) && !claimed[index];

  /// Quantos prêmios esperam coleta, bônus incluído — é o número do selo.
  int get claimableCount =>
      [
        for (int i = 0; i < missions.length; i++)
          if (canClaim(i)) i,
      ].length +
      (canClaimBonus ? 1 : 0);

  bool get allClaimed => missions.isNotEmpty && claimed.every((c) => c);

  bool get canClaimBonus => allClaimed && !bonusClaimed;

  /// Soma [amount] a toda missão de [kind] ainda em aberto. O progresso para
  /// no alvo: passar dele não mostraria nada a mais, e "61/60" lê como erro.
  DailyMissions record(MissionKind kind, int amount) {
    if (amount <= 0) return this;
    var changed = false;
    final next = [...progress];
    for (int i = 0; i < missions.length; i++) {
      if (missions[i].kind != kind || claimed[i]) continue;
      final capped = min(next[i] + amount, missions[i].target);
      if (capped != next[i]) {
        next[i] = capped;
        changed = true;
      }
    }
    return changed ? _copy(progress: next) : this;
  }

  DailyMissions claim(int index) {
    if (!canClaim(index)) return this;
    return _copy(claimed: [...claimed]..[index] = true);
  }

  DailyMissions claimBonus() =>
      canClaimBonus ? _copy(bonusClaimed: true) : this;

  DailyMissions _copy({
    List<int>? progress,
    List<bool>? claimed,
    bool? bonusClaimed,
  }) => DailyMissions(
    day: day,
    missions: missions,
    progress: progress ?? this.progress,
    claimed: claimed ?? this.claimed,
    bonusClaimed: bonusClaimed ?? this.bonusClaimed,
  );

  String encode() => jsonEncode({
    'day': day,
    'missions': [for (final m in missions) m.toJson()],
    'progress': progress,
    'claimed': claimed,
    'bonus': bonusClaimed,
  });

  /// Lê o que foi gravado. Qualquer coisa ilegível vale como "sem missões":
  /// o notifier sorteia as do dia de novo, o que é muito melhor que travar.
  static DailyMissions decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      final missions = [
        for (final m in (json['missions'] as List? ?? const []))
          ?Mission.fromJson(m),
      ];
      final progress = [
        for (final p in (json['progress'] as List? ?? const []))
          if (p is int) p,
      ];
      final claimed = [
        for (final c in (json['claimed'] as List? ?? const []))
          if (c is bool) c,
      ];
      final day = json['day'];
      if (day is! String ||
          missions.isEmpty ||
          progress.length != missions.length ||
          claimed.length != missions.length) {
        return empty;
      }
      return DailyMissions(
        day: day,
        missions: missions,
        progress: progress,
        claimed: claimed,
        bonusClaimed: json['bonus'] == true,
      );
    } catch (_) {
      return empty;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DailyMissions &&
      other.day == day &&
      listEquals(other.missions, missions) &&
      listEquals(other.progress, progress) &&
      listEquals(other.claimed, claimed) &&
      other.bonusClaimed == bonusClaimed;

  @override
  int get hashCode => Object.hash(
    day,
    Object.hashAll(missions),
    Object.hashAll(progress),
    Object.hashAll(claimed),
    bonusClaimed,
  );
}
