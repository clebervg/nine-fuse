import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/theme/app_fonts.dart';
import 'package:nine_fuse/core/theme/nf_tokens.dart';
import 'package:nine_fuse/core/widgets/nf_back_button.dart';
import 'package:nine_fuse/core/widgets/nf_background.dart';
import 'package:nine_fuse/core/widgets/nf_modal.dart';
import 'package:nine_fuse/core/widgets/nf_text.dart';
import 'package:nine_fuse/core/widgets/privacy_dialog.dart';
import 'package:nine_fuse/features/game/domain/game_settings.dart';
import 'package:nine_fuse/features/game/presentation/widgets/game_dialog.dart';
import 'package:nine_fuse/features/game/providers/settings.dart';
import 'package:nine_fuse/features/game/providers/tutorial.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chaves para os testes endereçarem cada controle.
const Key settingsScreenKey = Key('settings_screen');
const Key settingsSoundKey = Key('settings_sound');
const Key settingsVolumeKey = Key('settings_volume');
const Key settingsMusicKey = Key('settings_music');
const Key settingsVibrationKey = Key('settings_vibration');
const Key settingsPrivacyPolicyKey = Key('settings_privacy_policy');
const Key settingsConsentKey = Key('settings_consent');
const Key settingsCreditsKey = Key('settings_credits');
const Key settingsLicensesKey = Key('settings_licenses');
const Key settingsReplayTutorialKey = Key('settings_replay_tutorial');
Key settingsLanguageKey(AppLanguage language) =>
    Key('settings_language_${language.name}');

/// Abre as Configurações por cima da tela atual.
Future<void> openSettings(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// Configurações: som, música, vibração, idioma, privacidade e créditos.
///
/// É uma rota, e não uma caixa, ao contrário da privacidade de antes: são
/// quatro seções, e numa caixa elas não caberiam na altura de um iPhone SE
/// sem rolagem dentro do modal. Toda mudança vale na hora e é gravada — não
/// há botão "salvar", porque um ajuste que só vale depois de confirmar é um
/// ajuste que o jogador acha que não funcionou.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Perguntado **uma vez** ao abrir: um `FutureBuilder` com a chamada no
  /// `build` voltaria ao UMP a cada interruptor tocado.
  late final Future<bool> _consentRequired = ref
      .read(consentServiceProvider)
      .privacyOptionsRequired();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return NfBackground(
      child: Scaffold(
        key: settingsScreenKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: kNfBackButtonLeadingWidth,
          leading: const NfBackButton(),
          centerTitle: true,
          title: NfText.title(l10n.settingsTitle, size: 30),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _SectionLabel(l10n.settingsSectionAudio),
                  _Panel(
                    children: [
                      _SwitchRow(
                        key: settingsSoundKey,
                        icon: Icons.volume_up_rounded,
                        label: l10n.settingsSound,
                        value: settings.soundOn,
                        onChanged: notifier.setSound,
                      ),
                      // Volume só faz sentido com o som ligado: um controle
                      // ativo que não muda nada lê como defeito.
                      if (settings.soundOn)
                        _VolumeRow(
                          label: l10n.settingsVolume,
                          value: settings.soundVolume,
                          onChanged: notifier.setSoundVolume,
                        ),
                      _SwitchRow(
                        key: settingsMusicKey,
                        icon: Icons.music_note_rounded,
                        label: l10n.settingsMusic,
                        value: settings.musicOn,
                        onChanged: notifier.setMusic,
                      ),
                      _SwitchRow(
                        key: settingsVibrationKey,
                        icon: Icons.vibration_rounded,
                        label: l10n.settingsVibration,
                        value: settings.vibrationOn,
                        onChanged: notifier.setVibration,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(l10n.settingsSectionLanguage),
                  _Panel(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            for (final language in AppLanguage.values) ...[
                              if (language != AppLanguage.values.first)
                                const SizedBox(width: 8),
                              Expanded(
                                child: _LanguageChip(
                                  key: settingsLanguageKey(language),
                                  label: switch (language) {
                                    AppLanguage.system =>
                                      l10n.settingsLanguageSystem,
                                    AppLanguage.pt => l10n.settingsLanguagePt,
                                    AppLanguage.en => l10n.settingsLanguageEn,
                                  },
                                  selected: settings.language == language,
                                  onTap: () => notifier.setLanguage(language),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(l10n.settingsSectionPrivacy),
                  _Panel(
                    children: [
                      _LinkRow(
                        key: settingsPrivacyPolicyKey,
                        icon: Icons.privacy_tip_outlined,
                        label: l10n.settingsPrivacyPolicy,
                        // A mesma caixa que o botão do menu abria: texto,
                        // link da política e, no EEE, as opções do UMP.
                        onTap: () => showPrivacyDialog(context),
                      ),
                      // Só onde a lei exige (EEE, Reino Unido): fora dali o
                      // formulário do UMP não tem o que mostrar, e o item
                      // seria um beco sem saída.
                      FutureBuilder<bool>(
                        future: _consentRequired,
                        builder: (context, snapshot) {
                          if (snapshot.data != true) {
                            return const SizedBox.shrink();
                          }
                          return _LinkRow(
                            key: settingsConsentKey,
                            icon: Icons.tune_rounded,
                            label: l10n.settingsConsent,
                            onTap: ref
                                .read(consentServiceProvider)
                                .showPrivacyOptions,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(l10n.settingsSectionAbout),
                  _Panel(
                    children: [
                      // Zera os passos vistos. Os balões das fases 1-3 só
                      // voltam rejogando essas fases; os de estreia de
                      // cobertura e do dock voltam onde couberem.
                      _LinkRow(
                        key: settingsReplayTutorialKey,
                        icon: Icons.school_rounded,
                        label: l10n.settingsReplayTutorial,
                        onTap: () {
                          ref.read(tutorialProvider.notifier).reset();
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                backgroundColor: NfColors.night2,
                                content: Text(
                                  l10n.settingsReplayTutorialDone,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.display,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                        },
                      ),
                      _LinkRow(
                        key: settingsCreditsKey,
                        icon: Icons.auto_awesome_rounded,
                        label: l10n.settingsCredits,
                        onTap: () => _showCredits(context),
                      ),
                      _LinkRow(
                        key: settingsLicensesKey,
                        icon: Icons.description_outlined,
                        label: l10n.settingsLicenses,
                        // As licenças das fontes OFL já são registradas no
                        // `LicenseRegistry` (`AppFonts.registerLicense`), e
                        // aparecem aqui junto com as dos pacotes.
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: l10n.appTitle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sem número de versão: o projeto não tem `package_info_plus`, e um
  /// pacote nativo a mais só para escrever "1.0.0" não se paga.
  void _showCredits(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showNfModal<void>(
      context,
      builder: (dialogContext) => GameDialog(
        title: l10n.creditsTitle,
        accent: NfColors.gem,
        onClose: () => Navigator.of(dialogContext).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.creditsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.45,
                color: NfColors.textSoft,
              ),
            ),
            const SizedBox(height: 16),
            GameButton(
              label: l10n.creditsClose,
              color: AppColors.darkSurface,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rótulo de seção, o mesmo da Loja.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 10),
    child: NfText.label(
      text,
      color: NfColors.textMuted,
      textAlign: TextAlign.start,
    ),
  );
}

/// Painel do Observatório com as linhas separadas por um fio claro.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: NfDecorations.panel(radius: NfRadii.md),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

const TextStyle _rowText = TextStyle(
  fontFamily: AppFonts.display,
  fontWeight: FontWeight.w800,
  fontSize: 16,
  color: Colors.white,
);

/// Linha com interruptor. Ouro ligado, noite apagada — ouro é o que é
/// tocável e valioso; o desligado não pode brilhar como se estivesse ativo.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      leading: Icon(icon, color: value ? NfColors.gold : NfColors.textMuted),
      title: Text(label, style: _rowText),
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NfColors.goldLight
              : NfColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NfColors.goldDeep
              : NfColors.night0,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NfColors.gold
              : NfColors.gem,
        ),
      ),
    ),
  );
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
    child: Row(
      children: [
        const Icon(Icons.volume_down_rounded, color: NfColors.textMuted),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: NfColors.gold,
              inactiveTrackColor: NfColors.night0,
              thumbColor: NfColors.goldLight,
              overlayColor: NfColors.gold.withValues(alpha: 0.2),
            ),
            child: Slider(
              key: settingsVolumeKey,
              value: value,
              divisions: 10,
              semanticFormatterCallback: (v) => '$label ${(v * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Linha que abre algo (caixa, formulário, página).
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: NfColors.goldPale),
    title: Text(label, style: _rowText),
    trailing: const Icon(Icons.chevron_right_rounded, color: NfColors.goldPale),
    onTap: onTap,
  );
}

/// Opção de idioma: ouro quando escolhida, placa da noite quando não.
class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: NfDurations.press,
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NfRadii.sm),
          gradient: selected ? NfDecorations.goldFill : null,
          color: selected ? null : NfColors.night0,
          border: Border.all(
            color: selected ? NfColors.goldDeep : NfColors.gem,
            width: 2,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: selected ? NfColors.goldText : NfColors.textSoft,
            ),
          ),
        ),
      ),
    ),
  );
}
