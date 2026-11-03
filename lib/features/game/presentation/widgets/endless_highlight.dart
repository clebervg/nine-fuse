import 'package:flutter/material.dart';
import 'package:nine_fuse/core/audio/audio_service.dart';
import 'package:nine_fuse/core/audio/sound_event.dart';
import 'package:nine_fuse/core/feedback/haptics.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chave do destaque do Endless.
///
/// Mantém o nome antigo (`endless_card`) de propósito: é por onde os testes
/// abrem o Endless, e a mudança aqui é de layout, não de regra.
const Key endlessCardKey = Key('endless_card');

/// Chave do recorde exibido no destaque.
const Key endlessRecordKey = Key('endless_record');

/// Chave da chamada para jogar.
const Key endlessCallToActionKey = Key('endless_cta');

/// O Endless como placa própria, fora da trilha da campanha.
///
/// Não é uma fase e não pode parecer uma: fase tem objetivo, limite e um fim,
/// enquanto o Endless é o modo que não acaba e vale recorde. Enfileirá-lo entre
/// os pins ensinaria a coisa errada — daí ele ser uma placa retangular com gema
/// (os nós da trilha são discos) e morar fora da rolagem.
///
/// **Uma linha só, e é pela altura do mapa.** A placa divide o topo fixo com a
/// do capítulo e o botão de jogar fica fixo embaixo: num iPhone SE, a versão em
/// duas linhas (com a chamada em botão largo) deixava à trilha espaço para um
/// pin e meio. A chamada virou o botão de *play* dourado da direita — o texto
/// dela continua sendo o rótulo para leitor de tela e toque longo.
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
    final radius = BorderRadius.circular(NfRadii.md);

    return Opacity(
      opacity: isUnlocked ? 1 : 0.55,
      child: GestureDetector(
        key: endlessCardKey,
        behavior: HitTestBehavior.opaque,
        onTap: isUnlocked ? _handleTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111A4A), Color(0xFF0A1033)],
            ),
            border: Border.all(
              color: isUnlocked
                  ? const Color(0xFFC98A18)
                  : const Color(0xFF3A4380),
              width: 2,
            ),
            boxShadow: [
              // Blur zero: é a espessura da placa, não uma sombra.
              const BoxShadow(color: Color(0xFF05081C), offset: Offset(0, 4)),
              if (isUnlocked)
                BoxShadow(
                  color: NfColors.gem.withValues(alpha: 0.28),
                  blurRadius: 22,
                ),
            ],
          ),
          child: Row(
            children: [
              _Gem(lit: isUnlocked),
              const SizedBox(width: 12),
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
                        fontFamily: AppFonts.title,
                        color: Colors.white,
                        fontSize: 17,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isUnlocked)
                      Text(
                        l10n.endlessBestScore(highScore),
                        key: endlessRecordKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.number,
                          color: NfColors.gold,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      )
                    else
                      Text(
                        l10n.endlessLockedHint(unlockedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.number,
                          color: NfColors.textSoft,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isUnlocked)
                _PlayButton(label: l10n.endlessCta, onTap: _handleTap)
              else
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.lock_outline,
                    color: Color(0xFF7D86C2),
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    // Mesmo toque do mapa: o efeito do jogo se o arquivo existir, o clique
    // do sistema enquanto não existe.
    GameAudio.play(SoundEvent.buttonTap, fallback: Haptics.click);
    onTap();
  }
}

/// A gema roxa do modo: roxo marca o que é mágico, e o modo sem fim é isso.
class _Gem extends StatelessWidget {
  const _Gem({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: NfDecorations.goldRim,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: lit ? NfDecorations.gemFill : null,
        color: lit ? null : const Color(0xFF1F2A66),
      ),
      child: Icon(
        Icons.all_inclusive_rounded,
        color: lit ? Colors.white : const Color(0xFF7D86C2),
        size: 22,
      ),
    ),
  );
}

/// Botão de *play* dourado: a chamada do modo, compacta.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onTap});

  /// "Superar Recorde": vai para o leitor de tela e para o toque longo.
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    // O rótulo para leitor de tela vem do `Semantics` abaixo; o da dica
    // repetiria a mesma frase.
    excludeFromSemantics: true,
    child: Semantics(
      // Nó próprio: sem isto ele se funde ao toque da placa inteira, e o
      // leitor de tela não teria o botão de jogar para focar.
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: endlessCallToActionKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 40,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NfRadii.sm),
            gradient: NfDecorations.goldFill,
            boxShadow: const [
              BoxShadow(color: NfColors.goldShadow, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: NfColors.goldText,
            size: 30,
          ),
        ),
      ),
    ),
  );
}
