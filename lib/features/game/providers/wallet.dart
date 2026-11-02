import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/features/game/domain/economy.dart';
import 'package:nine_fuse/features/game/providers/game_storage.dart';

/// Os boosters que a loja vende por moeda, cada um com o preço do código.
///
/// Mora aqui, e não no domínio, porque só existe para a compra **fora** de uma
/// partida: dentro dela cada booster tem o seu mixin e o seu `grant*`.
enum BoosterKind {
  hammer(kHammerCoinPrice),
  bomb(kBombCoinPrice),
  brush(kBrushCoinPrice);

  const BoosterKind(this.coinPrice);

  final int coinPrice;
}

/// O que o jogador tem, visto de fora de uma partida.
@immutable
class Wallet {
  const Wallet({
    this.coins = 0,
    this.hammers = 0,
    this.bombs = 0,
    this.brushes = 0,
    this.claimedChests = const <int>{},
  });

  final int coins;

  /// Espelho do estoque de martelos, para o mapa poder mostrá-lo.
  ///
  /// Não é uma segunda fonte de verdade: a autoridade é o disco, e dentro de uma
  /// fase quem consome continua sendo `GameState.hammerCount`, que já é relido a
  /// cada `startLevel`. Este campo existe porque o mapa da saga vive **fora** de
  /// qualquer partida e não tem `GameState` de onde ler.
  final int hammers;

  /// Espelhos de bomba e pincel, pela mesma razão do [hammers]: a loja vive
  /// fora de qualquer partida e precisa mostrar quanto o jogador já tem antes
  /// de ele decidir comprar mais.
  final int bombs;
  final int brushes;

  final Set<int> claimedChests;

  bool canAfford(int price) => coins >= price;

  /// Estoque espelhado de [kind].
  int stockOf(BoosterKind kind) => switch (kind) {
    BoosterKind.hammer => hammers,
    BoosterKind.bomb => bombs,
    BoosterKind.brush => brushes,
  };

  bool hasClaimedChest(int chapter) => claimedChests.contains(chapter);

  Wallet copyWith({
    int? coins,
    int? hammers,
    int? bombs,
    int? brushes,
    Set<int>? claimedChests,
  }) => Wallet(
    coins: coins ?? this.coins,
    hammers: hammers ?? this.hammers,
    bombs: bombs ?? this.bombs,
    brushes: brushes ?? this.brushes,
    claimedChests: claimedChests ?? this.claimedChests,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallet &&
          coins == other.coins &&
          hammers == other.hammers &&
          bombs == other.bombs &&
          brushes == other.brushes &&
          setEquals(claimedChests, other.claimedChests);

  @override
  int get hashCode => Object.hash(
    coins,
    hammers,
    bombs,
    brushes,
    Object.hashAllUnordered(claimedChests),
  );

  @override
  String toString() =>
      'Wallet($coins moedas, $hammers martelos, $bombs bombas, '
      '$brushes pincéis)';
}

/// Lê e move o saldo do jogador.
class WalletNotifier extends StateNotifier<Wallet> {
  WalletNotifier({GameStorage? storage})
    : _storage = storage ?? const PrefsGameStorage(),
      super(const Wallet());

  final GameStorage _storage;

  /// Relê tudo do disco.
  ///
  /// Chamado ao abrir o mapa e ao voltar de uma fase, e não só no construtor:
  /// uma partida pode ter gasto ou ganho martelo enquanto o mapa estava fora de
  /// cena. É o mesmo remédio de `EndlessHighScore.refresh` e de
  /// `HammerBooster.refreshHammers`.
  ///
  /// Uma leitura que chega depois de o saldo ter mudado em memória é
  /// descartada: o disco está velho, e adotá-lo apagaria moedas recém-creditadas.
  Future<void> refresh() async {
    final before = state;
    try {
      final coins = await _storage.readCoins();
      final hammers = await _storage.readHammerCount();
      final bombs = await _storage.readBombCount();
      final brushes = await _storage.readBrushCount();
      final chests = await _storage.readClaimedChests();
      if (!mounted || state != before) return;

      state = Wallet(
        coins: coins,
        hammers: hammers,
        bombs: bombs,
        brushes: brushes,
        claimedChests: chests,
      );
    } catch (error, stack) {
      debugPrint('Falha ao ler a carteira: $error\n$stack');
    }
  }

  /// Soma [amount] moedas e grava.
  ///
  /// O tilintar mora aqui, e não em cada tela que credita, porque são cinco
  /// torneiras (vídeo na loja, no convite, no header, estrela, Nova) e o som é
  /// o mesmo para todas. [chime] falso é só para o estorno de uma compra que
  /// falhou: devolver moeda não é ganhar moeda.
  void creditCoins(int amount, {bool chime = true}) {
    if (amount <= 0) return;
    state = state.copyWith(coins: state.coins + amount);
    _persistCoins();
    if (chime) GameAudio.play(SoundEvent.coins);
  }

  /// Debita [price] se houver saldo. Devolve se a compra aconteceu.
  ///
  /// Não credita nada em troca: quem entrega o item é quem chamou. Misturar as
  /// duas coisas aqui obrigaria a carteira a conhecer todo item comprável.
  bool spendCoins(int price) {
    if (!state.canAfford(price)) return false;

    state = state.copyWith(coins: state.coins - price);
    _persistCoins();
    return true;
  }

  /// Compras em andamento, encadeadas: duas compras simultâneas leriam o mesmo
  /// estoque e gravariam o mesmo `estoque + 1` — o jogador pagaria duas vezes
  /// e levaria um item só.
  Future<bool> _purchases = Future.value(true);

  /// Compra uma unidade de [kind] **fora de uma partida** (a loja). Devolve se
  /// a compra aconteceu.
  ///
  /// Dentro da fase a compra não passa por aqui: lá a autoridade do estoque é o
  /// `GameState`, e quem credita é o `grant*` do notifier da partida (a
  /// mini-loja do cartão de início). Gravar no disco por baixo de uma partida
  /// viva deixaria o HUD mostrando um estoque que o próximo `startLevel`
  /// desmentiria.
  ///
  /// Sem o teto de [kMaxBoosterStock]: o teto vale para prêmio gratuito
  /// (roleta). Aqui o jogador pagou pelo item, e recusar a entrega seria cobrar
  /// sem pagar.
  Future<bool> buyBooster(BoosterKind kind) {
    final run = _purchases.then((_) => _buyBooster(kind));
    _purchases = run.catchError((Object _) => false);
    return run;
  }

  Future<bool> _buyBooster(BoosterKind kind) async {
    if (!mounted || !state.canAfford(kind.coinPrice)) return false;

    // Lê o estoque **antes** de debitar: se o disco falhar aqui, nada foi
    // cobrado.
    final int current;
    try {
      current = await _readStock(kind);
    } catch (error, stack) {
      debugPrint('Falha ao ler o estoque de ${kind.name}: $error\n$stack');
      return false;
    }
    if (!mounted || !spendCoins(kind.coinPrice)) return false;

    final next = current + 1;
    try {
      await _writeStock(kind, next);
    } catch (error, stack) {
      // O item não foi entregue: devolve a moeda, em vez de cobrar por nada.
      debugPrint('Falha ao gravar o estoque de ${kind.name}: $error\n$stack');
      if (mounted) creditCoins(kind.coinPrice, chime: false);
      return false;
    }
    if (!mounted) return true;
    state = switch (kind) {
      BoosterKind.hammer => state.copyWith(hammers: next),
      BoosterKind.bomb => state.copyWith(bombs: next),
      BoosterKind.brush => state.copyWith(brushes: next),
    };
    return true;
  }

  Future<int> _readStock(BoosterKind kind) => switch (kind) {
    BoosterKind.hammer => _storage.readHammerCount(),
    BoosterKind.bomb => _storage.readBombCount(),
    BoosterKind.brush => _storage.readBrushCount(),
  };

  Future<void> _writeStock(BoosterKind kind, int count) => switch (kind) {
    BoosterKind.hammer => _storage.writeHammerCount(count),
    BoosterKind.bomb => _storage.writeBombCount(count),
    BoosterKind.brush => _storage.writeBrushCount(count),
  };

  /// Paga o baú de [chapter], uma vez só. Devolve se pagou agora.
  ///
  /// Capítulo acima de `kChapterChestPayableCount` nunca paga — sem essa
  /// guarda, a campanha gerada (infinita) imprimiria moeda para sempre.
  /// Como esses capítulos nunca entram em `claimedChests`, o Set também
  /// fica naturalmente limitado ao teto, sem precisar de poda.
  bool claimChapterChest(int chapter) {
    if (chapter < 1 || chapter > kChapterChestPayableCount) return false;
    if (state.hasClaimedChest(chapter)) return false;

    final chests = {...state.claimedChests, chapter};
    state = state.copyWith(
      coins: state.coins + kChapterChestReward,
      claimedChests: chests,
    );
    // Baú primeiro, moeda depois: se só uma gravação for a sobreviver de uma
    // falha de disco, que seja a marca de "já reclamado" — assim o pior caso é
    // o jogador perder a moeda desta vez, não o baú repagar toda sessão que
    // reabrir o mapa (torneira infinita).
    _persistChests(chests);
    _persistCoins();
    return true;
  }

  /// A gravação é assíncrona e o estado não a espera: travar a UI até o disco
  /// responder seria pagar latência de I/O numa troca de tela. Falha de escrita
  /// custa o saldo na próxima abertura, não a ação de agora.
  Future<void> _persistCoins() async {
    try {
      await _storage.writeCoins(state.coins);
    } catch (error, stack) {
      debugPrint('Falha ao gravar as moedas: $error\n$stack');
    }
  }

  Future<void> _persistChests(Set<int> chests) async {
    try {
      await _storage.writeClaimedChests(chests);
    } catch (error, stack) {
      debugPrint('Falha ao gravar os baús reclamados: $error\n$stack');
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, Wallet>(
  (ref) => WalletNotifier(),
);
