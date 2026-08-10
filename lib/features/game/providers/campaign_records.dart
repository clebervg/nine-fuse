import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Estrelas e melhor placar de cada fase vencida.
///
/// Fica separado de `CampaignProgress` porque responde a outra pergunta:
/// aquele diz **até onde** o jogador chegou (é o que destrava fase), este diz
/// **quão bem** ele foi em cada uma (é o que alimenta o mapa e o cabeçalho).
/// Juntá-los faria a regra de destravamento depender do formato do histórico.
class CampaignRecords extends StateNotifier<Map<int, LevelRecord>> {
  CampaignRecords({GameStorage? storage})
    : _storage = storage ?? const PrefsGameStorage(),
      super(const {}) {
    _load();
  }

  final GameStorage _storage;

  /// A leitura é assíncrona: o mapa abre vazio e se preenche quando o disco
  /// responde. Falha de leitura vale como "nada salvo" — perder as estrelas é
  /// ruim, travar o mapa é pior.
  Future<void> _load() async {
    try {
      final saved = await _storage.readLevelRecords();
      if (!mounted || saved.isEmpty) return;

      // A leitura pode chegar **depois** de o jogador já ter vencido uma fase
      // nesta sessão. Fundir em vez de substituir preserva o resultado mais
      // recente, pela mesma razão do `if (saved > state)` em CampaignProgress.
      state = _merge(saved, state);
    } catch (error, stack) {
      debugPrint('Falha ao ler os registros das fases: $error\n$stack');
    }
  }

  /// Combina dois históricos ficando com o melhor de cada fase.
  static Map<int, LevelRecord> _merge(
    Map<int, LevelRecord> a,
    Map<int, LevelRecord> b,
  ) {
    final merged = Map.of(a);
    for (final entry in b.entries) {
      final existing = merged[entry.key];
      merged[entry.key] = existing == null
          ? entry.value
          : existing.mergedWith(entry.value);
    }
    return merged;
  }

  /// Registra o resultado de uma fase vencida, guardando o melhor.
  ///
  /// Devolve **quantas estrelas entraram** com este resultado. Quem pergunta é
  /// a barra do capítulo no cartão de vitória: ela precisa saber de onde
  /// começar a animar, e no instante em que o cartão renderiza o total já
  /// inclui o ganho. O número também não é dedutível da partida — o merge
  /// guarda o melhor, então rejogar com nota igual ou pior rende zero mesmo
  /// tirando três estrelas. Só este método enxerga os dois lados da conta.
  int record(int levelNumber, {required int stars, required int score}) {
    final fresh = LevelRecord(stars: stars, bestScore: score);
    final existing = state[levelNumber];
    final merged = existing == null ? fresh : existing.mergedWith(fresh);
    final gained = merged.stars - (existing?.stars ?? 0);

    // Nada mudou: não vale um estado novo nem uma gravação em disco.
    if (existing == merged) return 0;

    state = {...state, levelNumber: merged};
    _persist();
    return gained;
  }

  /// Estrelas de uma fase, ou zero se ela nunca foi vencida.
  int starsFor(int levelNumber) => state[levelNumber]?.stars ?? 0;

  /// Soma de todas as estrelas conquistadas.
  int get totalStars =>
      state.values.fold(0, (total, record) => total + record.stars);

  /// Soma dos melhores placares de cada fase — a "pontuação da conta".
  int get totalScore =>
      state.values.fold(0, (total, record) => total + record.bestScore);

  /// Estrelas conquistadas dentro de um capítulo.
  int starsInChapter(CampaignChapter chapter) =>
      starsInChapterOf(state, chapter);

  /// Versão estática de [starsInChapter], para quem já tem o mapa observado
  /// (via `ref.watch(campaignRecordsProvider)`) e quer evitar uma segunda
  /// leitura do provider através de `ref.read(...notifier)` só para chamar o
  /// método de instância. A regra de filtragem mora aqui uma única vez; o
  /// método de instância apenas delega para ela.
  static int starsInChapterOf(
    Map<int, LevelRecord> records,
    CampaignChapter chapter,
  ) => records.entries
      .where((entry) => chapter.contains(entry.key))
      .fold(0, (total, entry) => total + entry.value.stars);

  void reset() {
    state = const {};
    _persist();
  }

  Future<void> _persist() async {
    try {
      await _storage.writeLevelRecords(state);
    } catch (error, stack) {
      debugPrint('Falha ao gravar os registros das fases: $error\n$stack');
    }
  }
}

final campaignRecordsProvider =
    StateNotifierProvider<CampaignRecords, Map<int, LevelRecord>>(
      (ref) => CampaignRecords(),
    );
