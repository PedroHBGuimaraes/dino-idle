# Dino Idle — Documento de Planejamento

Jogo mobile idle/casual de dinossauros, feito em Godot 4.6 com apoio do Claude Code.

## Conceito

- **Tema:** o jogador reconstrói uma ilha selvagem cuidando de uma família de dinossauros (e outros répteis pré-históricos) que cresce com o tempo.
- **Plataforma:** Mobile (Android inicialmente), orientação **retrato**.
- **Engine:** Godot 4.6, jogo **2D**.
- **Estilo:** casual e viciante, no molde de idle games (referências de gosto: Archero, Galaxy Defense, jogos de caça-palavra, jogos com tema de dinossauros, idle games em geral).
- **Monetização:** anúncios via AdMob (rewarded ads principalmente).

## Mecânica principal

- **Recurso:** Comida — ganha por toque manual + produção passiva por segundo (soma da produção de todas as espécies desbloqueadas).
- **Progressão dos dinos:** 1 dino por espécie, que sobe de **nível (1 a 100)** gastando comida em cada level up (custo crescente e suave, tipo `custo_base × 1.08^nível`). O sprite visual muda conforme a faixa de nível:
  - Níveis 1–24 → Filhote
  - Níveis 25–49 → Jovem
  - Níveis 50–100 → Adulto
- **Passivas por nível (a cada 25 níveis: 25/50/75/100):** cada espécie tem uma combinação própria de passivas, dando "identidade" a cada dino. Tipos existentes:
  - `species_production_boost` — bônus % na produção da própria espécie
  - `global_production_boost` — bônus % na produção de todas as espécies
  - `tap_value_boost` — bônus % no valor do toque manual
  - `threshold_synergy` — bônus % na produção de todas as espécies acima de um nível X
  - `combo_click_boost` — bônus % crescente a cada 10 cliques seguidos, até um teto (200 cliques), resetando após alguns segundos de inatividade
- **Produção offline:** acumula comida enquanto o app está fechado (teto de 8h), com popup mostrando o total ganho ao reabrir.
- **Objetivo de longo prazo:** desbloquear todas as espécies e levar todas ao nível 100 (coleção completa da "família") — e, depois disso, o **prestígio** (ver abaixo) dá um segundo objetivo, sem teto.

## Sistema de Prestígio

Implementado como resposta ao "e depois da coleção completa, o que mais tem pra fazer?" — reseta o progresso da run em troca de uma moeda permanente.

- **Gatilho:** a partir de **50% de progresso geral da coleção** (`GameManager.get_collection_progress()` — média de nível/100 entre todas as espécies, já existia pro cenário vivo do fundo), não só nos 100%. Justificativa: exigir a coleção 100% completa (as 32 espécies no nível 100) seria tarde demais — o próprio custo geométrico das espécies finais já é um objetivo enorme sozinho. Depois do primeiro prestígio, o botão nunca mais some da UI, mesmo que o progresso da run atual caia de novo abaixo de 50%.
- **Moeda — "Fósseis Ancestrais":** `floor(0.05 × soma dos níveis de toda espécie DESBLOQUEADA)` — só quem já foi desbloqueado conta. Com o piso de 50%, gira em torno de **75-85 Fósseis no primeiro prestígio**; coleção 100% completa dá **160**. Cresce mais rápido a cada prestígio seguinte (produção maior desde o início da run nova).
- **O que reseta:** comida e nível de toda espécie (volta pro nível 1; só quem tem `starts_unlocked` continua desbloqueada) e qualquer buff de anúncio em andamento. **O que NÃO reseta:** conquistas (permanentes por design) e o próprio progresso de prestígio (óbvio, é o que sobrevive).
- **Upgrades (10 no total, `data/prestige/*.tres`):** compráveis várias vezes cada, custo geométrico igual ao level-up de espécie. 6 de produção passiva (+2% a +8% por nível, até +490% todos maxados) e 4 de valor de toque (+3% a +10% por nível, até +415% maxados). Bônus do mesmo grupo somam entre si num único multiplicador (`1.0 + soma`), em vez de multiplicar cada upgrade entre si — evita os números saírem do controle.
- **Persistência:** dobrado no mesmo `user://savegame.json` (chave `"prestige"`) em vez de um arquivo separado — segue o padrão já usado por conquistas/áudio nesse projeto (um único save, sem risco de escritas não-atômicas entre dois arquivos).
- **Testes:** `tests/test_prestige.gd`, script headless (`SceneTree`, sem framework — o projeto não tem GUT/gdUnit) cobrindo reset correto, persistência entre "sessões" via `get_save_state()`/`load_state()`, e o multiplicador batendo entre produção total/por espécie/toque. Roda com `godot --headless -s tests/test_prestige.gd --path .` — precisa ser executado na sua máquina, já que esta sessão não tem o binário do Godot disponível.

Números calibrados como ponto de partida razoável (mesmo raciocínio do balanceamento de espécie: crescimento geométrico suave), não testados com jogadores reais ainda — fáceis de reajustar depois, tudo em `.tres`, sem mexer em código.

## Espécies

- Expandido de 8 para **32 espécies no total** (8 originais + 24 novas), incluindo não só dinossauros como outros répteis pré-históricos:
  - Terrestres (maioria)
  - Voadores (ex. Pteranodonte, Pterodáctilo)
  - Aquáticos (ex. Plesiossauro, Mosassauro, Ictiossauro)
- As 8 espécies originais (ordem de custo crescente): Compsognathus (grátis, inicial), Velociraptor, Estegossauro, Triceratops, Parassaurolofo, Anquilossauro, Braquiossauro, Tiranossauro Rex.
- Curva de custo de desbloqueio entre espécies recalibrada para as 32, validada via `balance-check`.

### Papel dos anúncios (AdMob)

- Assistir anúncio recompensado = 2x produção por 30 min
- Assistir anúncio ao voltar pro jogo = dobra o ganho offline acumulado
- Bônus de comida disponível desde o início do jogo, proporcional à produção atual do jogador (não é mais valor fixo/só liberado depois de progresso)

## Assets

- **Sprites de dinos:** gerados via **PixelLab** (assinatura própria, MCP oficial conectado no Claude Code), mantendo consistência visual entre espécies (gera uma referência, aprova, usa como base pras demais). Pacotes prontos avaliados anteriormente (Pixelsaurs CC0, Dino Family) ficaram como alternativa não utilizada.
  - **Completo para as 32 espécies:** 3 sprites por espécie (Filhote/Jovem/Adulto = 96 no total) + animação de idle no estágio Adulto (5 frames por espécie = 160 no total).
- **Ícones de conquistas:** 12 ícones próprios gerados via PixelLab (um por conquista, ver Sistema de conquistas).
- **Ícones de UI, background da ilha:** também gerados via PixelLab, no mesmo estilo dos dinos.
- **Fonte:** fonte arredondada/casual estilo Fredoka/Baloo.
- **Sons:** efeitos de UI (toque, compra, evolução/level up, clique) gerados via síntese/código pelo Claude Code; música de fundo buscada em banco royalty-free; sistema de volume com toggle de mudo implementado.

## Design visual e "juice" — implementado

- Números flutuantes ao coletar comida
- Partículas de recompensa ao evoluir/desbloquear (efeito ainda sendo refinado, ficou simples na primeira versão)
- Animação idle nos dinos (respirar/balançar levemente)
- Squash & stretch ao tocar a área de alimentar
- Barra de progresso até o próximo nível de cada dino
- Indicador visual de "pronto para subir de nível"
- Transições suaves em popups (fade/escala)
- Parallax leve no background
- Silhueta escura para dinos ainda não desbloqueados (em vez de espaço vazio)
- Scroll vertical na lista de dinos, com indicador de mais conteúdo abaixo
- Indicador "✅ Completo" (com check verde) para dinos no nível/estágio máximo
- Onboarding/tutorial rápido na primeira abertura (dispensável, não repete depois da primeira vez)
- Tela de splash com identidade visual do jogo
- Tela de celebração especial ao completar toda a coleção (todas as espécies no nível máximo)
- Áreas de toque dos botões revisadas para conforto em tela pequena

## Melhorias visuais avançadas — rodada 2 (assets sem limite de orçamento)

Segunda rodada de polimento, decidida após ver o resultado da mesma abordagem no jogo irmão (Dino Merge — ver documento separado), com orçamento de assets liberado (PixelLab):

1. **Animação de transformação no level up/evolução** — efeito de "crescimento" ao subir de nível: escala + squash/stretch, flash de luz, partículas, priorizado nas transições de estágio visual (Filhote→Jovem→Adulto) e aplicado de forma mais sutil em level ups dentro da mesma faixa.
2. **Reação ao tocar num dino específico** — cada dino da lista reage individualmente ao toque direto (animação + som próprio), além da área geral de "alimentar".
3. **Sistema de conquistas/badges** — conjunto de conquistas salvas no save (ex. "primeiro dino no nível 100", "coleção completa", "produção acima de X/seg", "X dias seguidos jogando"), com ícones gerados via PixelLab e tela própria mostrando desbloqueadas/bloqueadas (bloqueadas em silhueta).
4. **Celebrações intermediárias** — confete leve (sem interromper o jogo) ao qualquer dino atingir nível 100 pela primeira vez, além da celebração maior já existente de coleção completa.
5. **Cenário vivo** (se der tempo) — fundo da ilha mudando sutilmente conforme progresso geral (vegetação, dinos decorativos ao fundo, variação de luz por marco), e/ou partículas ambiente passivas (folhas, borboletas).

Itens 1-3 priorizados e validados primeiro; 4-5 depois de confirmados os primeiros.

## Publicação na Google Play — pontos-chave

- Conta de desenvolvedor: taxa única de US$25, **paga uma vez só, para sempre**, e válida para **quantos jogos o desenvolvedor quiser publicar** na mesma conta.
- Verificação de identidade obrigatória (2-7 dias úteis).
- Formato exigido: Android App Bundle (.aab), não APK.
- targetSdkVersion precisa seguir o exigido (API 34+ em 2026).
- Política de privacidade obrigatória (o jogo usa AdMob, que coleta dado).
- Contas pessoais precisam de teste fechado com **mínimo 12 testadores reais** (número mais atual — checar no Play Console, já que já foi 20 antes) participando **continuamente por 14 dias consecutivos**, **por app publicado** (não é único por conta — cada app novo passa pelo próprio ciclo).
  - Testadores podem ser qualquer pessoa com Conta Google — amigos/família, comunidades de troca entre devs, ou freelancers pagos.
  - Não há exigência de tempo mínimo fixo por dia, mas o Google analisa se o uso parece real: sessões de pelo menos 1-2 minutos, navegação por telas diferentes, uso quase todo dia (evitar buracos de vários dias sem abrir, que reinicia o contador), horários variados (padrão robótico é detectado e descartado).
- Revisão final do Google: 3-7 dias úteis.
- Total estimado do processo (app pronto → publicado): 15-27 dias.

## Monetização — expectativa realista

eCPM (ganho a cada 1000 exibições de anúncio) varia muito por formato e país. Médias globais aproximadas:

| Formato | Tier 1 (EUA/Europa) | Média global |
|---|---|---|
| Banner | $0,50–$1,50 | $0,20–$0,80 |
| Interstitial | $5–$8 | $2,50–$5 |
| Rewarded (recompensado) | $15–$30 | $8–$18 |

Anúncios recompensados são os que mais rendem (jogador assiste voluntariamente) e tipicamente respondem por 50-70% da receita de anúncios em jogos mobile bem-sucedidos. Receita real depende fortemente de volume de jogadores ativos — um primeiro jogo sem marketing deve gerar receita simbólica até ganhar tração.

## Status atual da implementação

**Concluído e testado:**
- Estrutura completa do projeto Godot 4.6 (autoloads GameManager, SaveManager, SpeciesDatabase, AdsManager)
- Loop principal: toque manual, produção passiva, save/load em JSON, produção offline com teto de 8h (validado com script sintético batendo exato)
- Sistema de níveis (1-100) por espécie substituindo o antigo sistema de 3 estágios fixos
- Passivas variadas por espécie/nível (5 tipos diferentes, distribuídas para dar identidade a cada dino)
- Expansão de 8 para 32 espécies, incluindo répteis pré-históricos não-dinossauros
- Economia balanceada e validada via skill própria `balance-check` (ROI revisado mais de uma vez ao longo do projeto)
- AdMob integrado em modo de teste (plugin `godot-sdk-integrations/godot-admob`, MIT), com os 3 pontos de anúncio funcionando e fluxo de consentimento GDPR/UMP
- Assets visuais das **32 espécies** gerados via PixelLab e aplicados (sprites Filhote/Jovem/Adulto + idle animado, background, ícones de UI, ícones de conquistas)
- Sons de UI e música de fundo implementados, com sistema de volume
- Onboarding, splash screen, tela de celebração de coleção completa, ajustes de área de toque
- Ferramental de qualidade: gdtoolkit (gdformat/gdlint), hooks automáticos de formatação e proteção de arquivos sensíveis, MCP do Godot (Dokujaa/Godot-MCP) e MCP oficial da PixelLab conectados
- **Testes em dispositivo Android real** (build exportado como APK e instalado no celular do usuário) começaram e já passaram por várias rodadas de correção — ver lista de bugs encontrados abaixo. Esse é hoje o principal canal de QA do projeto (bugs que só aparecem fora do Editor).
- **Sistema de prestígio** implementado (`PrestigeManager`, Fósseis Ancestrais, 10 upgrades permanentes, reset de run, popup próprio) — ver seção "Sistema de Prestígio" acima. Escrito com testes headless (`tests/test_prestige.gd`), mas **ainda não rodado nem no Editor nem em dispositivo real** — é o próximo item a validar antes de considerar essa feature concluída.

**Bugs de export/dispositivo real encontrados e corrigidos nas rodadas de teste:**
- Nenhuma espécie aparecia no APK exportado (SpeciesDatabase escaneava `res://data/species/` em runtime, mas o export converte `.tres` pra binário e o arquivo listado vira `nome.tres.remap` — filtro não reconhecia, então nada carregava; só acontecia fora do Editor)
- Retângulo de destaque do tutorial saía errado na primeira vez que abria o app (media a posição do alvo cedo demais, antes do layout assentar)
- Scroll da lista de dinos muito difícil de usar no toque — só funcionava acertando a fresta entre cards (bug conhecido do próprio Godot: controles dentro de um `ScrollContainer` engolem o toque antes de chegar nele; corrigido ajustando `mouse_filter` em toda a árvore de cada card)
- Botões de anúncio recompensado (dobrar produção / bônus de comida) ficavam travados desabilitados pra sempre depois do boot, mesmo com anúncio já carregado (sinal de "anúncio pronto" do plugin nunca era escutado)
- Indicador de combo aparecendo/sumindo deslocava o resto do HUD pra cima e pra baixo a cada combo; agora fica sempre visível, mostrando "0x" parado
- Número flutuante "+X" de comida não aparecia no toque (nascia sempre no canto (0,0) da tela por causa da ordem entre `setup()` e entrar na árvore, não no ponto do toque)
- Vários popups e o fundo do cenário usavam tamanho fixo em pixel, quebrando/deixando vãos em aparelhos com aspect ratio diferente do de referência — convertidos pra tamanho responsivo (ancorado por fração de tela ou intrínseco ao conteúdo)
- Flash de tela cinza na transição entre a splash e o jogo (troca de cena síncrona deixava um instante sem nada desenhado); agora o `Main.tscn` carrega em background enquanto a splash continua na tela, com crossfade suave
- Popup de detalhes do dino e popup de "bem-vindo de volta" (ganhos offline) muito transparentes, texto se misturando com o fundo — escurecidos
- Botão de info (ⓘ) do card de cada dino pequeno demais pro toque — aumentado

**Ainda pendente para publicação:**
0. Rodar `tests/test_prestige.gd` (`godot --headless -s tests/test_prestige.gd --path .`) e depois testar o fluxo de prestígio na prática (chegar a 50% de progresso, prestigiar, comprar upgrade, fechar/reabrir o app pra confirmar que Fósseis/upgrades sobrevivem) — feature nova, ainda não validada nem no Editor
1. Continuar os testes em dispositivo Android real até não surgirem mais bugs novos de export/toque/responsividade (ciclo ativo, ver lista acima)
2. Ícone do app + splash screen em alta resolução para a ficha da loja (diferente do splash in-game)
3. Trocar AdMob de modo teste para modo produção (IDs reais da conta AdMob)
4. Configurar Android SDK e gerar o Android App Bundle (.aab) — precisa ser feito na máquina do usuário, já que o ambiente do Claude Code não tem Android SDK disponível
5. Escrever a política de privacidade (obrigatória por causa do AdMob)
6. Preparar a ficha da loja: nome, descrição curta/longa, screenshots, categoria, classificação etária
7. Recrutar no mínimo 12 testadores reais e rodar o ciclo de teste fechado de 14 dias consecutivos
8. Preencher o formulário de solicitação de acesso à produção no Play Console
9. Publicação final
