# Play Console: roteiro do primeiro envio

Respostas prontas para cada formulário do Play Console, baseadas no que o app
faz hoje (2026-11-04). Se o app ganhar Firebase, compra in-app ou login, as
seções "Segurança dos dados" e "Anúncios" mudam.

## 1. Criar o app

- **Nome do app:** NineFuse
- **Idioma padrão:** Português (Brasil) – pt-BR
- **App ou jogo:** Jogo
- **Gratuito ou pago:** Gratuito (não dá para mudar para pago depois)
- Aceitar as declarações (políticas do programa e leis de exportação dos EUA).

## 2. Assinatura

- **Play App Signing:** ativar (é o padrão para app novo). O Google guarda a
  chave de assinatura; a nossa `~/upload-keystore.jks` vira só a **chave de
  upload**. Guardar backup dela e da senha (`android/key.properties`) fora do
  computador.
- O pacote é `com.game.ninefuse`, e não muda depois do primeiro envio.

## 3. Ficha da loja (Presença na loja > Página principal da loja)

Os textos moram no ARB (`storeShortDescription`, `storeFullDescription`), em
`lib/l10n/app_pt.arb` e `app_en.arb`. Copie de lá; ao mudar, mude lá.

| Campo | Limite | Valor |
|---|---|---|
| Nome | 30 | NineFuse |
| Descrição curta | 80 | `storeShortDescription` |
| Descrição completa | 4000 | `storeFullDescription` |
| Ícone | 512x512 PNG | `dist/store/play_store_icon_512.png` |
| Gráfico de destaque | 1024x500 | `dist/store/play_feature_graphic_pt.png` (en: `_en`) |
| Capturas de celular | 2 a 8, lado maior ≤ 2x o menor | `dist/store/screenshots/` |

Adicionar a tradução **English (United States) – en-US** com os textos do
`app_en.arb` e o gráfico `_en`.

- **Categoria:** Jogo > Quebra-cabeça
- **Tags:** quebra-cabeça, match 3, números (as que a lista oferecer)
- **E-mail de contato:** ninefusegames@gmail.com
- **Site:** https://sites.google.com/view/ninefuse (opcional)
- **Política de privacidade:** https://sites.google.com/view/ninefuse

## 4. Conteúdo do app (Política > Conteúdo do app)

### Política de privacidade
`https://sites.google.com/view/ninefuse`

### Anúncios
**Sim, o app contém anúncios** (AdMob: premiados e intersticial).

### Acesso ao app
**Todas as funcionalidades estão disponíveis sem acesso especial** (não há
login).

### Classificação do conteúdo (questionário IARC)
- Categoria: **Jogo**
- Violência, medo, sexo, linguagem imprópria, drogas: **Não** em tudo.
- Jogos de azar simulados: **Não**. A roleta diária dá prêmios do próprio jogo,
  de graça, sem aposta nem compra.
- Os usuários interagem ou trocam conteúdo: **Não** (não há chat nem
  multijogador).
- Compartilha a localização do usuário com outros usuários: **Não**.
- Compras digitais: **Não** (não há compra in-app).
- Resultado esperado: Livre / PEGI 3 / ESRB Everyone.

### Público-alvo
- Faixas: **13-15, 16-17 e 18+**. **Não** marcar faixas abaixo de 13: isso
  coloca o app no programa Famílias, que exige configurar o AdMob para
  crianças (sem anúncio personalizado, só redes certificadas) e revisão
  extra.
- "O app atrai crianças sem querer?": **Não**.

### Apps de notícias, saúde, finanças, governo
**Não** em todos.

### ID de publicidade
**Sim, o app usa o ID de publicidade**. Finalidades: **Publicidade ou
marketing** e **Análise** (é o que o SDK do AdMob faz). O manifesto declara
`com.google.android.gms.permission.AD_ID`.

### Segurança dos dados
O jogo em si não envia nada a servidor nosso: progresso, moedas e
configurações ficam no aparelho. Quem coleta é o **SDK do Google Mobile Ads**.
Respostas segundo o guia do próprio Google para o AdMob
(https://developers.google.com/admob/android/privacy/play-data-disclosure):

- **O app coleta ou compartilha dados de usuário?** Sim.
- **Todos os dados são criptografados em trânsito?** Sim.
- **Os usuários podem pedir a exclusão dos dados?** Não há conta nem dado em
  servidor nosso; responder **Não** (desinstalar apaga tudo o que é local).

| Tipo de dado | Coletado | Compartilhado | Opcional? | Finalidades |
|---|---|---|---|---|
| Local > Local aproximado (pelo IP) | Sim | Sim | Não | Publicidade, Análise, Prevenção de fraudes |
| Atividade no app > Interações com o app | Sim | Sim | Não | Publicidade, Análise, Prevenção de fraudes |
| Informações e desempenho do app > Registros de falhas, Diagnóstico | Sim | Sim | Não | Publicidade, Análise, Prevenção de fraudes |
| IDs do dispositivo ou outros > ID de publicidade | Sim | Sim | Não | Publicidade, Análise, Prevenção de fraudes |

Nada de nome, e-mail, contatos, fotos, arquivos, mensagens, pagamentos ou
localização precisa.

## 5. Teste fechado (obrigatório em conta pessoal nova)

Conta pessoal criada depois de novembro de 2023 só libera produção depois de
um **teste fechado com pelo menos 12 testadores inscritos por 14 dias
seguidos**. Conta de organização (com D-U-N-S) não tem essa exigência.

1. Testar e lançar > Teste fechado > criar faixa (ex.: "Alfa").
2. Testadores: lista de e-mails (contas Google) ou um Grupo do Google.
3. Criar versão > enviar `build/app/outputs/bundle/release/app-release.aab`.
   Nome da versão: 1.0.0 (1). Notas: "Primeira versão de teste."
4. Enviar para revisão. Depois de aprovada, mandar o link de inscrição aos
   testadores; cada um precisa **aceitar** e instalar pela Play Store.
5. Passados os 14 dias com 12+ inscritos, pedir acesso à produção
   (Painel > Solicitar acesso à produção), com as respostas sobre o teste.

Cada novo `.aab` enviado precisa de um `versionCode` maior: subir
`version: 1.0.0+1` no `pubspec.yaml` (por exemplo `1.0.1+2`) e regerar com
`tool/build_release.sh`.

## 6. Depois de publicar

- AdMob > Apps > NineFuse > Configurações do app > **Vincular à loja**.
- Publicar a mensagem do GDPR em AdMob > Privacidade e mensagens (textos em
  `docs/consent-messages.md`).
- Conferir em Pacotes de apps > Detalhes o tamanho de download real.
