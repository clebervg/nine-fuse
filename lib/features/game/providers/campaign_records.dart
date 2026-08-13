import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Quantas fases guardam registro detalhado.
///
/// A campanha não tem fim, mas a memória tem: o histórico é uma única string
/// JSON reescrita a cada vitória, então guardar tudo tornaria cada fase vencida
/// mais cara que a anterior, para sempre. Duzentas fases são muito mais do que
/// o mapa mostra sem minutos de rolagem — o que se perde é detalhe que ninguém
/// consulta, e as estrelas seguem contadas no agregado.
const int kRecordWindow = 200;

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

  /// Estrelas de fases já podadas. Somadas ao total, nunca ao mapa.
  int archivedStars = 0;

  /// A maior fase cujo detalhe já foi podado (0 = nenhuma).
  ///
  /// É a marca d'água que separa "fase nunca vencida" (rende estrelas cheias)
  /// de "fase vencida e já paga, mas sem detalhe" (rende zero). Sem ela,
  /// `record()` só teria `existing == null` para decidir, e um `null` de fase
  /// podada é indistinguível de um `null` de fase inédita — farm infinito.
  int prunedBelow = 0;

  /// A leitura é assíncrona: o mapa abre vazio e se preenche quando o disco
  /// responde. Falha de leitura vale como "nada salvo" — perder as estrelas é
  /// ruim, travar o mapa é pior.
  Future<void> _load() async {
    try {
      final saved = await _storage.readLevelRecords();
      final loadedPrunedBelow = await _storage.readPrunedBelow();
      final loadedArchivedStars = await _storage.readArchivedStars();
      if (!mounted) return;

      // A marca nunca pode regredir. Enquanto a leitura estava em voo, uma
      // vitória registrada em memória pode ter empurrado `prunedBelow` para a
      // frente (uma poda disparada por `record()`); adotar cegamente o valor
      // do disco devolveria a marca para trás e reabriria, ainda que por uma
      // sessão, o farm que ela existe para fechar.
      prunedBelow = prunedBelow > loadedPrunedBelow
          ? prunedBelow
          : loadedPrunedBelow;

      // O mesmo vale para o agregado: ele só cresce (é poda, nunca desfaz), e
      // o lado que chegou depois não pode apagar estrelas que a memória já
      // sabia ter arquivado.
      archivedStars = archivedStars > loadedArchivedStars
          ? archivedStars
          : loadedArchivedStars;

      // A marca vale para os dois lados do merge, não só para o que veio do
      // disco: uma vitória registrada nesta sessão, na janela antes de a
      // carga responder, pode ter pago uma fase que a marca (já atualizada
      // acima) considera podada. Sem filtrar `state` também, essa fase
      // indevida ficaria presa no mapa e no `totalStars` para sempre, uma vez
      // por abertura do app.
      final prunedSaved = Map.fromEntries(
        saved.entries.where((entry) => entry.key > prunedBelow),
      );
      final prunedState = Map.fromEntries(
        state.entries.where((entry) => entry.key > prunedBelow),
      );

      // A leitura pode chegar **depois** de o jogador já ter vencido uma fase
      // nesta sessão. Fundir em vez de substituir preserva o resultado mais
      // recente, pela mesma razão do `if (saved > state)` em
      // CampaignProgress.
      state = _merge(prunedSaved, prunedState);
    } catch (error, stack) {
      debugPrint('Falha ao ler os registros das fases: $error\n$stack');
    }
  }

  /// Dispara uma releitura do disco fora do construtor.
  ///
  /// Só existe para o teste simular uma segunda carga (ex.: verificar que uma
  /// marca mais antiga vinda do disco não rebaixa a que a sessão já avançou em
  /// memória) sem precisar destruir e recriar o notifier inteiro.
  @visibleForTesting
  Future<void> debugReload() => _load();

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
    // Fase igual ou abaixo da marca: já foi vencida, já foi paga, e o detalhe
    // que diria "quanto ela tinha antes" não existe mais. Devolver zero é a
    // única resposta segura — sem o antes, qualquer outro número seria
    // inventado, e inventar para cima é o erro que paga a mesma vitória de
    // novo a cada rejogada (farm infinito). Não reentra no mapa nem soma ao
    // agregado: o crédito de estrelas dela já está contado ali.
    if (levelNumber <= prunedBelow) return 0;

    final fresh = LevelRecord(stars: stars, bestScore: score);
    final existing = state[levelNumber];
    final merged = existing == null ? fresh : existing.mergedWith(fresh);
    final gained = merged.stars - (existing?.stars ?? 0);

    // Nada mudou: não vale um estado novo nem uma gravação em disco.
    if (existing == merged) return 0;

    state = _pruned({...state, levelNumber: merged});
    _persist();
    return gained;
  }

  /// Estrelas de uma fase, ou zero se ela nunca foi vencida.
  int starsFor(int levelNumber) => state[levelNumber]?.stars ?? 0;

  /// Soma de todas as estrelas conquistadas, incluindo as das fases podadas.
  int get totalStars =>
      archivedStars +
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
    archivedStars = 0;
    prunedBelow = 0;
    _persist();
    unawaited(_persistArchivedStars());
    unawaited(_persistPrunedBelow());
  }

  Future<void> _persist() async {
    try {
      await _storage.writeLevelRecords(state);
    } catch (error, stack) {
      debugPrint('Falha ao gravar os registros das fases: $error\n$stack');
    }
  }

  /// Mesma proteção de `_persist()`: um disco quebrado não pode escapar como
  /// erro assíncrono não tratado na zona — é a mesma lição já registrada no
  /// `RewardedAdService`.
  Future<void> _persistArchivedStars() async {
    try {
      await _storage.writeArchivedStars(archivedStars);
    } catch (error, stack) {
      debugPrint('Falha ao gravar as estrelas arquivadas: $error\n$stack');
    }
  }

  Future<void> _persistPrunedBelow() async {
    try {
      await _storage.writePrunedBelow(prunedBelow);
    } catch (error, stack) {
      debugPrint('Falha ao gravar a marca de poda: $error\n$stack');
    }
  }

  /// Mantém apenas as [kRecordWindow] fases mais recentes, arquivando as
  /// estrelas das que saem.
  ///
  /// Poda pelo **número da fase**, e não pela ordem de gravação: o jogador pode
  /// rejogar uma fase antiga a qualquer momento, e nesse caso o que interessa
  /// continua sendo onde ela está na trilha.
  Map<int, LevelRecord> _pruned(Map<int, LevelRecord> records) {
    if (records.length <= kRecordWindow) return records;

    final ordered = records.keys.toList()..sort();
    final dropCount = records.length - kRecordWindow;

    final kept = Map.of(records);
    for (final number in ordered.take(dropCount)) {
      archivedStars += kept.remove(number)!.stars;
      // A poda sempre desce a partir do número mais baixo presente, então a
      // marca só cresce — nunca precisa comparar, o próprio laço já entrega
      // em ordem crescente.
      prunedBelow = number;
    }

    // As duas gravações são encadeadas numa única `Future`, agregado primeiro
    // e marca por último: é a marca que autoriza `_load()` a descartar do
    // detalhe as fases já pagas, então ela só pode existir em disco depois de
    // o agregado já estar lá. Gravar as duas em paralelo (dois `unawaited`
    // independentes) não garante ordem nenhuma entre elas — se a marca
    // vencesse a corrida e o agregado falhasse, a releitura descartaria do
    // mapa fases cujas estrelas nunca chegaram a entrar no total: perda
    // silenciosa. Um mapa gravado sem a marca correspondente é inofensivo (a
    // releitura conta certo de qualquer jeito); é a ordem inversa que dói.
    unawaited(
      _persistArchivedStars().then((_) => _persistPrunedBelow()),
    );
    return kept;
  }
}

final campaignRecordsProvider =
    StateNotifierProvider<CampaignRecords, Map<int, LevelRecord>>(
      (ref) => CampaignRecords(),
    );
