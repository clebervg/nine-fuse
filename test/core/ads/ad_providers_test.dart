import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/ads/rewarded_ad_service.dart';
import 'package:nine_fuse/features/game/presentation/widgets/bomb_offer_dialog.dart';
import 'package:nine_fuse/features/game/presentation/widgets/brush_offer_dialog.dart';

class _Ad implements RewardedAdHandle {
  @override
  Future<bool> show() async => true;

  @override
  void dispose() {}
}

/// Rede de mentira que anota de qual unidade cada anúncio foi pedido.
class _RecordingPort implements RewardedAdPort {
  final List<String> requested = [];

  @override
  Future<RewardedAdHandle?> load(String unitId) async {
    requested.add(unitId);
    return _Ad();
  }
}

void main() {
  test(
    'com o AdMob ligado, Bomba e Pincel pedem cada um a sua unidade',
    () async {
      // Até aqui os dois funis nunca chegavam ao AdMob: o padrão "paga sem rede"
      // valia também no release.
      final port = _RecordingPort();
      final container = ProviderContainer(
        overrides: [
          ...admobOverrides(),
          bombAdServiceProvider.overrideWith(
            (ref) => RewardedAdService(port: port, unitId: 'bomba'),
          ),
          brushAdServiceProvider.overrideWith(
            (ref) => RewardedAdService(port: port, unitId: 'pincel'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(bombAdProvider)(), isTrue);
      expect(await container.read(brushAdProvider)(), isTrue);
      expect(port.requested, containsAllInOrder(['bomba', 'pincel']));
    },
  );
}
