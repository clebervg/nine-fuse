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
}
