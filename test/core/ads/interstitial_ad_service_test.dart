import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/interstitial_ad_service.dart';

class _FakeAd implements InterstitialAdHandle {
  int shows = 0;
  int disposals = 0;

  @override
  Future<void> show() async => shows++;

  @override
  void dispose() => disposals++;
}

class _FakePort implements InterstitialAdPort {
  _FakePort(this._queue);

  final List<_FakeAd?> _queue;
  int loads = 0;

  @override
  Future<InterstitialAdHandle?> load(String unitId) async {
    loads++;
    return _queue.isEmpty ? null : _queue.removeAt(0);
  }
}

class _ThrowingPort implements InterstitialAdPort {
  @override
  Future<InterstitialAdHandle?> load(String unitId) async =>
      throw StateError('sem plugin nativo');
}

void main() {
  const unit = 'interstitial-de-teste';
  const enough = kInterstitialMinPlayTime;

  InterstitialAdService serviceWith(List<_FakeAd?> ads) =>
      InterstitialAdService(port: _FakePort(ads), unitId: unit);

  Future<bool> show(
    InterstitialAdService service, {
    InterstitialMoment moment = InterstitialMoment.afterVictory,
    int progress = 10,
    bool adsRemoved = false,
  }) => service.maybeShow(
    moment: moment,
    campaignProgress: progress,
    adsRemoved: adsRemoved,
  );

  group('regra', () {
    test('mostra pós-vitória com 45 s de jogo e estoque', () async {
      final ad = _FakeAd();
      final service = serviceWith([ad]);
      await service.preload();
      service.addPlayTime(enough);

      expect(await show(service), isTrue);
      expect(ad.shows, 1);
      expect(ad.disposals, 1);
    });

    test('a saída para o mapa também pode mostrar', () async {
      final service = serviceWith([_FakeAd()]);
      await service.preload();
      service.addPlayTime(enough);

      expect(await show(service, moment: InterstitialMoment.exitToMap), isTrue);
    });

    test('a derrota nunca mostra, nem com tempo de sobra', () async {
      final ad = _FakeAd();
      final service = serviceWith([ad]);
      await service.preload();
      service.addPlayTime(const Duration(minutes: 30));

      expect(
        await show(service, moment: InterstitialMoment.afterDefeat),
        isFalse,
      );
      expect(ad.shows, 0);
    });

    test('nada antes de vencer a fase 3 (onboarding)', () async {
      final service = serviceWith([_FakeAd()]);
      await service.preload();
      service.addPlayTime(const Duration(minutes: 30));

      expect(
        await show(service, progress: kInterstitialOnboardingLevels - 1),
        isFalse,
      );
      expect(
        await show(service, progress: kInterstitialOnboardingLevels),
        isTrue,
      );
    });

    test(
      'menos de 45 s de jogo não mostra — nem o primeiro da sessão',
      () async {
        final service = serviceWith([_FakeAd()]);
        await service.preload();
        service.addPlayTime(enough - const Duration(seconds: 1));

        expect(await show(service), isFalse);

        service.addPlayTime(const Duration(seconds: 1));
        expect(await show(service), isTrue);
      },
    );

    test('o relógio zera ao exibir: o segundo espera outros 45 s', () async {
      final service = serviceWith([_FakeAd(), _FakeAd()]);
      await service.preload();
      service.addPlayTime(enough);
      expect(await show(service), isTrue);
      // A reposição é disparada sem `await` dentro do serviço.
      await service.preload();

      expect(service.playSinceLast, Duration.zero);
      expect(await show(service), isFalse);

      service.addPlayTime(enough);
      expect(await show(service), isTrue);
    });

    test('o passe sem anúncios desliga o intersticial', () async {
      final service = serviceWith([_FakeAd()]);
      await service.preload();
      service.addPlayTime(enough);

      expect(await show(service, adsRemoved: true), isFalse);
    });

    test('tempo negativo não desconta jogo', () {
      final service = serviceWith(const []);
      service.addPlayTime(enough);
      service.addPlayTime(const Duration(seconds: -30));

      expect(service.playSinceLast, enough);
    });
  });

  group('estoque', () {
    test(
      'sem estoque pula sem esperar a rede e repõe para a próxima',
      () async {
        final port = _FakePort([null, _FakeAd()]);
        final service = InterstitialAdService(port: port, unitId: unit);
        await service.preload();
        service.addPlayTime(enough);

        expect(await show(service), isFalse);
        // Pular não gasta o relógio: a próxima oportunidade ainda vale.
        expect(service.playSinceLast, enough);

        await service.preload();
        expect(await show(service), isTrue);
      },
    );

    test('a rede que estoura vale como sem estoque', () async {
      final service = InterstitialAdService(
        port: _ThrowingPort(),
        unitId: unit,
      );
      await service.preload().timeout(const Duration(seconds: 1));
      service.addPlayTime(enough);

      expect(service.isReady, isFalse);
      expect(await show(service), isFalse);
    });

    test('a porta padrão nunca tem anúncio', () async {
      final service = InterstitialAdService(
        port: const NoInterstitialAdPort(),
        unitId: unit,
      );
      await service.preload();
      service.addPlayTime(enough);

      expect(await show(service), isFalse);
    });

    test('a música pausa só em volta da exibição', () async {
      final calls = <String>[];
      final service = InterstitialAdService(
        port: _FakePort([_FakeAd()]),
        unitId: unit,
        onShowStart: () => calls.add('start'),
        onShowEnd: () => calls.add('end'),
      );
      service.addPlayTime(enough);

      // Sem estoque: nenhum anúncio na tela, nada de pausar a música.
      expect(await show(service), isFalse);
      expect(calls, isEmpty);

      await service.preload();
      expect(await show(service), isTrue);
      expect(calls, ['start', 'end']);
    });
  });
}
