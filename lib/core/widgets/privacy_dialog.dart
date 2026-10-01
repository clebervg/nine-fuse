import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nine_fuse/core/ads/ad_providers.dart';
import 'package:nine_fuse/core/constants/app_colors.dart';
import 'package:nine_fuse/core/privacy/privacy_policy.dart';
import 'package:nine_fuse/l10n/app_localizations.dart';

/// Chaves para os testes endereçarem cada ação.
const privacyPolicyButtonKey = Key('privacy_policy_button');
const privacyAdOptionsButtonKey = Key('privacy_ad_options_button');

/// Caixa de privacidade: o link da política e, onde a lei exige (EEE), a
/// reabertura das opções de anúncio do UMP.
///
/// É `showDialog` e não uma tela, pelo mesmo motivo da loja de moedas: o ponto
/// de entrada vive na AppBar e a caixa é puramente informativa.
Future<void> showPrivacyDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PrivacyDialog(),
  );
}

class _PrivacyDialog extends ConsumerWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(consentServiceProvider);

    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      title: Text(l10n.privacyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.privacyBody),
          const SizedBox(height: 16),
          if (kPrivacyPolicyUrl.isNotEmpty)
            TextButton.icon(
              key: privacyPolicyButtonKey,
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.privacyPolicyLink),
              onPressed: openPrivacyPolicy,
            ),
          // Só aparece quando o UMP diz que o usuário precisa poder rever a
          // escolha; fora do EEE o botão seria um beco sem saída.
          FutureBuilder<bool>(
            future: consent.privacyOptionsRequired(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return TextButton.icon(
                key: privacyAdOptionsButtonKey,
                icon: const Icon(Icons.tune),
                label: Text(l10n.privacyAdOptions),
                onPressed: consent.showPrivacyOptions,
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.privacyClose),
        ),
      ],
    );
  }
}
