import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/domain/campaign_chapter.dart';
import 'package:nine_fuse/features/game/domain/level_record.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Armazenamento que só sabe falhar. Nenhuma leitura ou gravação de progresso
/// pode impedir o jogador de abrir o mapa.
class _BrokenStorage implements GameStorage {
  @override
  Future<int> readCampaignProgress() async => throw StateError('sem disco');
  @override
  Future<void> writeCampaignProgress(int levelNumber) async =>
      throw StateError('sem disco');
  @override
  Future<int> readHighScore() async => throw StateError('sem disco');
  @override
  Future<void> writeHighScore(int score) async => throw StateError('sem disco');
  @override
  Future<Map<int, LevelRecord>> readLevelRecords() async =>
      throw StateError('sem disco');
  @override
  Future<void> writeLevelRecords(Map<int, LevelRecord> records) async =>
      throw StateError('sem disco');
}

void main() {
  group('LevelRecord', () {
    test('guarda o melhor de cada grandeza, em separado', () {
      const antes = LevelRecord(stars: 3, bestScore: 100);
      const depois = LevelRecord(stars: 1, bestScore: 500);

      // Sobrar movimento e pontuar não são a mesma coisa: uma partida pode
      // render mais pontos e menos estrelas que a anterior.
      expect(
        antes.mergedWith(depois),
        const LevelRecord(stars: 3, bestScore: 500),
      );
    });

    test('lê de volta o que gravou', () {
      const record = LevelRecord(stars: 2, bestScore: 340);
      expect(LevelRecord.tryFromJson(record.toJson()), record);
    });

    test('conteúdo inválido vira nulo, não exceção', () {
      // Disco corrompido ou gravado por uma versão futura não pode derrubar o
      // mapa: o registro se perde, o jogo abre.
      expect(LevelRecord.tryFromJson(null), isNull);
      expect(LevelRecord.tryFromJson('nada disso'), isNull);
      expect(LevelRecord.tryFromJson({'stars': 9, 'score': 10}), isNull);
      expect(LevelRecord.tryFromJson({'stars': 0, 'score': 10}), isNull);
      expect(LevelRecord.tryFromJson({'stars': 2, 'score': -1}), isNull);
      expect(LevelRecord.tryFromJson({'stars': '2', 'score': 10}), isNull);
      expect(LevelRecord.tryFromJson({'score': 10}), isNull);
    });
  });

  group('registros da campanha', () {
    test('somam estrelas e pontos de todas as fases', () {
      final records = CampaignRecords(storage: InMemoryGameStorage());
      addTearDown(records.dispose);

      records.record(1, stars: 3, score: 100);
      records.record(2, stars: 2, score: 250);

      expect(records.totalStars, 5);
      expect(records.totalScore, 350);
      expect(records.starsFor(1), 3);
      expect(records.starsFor(99), 0, reason: 'fase nunca vencida vale zero');
    });

    // Rejogar para tentar a terceira estrela não pode custar a que já se tinha.
    test('rejogar pior não apaga o resultado melhor', () {
      final records = CampaignRecords(storage: InMemoryGameStorage());
      addTearDown(records.dispose);

      records.record(1, stars: 3, score: 900);
      records.record(1, stars: 1, score: 100);

      expect(records.starsFor(1), 3);
      expect(records.totalScore, 900);
    });

    test('rejogar melhor atualiza', () {
      final records = CampaignRecords(storage: InMemoryGameStorage());
      addTearDown(records.dispose);

      records.record(1, stars: 1, score: 100);
      records.record(1, stars: 3, score: 900);

      expect(records.starsFor(1), 3);
      expect(records.totalScore, 900);
    });

    test('conta estrelas por capítulo', () {
      final records = CampaignRecords(storage: InMemoryGameStorage());
      addTearDown(records.dispose);

      records.record(1, stars: 3, score: 0);
      records.record(kChapters.last.firstLevel, stars: 2, score: 0);

      expect(records.starsInChapter(kChapters.first), 3);
      expect(records.starsInChapter(kChapters.last), 2);
    });

    group('o retorno diz quantas estrelas entraram', () {
      test('a primeira vitória devolve as estrelas todas', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        expect(records.record(1, stars: 2, score: 100), 2);
      });

      test('rejogar melhor devolve só a diferença', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        records.record(1, stars: 1, score: 100);

        expect(records.record(1, stars: 3, score: 900), 2);
      });

      // O merge guarda o melhor de cada fase, então rejogar pior não tira
      // estrela — e também não dá nenhuma. A barra do capítulo não pode animar
      // um ganho que não houve.
      test('rejogar igual ou pior devolve zero', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        records.record(1, stars: 3, score: 900);

        expect(records.record(1, stars: 3, score: 900), 0);
        expect(records.record(1, stars: 1, score: 10), 0);
      });

      // Placar melhor com a mesma nota grava (o melhor placar mudou) mas não
      // acrescenta estrela nenhuma.
      test('só o placar melhorou: grava, mas devolve zero', () {
        final records = CampaignRecords(storage: InMemoryGameStorage());
        addTearDown(records.dispose);

        records.record(1, stars: 2, score: 100);

        expect(records.record(1, stars: 2, score: 800), 0);
        expect(records.totalScore, 800);
        expect(records.starsFor(1), 2);
      });
    });

    test('grava no armazenamento', () async {
      final storage = InMemoryGameStorage();
      final records = CampaignRecords(storage: storage);
      addTearDown(records.dispose);

      records.record(3, stars: 2, score: 500);
      await Future<void>.delayed(Duration.zero);

      expect(
        storage.levelRecords[3],
        const LevelRecord(stars: 2, bestScore: 500),
      );
    });

    test('lê o que estava salvo', () async {
      final storage = InMemoryGameStorage(
        levelRecords: {1: const LevelRecord(stars: 3, bestScore: 700)},
      );
      final records = CampaignRecords(storage: storage);
      addTearDown(records.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(records.starsFor(1), 3);
      expect(records.totalScore, 700);
    });

    // A leitura é assíncrona: o jogador pode vencer uma fase antes de o disco
    // responder, e o valor lido não pode atropelar o mais recente.
    test('a leitura tardia não apaga um resultado feito antes dela', () async {
      final storage = InMemoryGameStorage(
        levelRecords: {1: const LevelRecord(stars: 1, bestScore: 50)},
      );
      final records = CampaignRecords(storage: storage);
      addTearDown(records.dispose);

      // Antes de a leitura chegar.
      records.record(1, stars: 3, score: 900);

      await Future<void>.delayed(Duration.zero);

      expect(records.starsFor(1), 3);
      expect(records.totalScore, 900);
    });

    test('falha de armazenamento não derruba nada', () async {
      final records = CampaignRecords(storage: _BrokenStorage());
      addTearDown(records.dispose);

      await Future<void>.delayed(Duration.zero);
      expect(records.totalStars, 0);

      records.record(1, stars: 3, score: 100);
      await Future<void>.delayed(Duration.zero);

      expect(
        records.starsFor(1),
        3,
        reason: 'gravar falhou, mas a sessão continua valendo',
      );
    });
  });

  group('capítulos', () {
    test('cobrem toda a campanha, sem buraco nem sobreposição', () {
      for (int number = 1; number <= 10; number++) {
        final matches = kChapters.where((c) => c.contains(number)).toList();
        expect(
          matches,
          hasLength(1),
          reason: 'a fase $number deveria estar em exatamente um capítulo',
        );
      }
    });

    test('o corte cai onde a janela de spawn sobe', () {
      // A partir da fase 7 o `0` para de cair — é onde o jogo muda de natureza.
      expect(chapterOf(6).number, 1);
      expect(chapterOf(7).number, 2);
    });

    test('uma fase fora das faixas não quebra o mapa', () {
      // Estender a campanha sem estender os capítulos não pode lançar.
      expect(chapterOf(999), kChapters.last);
    });
  });
}
