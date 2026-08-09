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
}

/// Persistência real, no armazenamento do dispositivo.
class PrefsGameStorage implements GameStorage {
  const PrefsGameStorage();

  static const String _campaignKey = 'campaign_progress';
  static const String _highScoreKey = 'endless_high_score';
  static const String _recordsKey = 'campaign_level_records';

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
}

/// Persistência só em memória, para testes.
class InMemoryGameStorage implements GameStorage {
  InMemoryGameStorage({
    this.campaignProgress = 0,
    this.highScore = 0,
    Map<int, LevelRecord>? levelRecords,
  }) : levelRecords = levelRecords ?? {};

  int campaignProgress;
  int highScore;
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
  Future<Map<int, LevelRecord>> readLevelRecords() async =>
      Map.of(levelRecords);

  @override
  Future<void> writeLevelRecords(Map<int, LevelRecord> records) async =>
      levelRecords = Map.of(records);
}
