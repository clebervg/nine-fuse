# Teto no baú de capítulo (`claimChapterChest`)

## Contexto

`WalletNotifier.claimChapterChest(int chapter)` (`lib/features/game/providers/wallet.dart:103-118`)
já impede reclamar o **mesmo** capítulo duas vezes (`claimedChests: Set<int>`,
checado via `hasClaimedChest`). O problema não é repetição — é que a
campanha é infinita (Fase 15, `level_generator.dart`): todo capítulo novo,
para sempre, paga `kChapterChestReward = 200` moedas ao ser reclamado. Sem
teto, é impressão de moeda sem limite, e o `Set<int> claimedChests` cresce
um inteiro por capítulo reclamado, sem poda — a mesma classe de vazamento
que `CampaignRecords` já teve e corrigiu com uma marca d'água
(`prunedBelow`).

Hoje `claimChapterChest` não está ligado a nenhuma UI (achado confirmado:
nenhum widget referencia "baú"/"chest" fora do texto genérico em
`coin_sources_card.dart`), então não é bug em produção. Mas o CLAUDE.md já
registra a decisão: "precisa ganhar um teto ou um valor decrescente por
capítulo antes de a Fase B do baú (ainda não construída) o conectar a um
botão." Esta task entrega esse teto — só o fix econômico, sem UI.

## Decisão

**Teto fixo de capítulos pagos.** Só os primeiros `kChapterChestPayableCount`
capítulos pagam baú; capítulos acima disso não creditam nada ao serem
"reclamados".

`kChapterChestPayableCount = 20`, em `lib/features/game/domain/economy.dart`,
ao lado de `kChapterChestReward`.

- Capítulos 1-2 são os artesanais (fases 1-10, `kChapters` em
  `campaign_chapter.dart`); capítulos 3-20 são os primeiros 18 capítulos
  gerados (`kBlockSize = 10` fases cada, `level_generator.dart:19`) — cobre
  até a fase ~190.
- Teto de moeda vitalícia via baú: `20 * kChapterChestReward = 4000`.

Alternativa considerada e descartada: valor decrescente por capítulo
(fórmula amortecendo até um piso, no espírito de `kTighteningFloor` da
Fase 15). Rejeitada por decisão do dono do produto — mais uma fórmula para
calibrar e testar sem necessidade clara, quando um teto fixo já resolve o
problema real (impressão infinita) de forma simples e previsível.

## Mudança em `claimChapterChest`

```dart
bool claimChapterChest(int chapter) {
  if (chapter > kChapterChestPayableCount) return false;
  if (state.hasClaimedChest(chapter)) return false;
  // ...resto inalterado
}
```

Capítulo acima do teto retorna `false` imediatamente — **sem** inserir no
`Set<int> claimedChests` e sem persistir nada. Como o baú nunca paga além
do capítulo 20, o `Set` fica naturalmente limitado a no máximo 20 entradas
para sempre: resolve o vazamento de memória/disco por construção, sem
precisar de uma marca d'água tipo `prunedBelow` — diferente do caso do
`CampaignRecords`, que guardava detalhe por fase (uma estrutura sem teto
óbvio); aqui o teto de capítulos pagos já É o limite estrutural do `Set`.

Não há migração a considerar: o jogo ainda não foi lançado, não há UI de
baú em produção, logo não há capítulo além de 20 já persistido em disco de
nenhum jogador real.

## Testes

Em `test/features/game/providers/wallet_test.dart`, ao lado dos dois
testes existentes de baú:

1. **Capítulo acima do teto (21) não paga:** `claimChapterChest(21)` volta
   `false`, `coins` não muda, `claimedChests` não ganha `21`.
2. **Capítulo exatamente no teto (20) ainda paga:** `claimChapterChest(20)`
   volta `true`, credita `kChapterChestReward` normalmente — trava a borda
   (`>`, não `>=`).
3. **O `Set` nunca cresce além do teto:** reclamar uma sequência de
   capítulos muito além de 20 (ex: 21 a 40) não deixa nenhum vestígio em
   `claimedChests` — trava a garantia central deste fix, não só o caso de
   borda isolado.

## Fora de escopo (decisão explícita)

Nenhuma UI de baú (mapa da saga, indicador de progresso, botão de
resgate) — isso continua sendo a Fase B já registrada no CLAUDE.md, ainda
não desenhada. Esta task só existe para que, quando a Fase B vier, ligar o
botão num `claimChapterChest` já seguro não seja um passo esquecido.
