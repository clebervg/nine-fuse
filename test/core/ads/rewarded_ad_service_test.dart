import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/rewarded_ad_service.dart';

/// Um anúncio de mentira: registra se foi exibido e se foi devolvido.
class _FakeAd implements RewardedAdHandle {
  _FakeAd({this.earns = true});

  final bool earns;
  int shows = 0;
  int disposals = 0;

  @override
  Future<bool> show() async {
    shows++;
    return earns;
  }

  @override
  void dispose() => disposals++;
}

/// Uma rede de anúncios de mentira, com fila programável de respostas.
class _FakePort implements RewardedAdPort {
  _FakePort(this._queue);

  final List<_FakeAd?> _queue;
  final List<String> requested = [];
  int get loads => requested.length;

  @override
  Future<RewardedAdHandle?> load(String unitId) async {
    requested.add(unitId);
    return _queue.isEmpty ? null : _queue.removeAt(0);
  }
}

/// Uma rede que estoura em vez de responder — o caso do plugin nativo ausente,
/// que devolve `MissingPluginException` do canal de plataforma.
class _ThrowingPort implements RewardedAdPort {
  int loads = 0;

  @override
  Future<RewardedAdHandle?> load(String unitId) async {
    loads++;
    throw StateError('sem plugin nativo');
  }
}

void main() {
  const unit = 'unit-de-teste';

  group('rede que estoura', () {
    test('o preload que falha não deixa o serviço pendurado', () async {
      // O sintoma real: o `Completer` da porta nunca completava, então
      // `_loading` nunca limpava e **todo** preload seguinte era engolido — o
      // serviço ficava morto para o resto da sessão.
      final port = _ThrowingPort();
      final service = RewardedAdService(port: port, unitId: unit);

      await service.preload().timeout(const Duration(seconds: 1));
      expect(service.isReady, isFalse);

      await service.preload().timeout(const Duration(seconds: 1));

      expect(
        port.loads,
        2,
        reason: 'a segunda tentativa foi engolida por uma carga fantasma',
      );
    });

    test('exibir com a rede estourando responde que não pagou', () async {
      final service = RewardedAdService(port: _ThrowingPort(), unitId: unit);

      expect(await service.show().timeout(const Duration(seconds: 1)), isFalse);
    });
  });

  group('preload', () {
    test('guarda o anúncio antes de alguém pedir', () async {
      final ad = _FakeAd();
      final port = _FakePort([ad]);
      final service = RewardedAdService(port: port, unitId: unit);

      await service.preload();

      expect(port.loads, 1);
      expect(service.isReady, isTrue);
      expect(
        ad.shows,
        0,
        reason: 'o preload exibiu o anúncio em vez de só carregá-lo',
      );
    });

    test('não carrega um segundo com um já guardado', () async {
      // Carregar por cima vazaria o primeiro: a rede cobra memória por anúncio
      // vivo, e o que foi substituído nunca seria exibido nem devolvido.
      final port = _FakePort([_FakeAd(), _FakeAd()]);
      final service = RewardedAdService(port: port, unitId: unit);

      await service.preload();
      await service.preload();

      expect(port.loads, 1);
    });

    test('a rede sem anúncio deixa o serviço vazio, e não quebrado', () async {
      final port = _FakePort([null]);
      final service = RewardedAdService(port: port, unitId: unit);

      await service.preload();

      expect(service.isReady, isFalse);
    });
  });

  group('exibição', () {
    test('o anúncio guardado é exibido sem nova carga', () async {
      final ad = _FakeAd();
      final port = _FakePort([ad, _FakeAd()]);
      final service = RewardedAdService(port: port, unitId: unit);
      await service.preload();

      final earned = await service.show();

      expect(earned, isTrue);
      expect(ad.shows, 1);
      expect(port.loads, 2, reason: 'o serviço não repôs o estoque');
    });

    test('sem estoque, carrega na hora em vez de recusar', () async {
      // O convite já está aberto e o jogador tocou em "assistir": responder
      // "não tem anúncio" porque o preload não terminou seria perder a
      // conversão por um detalhe de sincronia.
      final ad = _FakeAd();
      final port = _FakePort([ad]);
      final service = RewardedAdService(port: port, unitId: unit);

      final earned = await service.show();

      expect(earned, isTrue);
      expect(ad.shows, 1);
    });

    test('sem anúncio nenhum, responde que não pagou', () async {
      final service = RewardedAdService(port: _FakePort([]), unitId: unit);

      expect(await service.show(), isFalse);
    });

    test('anúncio fechado antes do fim não paga', () async {
      // A rede distingue "assistiu" de "fechou no meio", e o prêmio é do
      // primeiro caso. Pagar os dois transformaria o anúncio em um botão.
      final port = _FakePort([_FakeAd(earns: false)]);
      final service = RewardedAdService(port: port, unitId: unit);
      await service.preload();

      expect(await service.show(), isFalse);
    });

    test('o anúncio exibido é devolvido, e não fica em estoque', () async {
      // Um anúncio premiado só pode ser exibido uma vez; guardá-lo daria um
      // segundo prêmio de graça na próxima chamada.
      final ad = _FakeAd();
      final port = _FakePort([ad, null]);
      final service = RewardedAdService(port: port, unitId: unit);
      await service.preload();

      await service.show();

      expect(ad.disposals, 1);
      expect(service.isReady, isFalse);
    });
  });

  group('dispose', () {
    test('o estoque não exibido é devolvido ao fechar o serviço', () async {
      final ad = _FakeAd();
      final service = RewardedAdService(port: _FakePort([ad]), unitId: unit);
      await service.preload();

      service.dispose();

      expect(ad.disposals, 1);
      expect(service.isReady, isFalse);
    });
  });
}
