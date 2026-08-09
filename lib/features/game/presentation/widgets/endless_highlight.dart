import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';

/// Chave do destaque do Endless.
///
/// Mantém o nome antigo (`endless_card`) de propósito: é por onde os testes
/// abrem o Endless, e a mudança aqui é de layout, não de regra.
const Key endlessCardKey = Key('endless_card');

/// Chave do recorde exibido no destaque.
const Key endlessRecordKey = Key('endless_record');

/// Chave da chamada para jogar.
const Key endlessCallToActionKey = Key('endless_cta');

/// O Endless como ilha própria, fora da trilha da campanha.
///
/// Não é uma fase e não pode parecer uma: fase tem objetivo, limite e um fim,
/// enquanto o Endless é o modo que não acaba e vale recorde. Enfileirá-lo entre
/// os pins ensinaria a coisa errada — daí o formato, a cor e a posição serem
/// deliberadamente diferentes de tudo no mapa.
class EndlessHighlight extends StatelessWidget {
  const EndlessHighlight({
    super.key,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.highScore,
    required this.onTap,
  });

  final bool isUnlocked;

  /// Fase que precisa ser concluída para liberar.
  final int unlockedAt;

  final int highScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Opacity(
      opacity: isUnlocked ? 1 : 0.45,
      child: Container(
        key: endlessCardKey,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B1B4D), Color(0xFF11324A)],
          ),
          border: Border.all(
            color: isUnlocked
                ? AppColors.digit3.withValues(alpha: 0.75)
                : AppColors.darkBorder,
            width: 2,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: AppColors.digit3.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: isUnlocked ? _handleTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.digit3,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.endlessHighlightTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (isUnlocked)
                              Text(
                                l10n.endlessBestScore(highScore),
                                key: endlessRecordKey,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.digit3,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              )
                            else
                              Text(
                                l10n.endlessLockedHint(unlockedAt),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!isUnlocked)
                        const Icon(
                          Icons.lock_outline,
                          color: Colors.white38,
                          size: 24,
                        ),
                    ],
                  ),
                  // A chamada tem linha própria, e não um canto da primeira.
                  // Dividindo a linha com o título e a legenda, numa tela de
                  // 393pt sobravam 140pt para o texto: o título quebrava em
                  // duas linhas e "Sua melhor pontuação" saía truncada.
                  if (isUnlocked) ...[
                    const SizedBox(height: 12),
                    GameButton(
                      key: endlessCallToActionKey,
                      label: l10n.endlessCta,
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.digit3,
                      fontSize: 15,
                      onPressed: _handleTap,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    // Som do próprio sistema: nenhum pacote de áudio, nenhum arquivo no bundle,
    // e o ajuste de som do aparelho é respeitado sem código nosso.
    SystemSound.play(SystemSoundType.click);
    onTap();
  }
}
