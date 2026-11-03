"""Modelo de renda diária de moedas e boosters, por perfil de jogador.

Uso: python3 tool/economy_income_model.py

Não é simulação de partida (essa é a `simulate_economy.dart`): é a conta de
quanto cada torneira paga por dia, para um jogador que vence N fases. Serve
para recalibrar a economia com número na mão. Os valores abaixo espelham
`lib/features/game/domain/economy.dart`, `daily_reward.dart`,
`daily_missions.dart` e `daily_spin.dart` — ao mudar um deles, mude aqui.

Premissas (estimativas, sem dados de jogador real ainda):
- estrelas por vitória nova: 2,2-2,4;
- um baú a cada 10 fases vencidas (100 nos capítulos 1-20, 50 depois);
- uma roleta grátis por dia; recompensa diária todos os dias;
- vídeos de moeda e de booster ficam de fora: são receita, não economia.
"""

PRICES = {'hammer': 150, 'brush': 150, 'bomb': 200}
COINS_PER_STAR = 5
CHEST = 100  # capítulos 1-20; depois, LATE_CHEST
LATE_CHEST = 50
ROULETTE_COINS = [10, 25, 50, 100, 200]  # + 3 fatias de booster, 8 no total
DAILY = [(10, 0), (15, 0), (20, 0), (0, 1), (25, 0), (30, 0), (50, 1)]
MISSIONS = [10, 15, 25]  # fácil, média, difícil (valor típico)
MISSIONS_BONUS = 20

BOOSTER = sum(PRICES.values()) / len(PRICES)


def day_income(wins, stars_per_win, missions_done, nova_coins, chest=CHEST):
    coins = wins * stars_per_win * COINS_PER_STAR + wins * chest / 10
    coins += sum(ROULETTE_COINS) / 8 + sum(c for c, _ in DAILY) / 7
    coins += sum(MISSIONS[:missions_done])
    coins += MISSIONS_BONUS if missions_done == 3 else 0
    coins += nova_coins
    free = 3 / 8 + sum(b for _, b in DAILY) / 7
    return coins, free


if __name__ == '__main__':
    for name, wins, stars, missions, nova in [
        ('casual (2 fases/dia)', 2, 2.2, 1, 0),
        ('engajado (5 fases/dia)', 5, 2.3, 3, 10),
        ('intenso (12 fases/dia)', 12, 2.4, 3, 30),
    ]:
        for label, chest in [('cap. 1-20', CHEST), ('cap. 21+', LATE_CHEST)]:
            coins, free = day_income(wins, stars, missions, nova, chest)
            total = coins / BOOSTER + free
            print(f'{name:24} {label:9} moedas/dia {coins:4.0f}  '
                  f'boosters/dia {total:4.2f}  por fase {total / wins:4.2f}')
