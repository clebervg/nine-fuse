import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/features/game/providers/campaign_records.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Armazenamento cuja leitura da marca de poda só resolve quando o teste
/// mandar. Simula a janela real entre o construtor disparar `_load()` e o
/// disco responder — janela em que `prunedBelow` ainda vale 0 em memória.
class _GatedStorage extends InMemoryGameStorage {
  _GatedStorage({required this.gate, required super.prunedBelow});

  final Completer<void> gate;

  @override
  Future<int> readPrunedBelow() async {
    await gate.future;
    return super.readPrunedBelow();
  }
}

/// Armazenamento cuja leitura da marca de poda ignora qualquer gravação
/// posterior e sempre devolve o valor congelado na construção. Simula um
/// disco desatualizado (ex.: outra aba, outra instância mais lenta) que
/// responde depois de a memória já ter avançado a marca sozinha.
class _StalePrunedBelowStorage extends InMemoryGameStorage {
  _StalePrunedBelowStorage(this._frozenPrunedBelow);

  final int _frozenPrunedBelow;

  @override
  Future<int> readPrunedBelow() async => _frozenPrunedBelow;
}

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

  // Achado 1 da re-revisão: enquanto `_load()` não resolveu, `prunedBelow`
  // vale 0 em memória, então uma vitória numa fase já podada no disco passa
  // pela guarda de `record()`. O bug era `_load()` filtrar só o lado do disco
  // ao fundir — a fase indevida sobrevivia no mapa e no `totalStars` depois da
  // carga chegar. A correção precisa aplicar o filtro da marca aos dois lados
  // do merge.
  test(
    'vitória numa fase podada, registrada antes de a carga responder, não sobrevive à carga',
    () async {
      final gate = Completer<void>();
      final storage = _GatedStorage(gate: gate, prunedBelow: 50);
      final records = CampaignRecords(storage: storage);
      addTearDown(records.dispose);

      // A carga está em voo (presa no gate); `prunedBelow` em memória ainda é
      // 0, então a fase 10 (abaixo da marca real do disco) passa pela guarda.
      final gained = records.record(10, stars: 3, score: 100);
      expect(
        gained,
        3,
        reason:
            'antes de a carga responder, prunedBelow em memória ainda é 0',
      );
      expect(records.state.containsKey(10), isTrue);

      final totalBefore = records.totalStars;

      // Libera a leitura da marca de poda: agora `_load()` conclui.
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(
        records.state.containsKey(10),
        isFalse,
        reason:
            'a marca lida do disco (50) descarta a fase 10 também do lado da memória',
      );
      expect(
        records.totalStars,
        lessThan(totalBefore),
        reason: 'a fase indevida não pode inflar o total depois da carga',
      );
    },
  );

  // Achado 1, segunda metade: a marca é uma trava que só aperta. Uma leitura
  // do disco mais atrasada (ou mais antiga) não pode rebaixar uma marca que a
  // própria sessão já avançou em memória via poda.
  test(
    'a marca não regride: uma marca menor vinda do disco não rebaixa a da memória',
    () async {
      final storage = _StalePrunedBelowStorage(3);
      final records = CampaignRecords(storage: storage);
      addTearDown(records.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(records.prunedBelow, 3);

      // Uma poda nesta sessão empurra a marca em memória para além do disco.
      for (int n = 1; n <= kRecordWindow + 5; n++) {
        records.record(n, stars: 3, score: 100);
      }
      final prunedByMemory = records.prunedBelow;
      expect(prunedByMemory, greaterThan(3));

      // Uma segunda releitura do mesmo disco (marca desatualizada em 3) não
      // pode rebaixar a marca que a memória já avançou sozinha.
      await records.debugReload();

      expect(records.prunedBelow, prunedByMemory);
    },
  );
}
