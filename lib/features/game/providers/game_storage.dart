import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O que o app lembra entre aberturas: o avanço na campanha, o resultado de
/// cada fase vencida e o recorde do Endless.
///
/// A interface existe para os testes não dependerem de disco nem de plugin de
/// plataforma. Nenhuma implementação deve lançar em caminho normal — quem chama
/// trata falha como "não havia nada salvo", porque perder o progresso é ruim
/// mas impedir de jogar é pior.
abstract interface class GameStorage {
  Future<int> readCampaignProgress();
  Future<void> writeCampaignProgress(int levelNumber);

  Future<int> readHighScore();
  Future<void> writeHighScore(int score);

  /// Estrelas e melhor placar de cada fase já vencida, por número de fase.
  Future<Map<int, LevelRecord>> readLevelRecords();
  Future<void> writeLevelRecords(Map<int, LevelRecord> records);

  /// Estrelas de fases cujo detalhe já foi podado.
  ///
  /// A campanha é infinita, e o histórico por fase é gravado como **uma única
  /// string JSON** reescrita a cada vitória: sem poda, cada fase vencida
  /// custaria uma escrita proporcional a tudo que já foi jogado. O agregado é
  /// o que preserva a conta de estrelas quando o detalhe sai.
  Future<int> readArchivedStars();
  Future<void> writeArchivedStars(int stars);

  /// A maior fase cujo detalhe já foi podado.
  ///
  /// A poda descarta sempre pelo **número da fase**, então toda fase igual ou
  /// abaixo desta marca é uma fase já paga, sem detalhe para recalcular o
  /// ganho — sem guardar isto à parte, `record()` não teria como distinguir
  /// "fase nunca vencida" de "fase vencida e podada", e pagaria a segunda de
  /// novo a cada rejogada (farm infinito de moedas).
  Future<int> readPrunedBelow();
  Future<void> writePrunedBelow(int levelNumber);

  /// Martelos de Fusão em estoque.
  ///
  /// É inventário do **jogador**, não da fase: sobrevive a começar, perder e
  /// recomeçar. Um martelo comprado que desaparecesse ao avançar de fase seria
  /// dinheiro tirado de quem pagou.
  Future<int> readHammerCount();
  Future<void> writeHammerCount(int count);

  /// Moedas em carteira.
  ///
  /// Como o martelo, é do **jogador** e não da fase. Diferente dele, nenhuma
  /// regra de partida a consome: quem gasta é o convite de aquisição.
  Future<int> readCoins();
  Future<void> writeCoins(int coins);

  /// Números dos capítulos cujo baú já foi reclamado.
  ///
  /// Guardar quem **já pagou** é o que impede o baú de repagar a cada visita ao
  /// mapa. É um conjunto, e não um contador, porque capítulos podem ser
  /// fechados fora de ordem quando a campanha crescer.
  Future<Set<int>> readClaimedChests();
  Future<void> writeClaimedChests(Set<int> chapters);
}

/// Persistência real, no armazenamento do dispositivo.
class PrefsGameStorage implements GameStorage {
  const PrefsGameStorage();

  static const String _campaignKey = 'campaign_progress';
  static const String _highScoreKey = 'endless_high_score';
  static const String _recordsKey = 'campaign_level_records';
  static const String _archivedStarsKey = 'campaign_archived_stars';
  static const String _prunedBelowKey = 'campaign_pruned_below';
  static const String _hammerKey = 'booster_hammer_count';
  static const String _coinsKey = 'wallet_coins';
  static const String _chestsKey = 'campaign_chests_claimed';

  @override
  Future<int> readCampaignProgress() async =>
      (await SharedPreferences.getInstance()).getInt(_campaignKey) ?? 0;

  @override
  Future<void> writeCampaignProgress(int levelNumber) async =>
      (await SharedPreferences.getInstance()).setInt(_campaignKey, levelNumber);

  @override
  Future<int> readHighScore() async =>
      (await SharedPreferences.getInstance()).getInt(_highScoreKey) ?? 0;

  @override
  Future<void> writeHighScore(int score) async =>
      (await SharedPreferences.getInstance()).setInt(_highScoreKey, score);

  @override
  Future<int> readHammerCount() async =>
      (await SharedPreferences.getInstance()).getInt(_hammerKey) ?? 0;

  @override
  Future<void> writeHammerCount(int count) async =>
      (await SharedPreferences.getInstance()).setInt(_hammerKey, count);

  @override
  Future<int> readCoins() async =>
      (await SharedPreferences.getInstance()).getInt(_coinsKey) ?? 0;

  @override
  Future<void> writeCoins(int coins) async =>
      (await SharedPreferences.getInstance()).setInt(_coinsKey, coins);

  /// Os baús vão como lista de strings porque é o que o `SharedPreferences`
  /// oferece de coleção. A conversão para `Set<int>` acontece aqui, para o
  /// resto do app nunca ver o formato do disco.
  @override
  Future<Set<int>> readClaimedChests() async {
    final raw = (await SharedPreferences.getInstance()).getStringList(
      _chestsKey,
    );
    if (raw == null) return const {};

    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  @override
  Future<void> writeClaimedChests(Set<int> chapters) async =>
      (await SharedPreferences.getInstance()).setStringList(
        _chestsKey,
        chapters.map((chapter) => '$chapter').toList(),
      );

  /// Os registros vão num único JSON, e não numa chave por fase.
  ///
  /// São lidos sempre juntos (o cabeçalho soma todos) e escritos juntos; uma
  /// chave por fase multiplicaria o número de acessos ao disco sem nada em
  /// troca, e deixaria um estado meio-gravado possível.
  @override
  Future<Map<int, LevelRecord>> readLevelRecords() async {
    final raw = (await SharedPreferences.getInstance()).getString(_recordsKey);
    if (raw == null) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};

      final records = <int, LevelRecord>{};
      for (final entry in decoded.entries) {
        final number = int.tryParse('${entry.key}');
        final record = LevelRecord.tryFromJson(entry.value);
        if (number != null && record != null) records[number] = record;
      }
      return records;
    } catch (error, stack) {
      // Conteúdo corrompido vale como "nada salvo": abrir o mapa é mais
      // importante do que preservar um registro que já se perdeu.
      debugPrint('Registro de fases ilegível, ignorando: $error\n$stack');
      return const {};
    }
  }

  @override
  Future<void> writeLevelRecords(Map<int, LevelRecord> records) async {
    final encoded = jsonEncode({
      for (final entry in records.entries) '${entry.key}': entry.value.toJson(),
    });
    await (await SharedPreferences.getInstance()).setString(
      _recordsKey,
      encoded,
    );
  }

  @override
  Future<int> readArchivedStars() async =>
      (await SharedPreferences.getInstance()).getInt(_archivedStarsKey) ?? 0;

  @override
  Future<void> writeArchivedStars(int stars) async =>
      (await SharedPreferences.getInstance()).setInt(
        _archivedStarsKey,
        stars,
      );

  @override
  Future<int> readPrunedBelow() async =>
      (await SharedPreferences.getInstance()).getInt(_prunedBelowKey) ?? 0;

  @override
  Future<void> writePrunedBelow(int levelNumber) async =>
      (await SharedPreferences.getInstance()).setInt(
        _prunedBelowKey,
        levelNumber,
      );
}

/// Persistência só em memória, para testes.
class InMemoryGameStorage implements GameStorage {
  InMemoryGameStorage({
    this.campaignProgress = 0,
    this.highScore = 0,
    this.hammerCount = 0,
    this.coins = 0,
    this.archivedStars = 0,
    this.prunedBelow = 0,
    Set<int>? claimedChests,
    Map<int, LevelRecord>? levelRecords,
  }) : claimedChests = claimedChests ?? {},
       levelRecords = levelRecords ?? {};

  int campaignProgress;
  int highScore;
  int hammerCount;
  int coins;
  int archivedStars;
  int prunedBelow;
  Set<int> claimedChests;
  Map<int, LevelRecord> levelRecords;

  @override
  Future<int> readCampaignProgress() async => campaignProgress;

  @override
  Future<void> writeCampaignProgress(int levelNumber) async =>
      campaignProgress = levelNumber;

  @override
  Future<int> readHighScore() async => highScore;

  @override
  Future<void> writeHighScore(int score) async => highScore = score;

  @override
  Future<int> readHammerCount() async => hammerCount;

  @override
  Future<void> writeHammerCount(int count) async => hammerCount = count;

  @override
  Future<int> readCoins() async => coins;

  @override
  Future<void> writeCoins(int value) async => coins = value;

  @override
  Future<Set<int>> readClaimedChests() async => Set.of(claimedChests);

  @override
  Future<void> writeClaimedChests(Set<int> chapters) async =>
      claimedChests = Set.of(chapters);

  @override
  Future<Map<int, LevelRecord>> readLevelRecords() async =>
      Map.of(levelRecords);

  @override
  Future<void> writeLevelRecords(Map<int, LevelRecord> records) async =>
      levelRecords = Map.of(records);

  @override
  Future<int> readArchivedStars() async => archivedStars;

  @override
  Future<void> writeArchivedStars(int stars) async => archivedStars = stars;

  @override
  Future<int> readPrunedBelow() async => prunedBelow;

  @override
  Future<void> writePrunedBelow(int levelNumber) async =>
      prunedBelow = levelNumber;
}
