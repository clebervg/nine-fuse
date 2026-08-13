import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

void main() {
  test('poda o detalhe das fases antigas sem perder as estrelas', () async {
    final storage = InMemoryGameStorage();
    final records = CampaignRecords(storage: storage);
    addTearDown(records.dispose);

    // Uma fase a mais do que a janela comporta.
    for (int n = 1; n <= kRecordWindow + 5; n++) {
      records.record(n, stars: 3, score: 100);
    }

    expect(records.state.length, lessThanOrEqualTo(kRecordWindow));
    expect(records.totalStars, (kRecordWindow + 5) * 3);
  });

  test('a poda descarta as fases mais antigas, não as recentes', () async {
    final storage = InMemoryGameStorage();
    final records = CampaignRecords(storage: storage);
    addTearDown(records.dispose);

    for (int n = 1; n <= kRecordWindow + 5; n++) {
      records.record(n, stars: 3, score: 100);
    }

    expect(records.state.containsKey(1), isFalse);
    expect(records.state.containsKey(kRecordWindow + 5), isTrue);
  });

  test('o arquivo sobrevive a uma releitura do disco', () async {
    final storage = InMemoryGameStorage();
    final first = CampaignRecords(storage: storage);
    for (int n = 1; n <= kRecordWindow + 5; n++) {
      first.record(n, stars: 3, score: 100);
    }
    first.dispose();

    final second = CampaignRecords(storage: storage);
    addTearDown(second.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(second.totalStars, (kRecordWindow + 5) * 3);
  });

  // Farm infinito: sem a marca d'água, `record()` não sabe que a fase 1 já
  // foi paga (o detalhe dela não existe mais), então trata a repetição como
  // ganho cheio — e a poda soma as mesmas estrelas ao agregado de novo.
  test('rejogar uma fase cujo detalhe foi podado rende zero', () {
    final storage = InMemoryGameStorage();
    final records = CampaignRecords(storage: storage);
    addTearDown(records.dispose);

    for (int n = 1; n <= kRecordWindow + 5; n++) {
      records.record(n, stars: 3, score: 100);
    }
    // A fase 1 já foi podada: seu detalhe não está mais em `state`.
    expect(records.state.containsKey(1), isFalse);

    final gained = records.record(1, stars: 3, score: 100);

    expect(gained, 0);
  });

  test(
    'rejogar repetidamente uma fase podada não infla totalStars nem archivedStars',
    () {
      final storage = InMemoryGameStorage();
      final records = CampaignRecords(storage: storage);
      addTearDown(records.dispose);

      for (int n = 1; n <= kRecordWindow + 5; n++) {
        records.record(n, stars: 3, score: 100);
      }

      final totalBefore = records.totalStars;
      final archivedBefore = records.archivedStars;

      for (int i = 0; i < 10; i++) {
        records.record(1, stars: 3, score: 100);
      }

      expect(records.totalStars, totalBefore);
      expect(records.archivedStars, archivedBefore);
      expect(records.state.containsKey(1), isFalse);
    },
  );

  test(
    'após uma releitura do disco, o total de estrelas não conta duas vezes',
    () async {
      final storage = InMemoryGameStorage();
      final first = CampaignRecords(storage: storage);
      for (int n = 1; n <= kRecordWindow + 5; n++) {
        first.record(n, stars: 3, score: 100);
      }
      first.dispose();

      final second = CampaignRecords(storage: storage);
      addTearDown(second.dispose);
      await Future<void>.delayed(Duration.zero);

      final totalBefore = second.totalStars;

      // Fase 1 está abaixo da marca d'água persistida: rejogá-la depois da
      // releitura não pode nem pagar de novo nem reentrar no mapa.
      final gained = second.record(1, stars: 3, score: 100);

      expect(gained, 0);
      expect(second.totalStars, totalBefore);
      expect(second.state.containsKey(1), isFalse);
    },
  );

  test('uma fase acima da marca continua rendendo normalmente ao melhorar', () {
    final storage = InMemoryGameStorage();
    final records = CampaignRecords(storage: storage);
    addTearDown(records.dispose);

    for (int n = 1; n <= kRecordWindow + 5; n++) {
      records.record(n, stars: 1, score: 100);
    }
    // A última fase gravada está acima da marca: seu detalhe segue no mapa.
    final lastLevel = kRecordWindow + 5;
    expect(records.state.containsKey(lastLevel), isTrue);
    expect(records.starsFor(lastLevel), 1);

    final gained = records.record(lastLevel, stars: 3, score: 900);

    expect(gained, 2);
    expect(records.starsFor(lastLevel), 3);
  });
}
