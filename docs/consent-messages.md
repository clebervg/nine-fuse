# Mensagens de consentimento e declarações de privacidade

Textos prontos para copiar. **Revise antes de usar**: eles descrevem o app como
está hoje (AdMob apenas, sem Firebase). Ao adicionar analytics ou crash
reporting, atualize tudo aqui e a política de privacidade.

> O formulário de consentimento (UMP) é configurado no **AdMob**, não no Google
> Play. O Play Console recebe só as seções 3 e 4.

## 1. AdMob → Privacidade e mensagens

Caminho: AdMob › **Privacidade e mensagens**.

### 1.1 Mensagem do GDPR (Europa e Reino Unido)
1. **Criar mensagem › Regulamentações europeias**.
2. Apps: selecione o **NineFuse** (Android e, depois, iOS).
3. Tipo de mensagem: **Consentimento** com as opções *Consentir*,
   *Gerenciar opções* e *Não consentir* (padrão do Google).
4. Idiomas: ao menos **Português (Brasil)** e **Inglês**.
5. Texto personalizável (campo de descrição, se disponível):

   - **PT:** "O NineFuse é gratuito e é mantido com anúncios. Você escolhe se
     eles podem usar o identificador do seu aparelho para serem mais
     relevantes. Você pode mudar essa escolha a qualquer momento."
   - **EN:** "NineFuse is free and supported by ads. You choose whether they
     may use your device identifier to be more relevant. You can change this
     choice at any time."
6. **Publicar**. A mensagem só aparece para o usuário **depois de publicada**.

### 1.2 Mensagem de regulamentações dos EUA (opcional)
Só se for distribuir nos EUA com leis estaduais (CCPA etc.). Mesmo caminho,
**Regulamentações de estados dos EUA**.

### 1.3 Mensagem do ATT / IDFA (iOS) — quando o app iOS for cadastrado
1. **Criar mensagem › Mensagem do IDFA**.
2. Texto explicativo mostrado **antes** do diálogo do sistema:
   - **PT:** "Para manter o NineFuse gratuito, mostramos anúncios. Na próxima
     tela, permitir o acompanhamento nos ajuda a exibir anúncios mais
     relevantes. Você pode recusar e continuar jogando normalmente."
   - **EN:** "To keep NineFuse free, we show ads. On the next screen, allowing
     tracking helps us show more relevant ads. You can decline and keep playing
     as usual."

## 2. Texto do diálogo do sistema (ATT)

Já está no `ios/Runner/Info.plist` (`NSUserTrackingUsageDescription`), em PT e
EN no mesmo texto:

> Usamos o identificador de publicidade para mostrar anúncios mais relevantes
> para você. / We use the advertising identifier to show you more relevant ads.

Para localizar de verdade (um texto por idioma), crie
`ios/Runner/pt-BR.lproj/InfoPlist.strings` e `en.lproj/InfoPlist.strings` com a
chave `NSUserTrackingUsageDescription`.

## 3. Google Play Console → Conteúdo do app

### 3.1 ID de publicidade
**Política e programas › Conteúdo do app › ID de publicidade**
- O app usa o ID de publicidade? **Sim**
- Finalidades: **Publicidade ou marketing**
  (acrescente **Análise** só quando o Firebase Analytics entrar).

### 3.2 Anúncios
- O app contém anúncios? **Sim**.

### 3.3 Segurança dos dados
Confira também a página do Google "Declarações de segurança de dados do
AdMob", que lista o que o SDK coleta, e prevalece sobre a lista abaixo.

| Pergunta | Resposta |
|---|---|
| O app coleta ou compartilha dados do usuário? | **Sim** (pelo SDK de anúncios) |
| Dados criptografados em trânsito? | **Sim** |
| O usuário pode pedir a exclusão dos dados? | **Não** coletamos dados próprios; progresso fica só no aparelho |

Tipos de dados (todos **compartilhados com o Google/AdMob**, finalidade
**Publicidade ou marketing**, **não opcionais** para os anúncios):
- **Identificadores do dispositivo ou outros** (ID de publicidade)
- **Local aproximado** (derivado do IP)
- **Atividade no app › Interações no app** (interação com anúncios)
- **Desempenho do app › Diagnósticos**

Sem dados de: contas, contatos, mensagens, fotos, localização precisa,
pagamentos, saúde.

### 3.4 Política de privacidade
Cole o URL público da política (ver `docs/privacy_policy.md` e o README).

### 3.5 Público-alvo
O app **não é direcionado a crianças**. Marque públicos de 13+ (ou 18+). Se
marcar crianças, a Política para Famílias muda as regras de anúncio.

## 4. Antes de publicar, confira

- [ ] Mensagem do GDPR **publicada** no AdMob (senão o formulário nunca abre).
- [ ] Política de privacidade no ar, com e-mail de contato real.
- [ ] Declarações do Play iguais ao que a política diz.
- [ ] Testado em aparelho com região da UE (use `ConsentDebugSettings` com o
      ID do aparelho de teste) para ver o formulário aparecer.
