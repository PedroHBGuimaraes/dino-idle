# Dino Mobile

Jogo idle/casual em Godot 4.6 (2D, retrato): reconstrua uma ilha cuidando de
uma família de dinossauros (e outros répteis pré-históricos). Toque para
ganhar Comida, desbloqueie espécies e suba cada uma de nível (1 a 100) para
aumentar a produção passiva e desbloquear passivas permanentes.

## Mecânica

- **Comida**: moeda única. Ganha por toque manual (`GameManager.tap()`) e por
  produção passiva/segundo (soma da produção de todas as espécies
  desbloqueadas, no nível atual de cada uma).
- **32 espécies** (8 dinossauros terrestres originais + 24 adicionadas —
  mais terrestres, répteis voadores e répteis marinhos), cada uma com
  **1 único dino** — lista completa e detalhes de passiva em
  [`data/species/README.md`](data/species/README.md).
- Cada espécie é **desbloqueada uma vez** (`unlock_cost`) e depois **sobe
  de nível 1 a 100**, cada level up com custo geométrico próprio
  (`level_cost_base`) e aumentando a produção daquele dino de forma
  contínua (também geométrica, não mais em saltos de estágio). O sprite
  ainda troca em 3 faixas visuais (Filhote/Jovem/Adulto por nível), mas
  isso é só arte — custo/produção são sempre por nível.
- **Passivas**: a cada nível 25/50/75/100, a espécie desbloqueia um bônus
  permanente (produção própria, produção global, valor do toque, sinergia
  condicional por nível, ou combo de cliques ativo) — ver
  [`data/species/README.md`](data/species/README.md) e
  `resources/passive_effect.gd`.
- **Produção offline**: ao reabrir o jogo, o tempo decorrido desde o último
  save (com teto de 8h) é convertido em Comida e mostrado num popup.
- **Prestígio**: a partir de 50% de progresso da coleção
  (`GameManager.get_collection_progress()`), o jogador pode resetar a run
  (comida e nível de todas as espécies) em troca de Fósseis Ancestrais, uma
  moeda permanente que compra multiplicadores permanentes de produção/toque —
  ver seção [Prestígio](#prestígio) abaixo.
- **AdMob** (integrado, modo de teste): 3 anúncios recompensados —
  dobrar produção por 30 min, dobrar o ganho de produção offline no popup de
  "bem-vindo de volta", e comida bônus a cada
  `GameManager.BONUS_AD_UNLOCK_INTERVAL` (hoje 2) espécies desbloqueadas.
  Ver seção [AdMob](#admob) abaixo para detalhes, modo de teste vs. produção
  e o fluxo de consentimento GDPR.

## Estrutura de pastas

```
autoload/            # Singletons (Project Settings > Autoload)
  GameManager.gd       # Estado de jogo: comida, desbloqueio/estágio, buff de produção, bônus
  PrestigeManager.gd     # Fósseis Ancestrais (moeda permanente) e upgrades de prestígio — ver seção Prestígio
  SaveManager.gd        # Save/load em JSON, autosave, produção offline
  SpeciesDatabase.gd     # Carrega e indexa os .tres de data/species/
  AdsManager.tscn/.gd     # Fachada de anúncios recompensados sobre o node Admob (plugin AdMob)
addons/
  AdmobPlugin/            # Plugin godot-sdk-integrations/godot-admob (Android/iOS)
  GMPShared/               # Dependência compartilhada do AdmobPlugin
  godot_mcp/               # Plugin MCP (dev tooling, controla a Editor via Claude — não afeta o jogo)
resources/
  dino_species_data.gd   # class_name DinoSpeciesData extends Resource
  passive_effect.gd        # class_name PassiveEffect extends Resource (bônus por marco de nível)
  prestige_upgrade_data.gd  # class_name PrestigeUpgradeData extends Resource
  food_format.gd            # Formatação compacta de números (1.2K, 3.4M...)
data/species/             # Uma instância .tres por espécie (dados data-driven) — ver README nessa pasta
data/prestige/             # Uma instância .tres por upgrade de prestígio
tests/
  test_prestige.gd        # Testes headless do sistema de prestígio — ver seção Prestígio
scenes/
  main/                    # Cena raiz (Main.tscn) — liga tap + carrega o save
  dino/                    # Visual placeholder reutilizável de um dino
  ui/                      # HUD, ShopPanel/DinoCard (família), popup de offline
assets/placeholder/       # Nota de como/onde trocar por arte final
```

Convenção: script sempre ao lado da cena que ele controla; `autoload/` só
para singletons; `resources/` para classes de dados puras (sem cena); os
`.tres` em `data/` são as instâncias de dados — edite valores direto no
Inspector do Godot sem tocar em código.

### Fluxo de dados

`data/species/*.tres` → `SpeciesDatabase` (carrega e indexa) → `GameManager`
(estado + regras: desbloquear, evoluir, produção) → UI (`HUD`, `ShopPanel` /
`DinoCard`) reage a `GameManager.food_changed` e
`GameManager.dino_state_changed` via sinais.

## Save/Load

- Arquivo: `user://savegame.json` (texto simples, não binário).
- Formato:
  ```json
  {
    "version": 1,
    "food": 1234.5,
    "last_save_unix": 1755600000,
    "species": {
      "compsognathus": { "unlocked": true, "level": 12 },
      "velociraptor": { "unlocked": false, "level": 1 }
    },
    "unlocks_since_last_bonus": 1,
    "production_boost_multiplier": 2.0,
    "production_boost_expires_unix": 1755601800
  }
  ```
- Saves salvos antes do sistema de níveis (campo `"stage": 0/1/2`) migram
  sozinhos ao carregar — `GameManager.load_state()` converte stage 0/1/2
  pra nível 1/25/50 automaticamente (ver `_migrate_level_from_entry`).
- A produção offline é calculada com a produção **base** (sem o buff de
  anúncio) de propósito — um buff de 30min não deve valer pelas horas
  inteiras em que o app ficou fechado (evita o exploit de ativar o buff e
  imediatamente fechar o app por horas). Ver comentário em
  `SaveManager.load_game()`.
- Autosave a cada 30s, e também ao perder foco/fechar (importante no Android,
  onde o app pode ser encerrado sem aviso).
- `Main.gd` chama `SaveManager.load_game()` só depois que a UI filha já está
  pronta e conectada aos sinais, para que o estado carregado (e o popup de
  ganhos offline) apareça corretamente.

## Adicionar uma nova espécie

Guia completo (curva de custo/produção, como escolher uma passiva com
"personalidade própria", balance-check) em
[`data/species/README.md`](data/species/README.md#adicionar-uma-nova-espécie).

## Prestígio

Objetivo de longuíssimo prazo depois que a coleção já está bem avançada:
reseta o progresso da run em troca de uma moeda permanente. Ver
`dino-idle-game-plano.md` §"Sistema de Prestígio" pra contexto/números
completos (curva de custo, justificativa do piso de 50%).

- **Gatilho**: `PrestigeManager.can_prestige()` fica `true` a partir de
  `GameManager.get_collection_progress() >= PrestigeManager.PRESTIGE_MIN_PROGRESS`
  (hoje `0.5`). Depois do primeiro prestígio, o botão nunca mais some da UI
  (`PrestigeManager.is_unlocked()`), mesmo que o progresso da run atual caia
  de novo abaixo do piso.
- **Fósseis Ancestrais**: `PrestigeManager.perform_prestige()` concede
  `floor(FOSSILS_PER_LEVEL_SUM * soma dos níveis das espécies DESBLOQUEADAS)`
  e chama `GameManager.reset_for_prestige()` — zera `food`, devolve toda
  espécie pro nível 1 e só deixa desbloqueada quem tem
  `DinoSpeciesData.starts_unlocked == true` (hoje só o Compsognathus), e
  encerra qualquer buff de anúncio em andamento. **Não mexe** em conquistas
  (`AchievementManager`, permanentes por design) nem no próprio saldo/upgrades
  de prestígio.
- **Upgrades**: `data/prestige/*.tres` (`PrestigeUpgradeData`), 10 no total —
  6 de produção passiva (`target = PRODUCTION`), 4 de valor de toque
  (`target = TAP`). Cada um é comprável várias vezes (custo geométrico via
  `cost_for_level`, igual ao level-up de espécie) até seu `max_level`. O
  bônus de cada upgrade cresce linearmente por nível e todos do mesmo
  `target` somam entre si num único multiplicador
  (`PrestigeManager.get_production_multiplier()`/`get_tap_multiplier()`),
  aplicado em `GameManager.get_base_production_per_second()`,
  `get_species_current_production()` e `_get_global_tap_multiplier()` — os 3
  precisam ficar em sincronia (mesmo cuidado que já existia entre eles pro
  buff de anúncio).
- **Persistência**: `PrestigeManager` guarda seu próprio estado
  (`fossils`/`prestige_count`/níveis de upgrade) independente do
  `GameManager` — sobrevive ao reset porque `reset_for_prestige()` nunca
  toca nele. `SaveManager` dobra os dois no mesmo `user://savegame.json`
  (chave `"prestige"`, ver `get_save_state()`/`load_state()`), sem precisar
  de um arquivo separado — segue o mesmo padrão já usado por
  `AchievementManager`/`AudioManager`.
- **UI**: `scenes/ui/PrestigePopup.tscn` (loja de upgrades + botão de
  prestigiar, com confirmação inline por ser destrutivo) e
  `scenes/ui/PrestigeUpgradeRow.tscn` (uma linha por upgrade), abertos pelo
  botão "♻" no `HUD` (só visível quando `PrestigeManager.is_unlocked()`).
- **Testes**: `tests/test_prestige.gd`, headless (`SceneTree`, sem
  GUT/gdUnit — o projeto não tem framework de teste instalado). Roda com
  `godot --headless -s tests/test_prestige.gd --path .` a partir da raiz do
  projeto; imprime PASS/FAIL por checagem e sai com código 0/1. Cobre reset
  correto, persistência de `PrestigeManager` entre "sessões" (via
  `get_save_state()`/`load_state()`, sem tocar o save real em disco) e o
  multiplicador de prestígio batendo entre produção total, produção por
  espécie e valor de toque.

## Rodar no editor

Abra a pasta do projeto no Godot **4.6**, rode a cena `Main.tscn`
(já configurada como cena principal). Toque na área central para ganhar
Comida, desbloqueie/evolua espécies pelos cards da lista.

## Exportar para Android

Esta máquina não tem Godot Editor, Android SDK nem Java instalados, então o
preset de export não foi gerado — configure pela própria Editor:

1. Instale **Android Studio SDK** (ou só as *command line tools*) e um
   **JDK 17+**; configure `Editor Settings > Export > Android` apontando
   para o SDK.
2. No Godot: **Project > Install Android Build Template**.
3. Baixe os **Export Templates** correspondentes à versão do Godot
   (Editor > Manage Export Templates).
4. **Project > Export > Add... > Android**, defina:
   - *Unique Name* / *Package* (ex.: `com.seudominio.dinomobile`).
   - *Orientation*: `portrait` (já é o padrão do projeto).
   - Um keystore de debug (o Godot pode gerar um automaticamente) e,
     depois, um keystore de release seu para publicar.
   - Em **Launcher Icons**, aponte todos os campos (main/adaptive
     foreground/background/monochrome) pra `res://icon.png` (1024x1024) — o
     Godot reamostra pro tamanho de cada mipmap automaticamente. Pra ícone
     de loja (Play Console), o mesmo `icon.png` já serve como a arte de
     512x512/1024x1024 pedida.
5. Exporte um `.apk`/`.aab` de debug e instale num dispositivo/emulador para
   testar.

## Áudio

Detalhes completos (desenho de cada SFX, onde cada som dispara, sistema de
volume) em [`docs/audio.md`](docs/audio.md). Resumo:

- **4 efeitos sonoros** (`assets/audio/sfx/*.wav`) — sintetizados por código
  (onda quadrada, estilo 8-bit), sem depender de assets de terceiros. Script
  de geração: `docs/gen_sfx.py` (só stdlib do Python, `wave`+`struct`).
- **Música de fundo** (`assets/audio/music/island_theme.ogg`): faixa
  **"Feel Good Island Loop"**, de **Brandon Morris**, via
  [OpenGameArt.org](https://opengameart.org/content/feel-good-island-loop).
  Licenciada como **CC0** (domínio público — uso comercial livre, atribuição
  não exigida). Ainda assim, dando o crédito por educação: "Feel Good Island
  Loop" by Brandon Morris (OpenGameArt.org, CC0). Pra trocar a faixa depois,
  é só substituir o arquivo em `assets/audio/music/island_theme.ogg` (o
  `AudioManager` toca em loop automaticamente qualquer `.ogg` `AudioStreamOggVorbis`
  encontrado nesse caminho — se o arquivo não existir, o jogo funciona
  normalmente, só sem música).
- **Volume/mudo**: `AudioManager` (autoload) controla dois barramentos
  Godot (`Music`/`SFX`, ver `resources/audio/bus_layout.tres`), com volume
  independente e um mudo geral, acessível pelo botão de engrenagem no HUD.
  Preferências persistem no save.

## AdMob

Integrado via [`godot-sdk-integrations/godot-admob`](https://github.com/godot-sdk-integrations/godot-admob)
(MIT, gratuito) — plugin em `addons/AdmobPlugin/` (+ dependência
`addons/GMPShared/`). Só funciona de verdade em build **Android/iOS
exportado**; no Editor/desktop o SDK nativo não existe e todo método de
anúncio vira um no-op seguro (`is_rewarded_ad_ready()` sempre `false`).

### Arquitetura

- `autoload/AdsManager.tscn` — autoload real (não só o `.gd`): tem um node
  filho `Admob` (`%Admob`) com os IDs de anúncio configurados no Inspector.
- `autoload/AdsManager.gd` — fachada. **Nada mais no projeto deve
  referenciar `$Admob`/`Admob` diretamente** — sempre passe por
  `AdsManager`.
- API pública:
  - `AdsManager.is_rewarded_ad_ready() -> bool`
  - `AdsManager.show_rewarded_ad(on_result: Callable)` — genérico,
    `on_result` recebe `(bool earned_reward)`. Usado pelo
    `OfflineEarningsPopup` pra "dobrar" um valor que só ele conhece.
  - `AdsManager.request_double_production_boost()` — placement #1.
  - `AdsManager.request_bonus_food()` — placement #3.

### Os 3 anúncios recompensados

1. **Dobrar produção por 30 min** — botão no `HUD`
   (`GameManager.activate_production_boost(2.0, 30*60)`). Multiplicador e
   expiração (timestamp Unix) ficam em `GameManager` e são salvos, então
   sobrevivem a fechar/reabrir o app.
2. **Dobrar ganhos offline** — botão no `OfflineEarningsPopup`, some depois
   de usado uma vez por popup.
3. **Comida bônus a cada N desbloqueios** — `GameManager.BONUS_AD_UNLOCK_INTERVAL`
   (hoje `2`). Botão "🎁" aparece no `HUD` quando disponível
   (`GameManager.is_bonus_ad_available()`). Valor do bônus escala com a
   produção atual (`~2 min` de produção, com piso mínimo de 10) em vez de
   um número fixo, pra continuar relevante em qualquer ponto do jogo.

### Modo de teste vs. produção

O node `Admob` (em `AdsManager.tscn`) já vem configurado em **modo de
teste** — `is_real = false` e os `android_debug_*_id` preenchidos com os
IDs de teste oficiais do Google (ex. rewarded:
`ca-app-pub-3940256099942544/5224354917`, app ID:
`ca-app-pub-3940256099942544~3347511713`). Nesse modo, os anúncios exibidos
são sempre de teste — seguro pra desenvolver sem risco de suspensão de
conta por tráfego inválido.

**Antes de publicar de verdade**, na Editor:

1. Crie um app no [AdMob Console](https://apps.admob.com/) e gere os IDs de
   anúncio recompensado real (e o App ID real).
2. Abra `autoload/AdsManager.tscn`, selecione o node `Admob`.
3. No Inspector, preencha `Android Real Ad Unit IDs > Rewarded Id` (e os
   outros que forem usados) e `Android Application IDs > Real Application Id`.
4. Marque `is_real = true`.
5. No export Android (ver seção acima), confirme que o `AdmobPlugin` está
   habilitado (`Project Settings > Plugins`) — ele injeta o App ID e as
   permissões certas no `AndroidManifest.xml` automaticamente no export.

### Consentimento (GDPR/UMP)

O fluxo do Google User Messaging Platform (UMP) já vem no plugin e é
disparado automaticamente pelo `AdsManager` depois que o SDK inicializa:
`update_consent_info()` → se `REQUIRED`, carrega e mostra o formulário de
consentimento → só carrega o primeiro anúncio recompensado depois que o
consentimento é `NOT_REQUIRED` ou `OBTAINED`. Pra testar o formulário
aparecendo (a geolocalização real do dispositivo de teste pode não exigir
consentimento), defina `debug_geography = EEA` no node `Admob` durante
testes.

### Limitação desta máquina/sessão

Sem Android SDK aqui, não dá pra exportar um `.apk` e ver um anúncio de
verdade na tela. O que foi validado:
- O projeto carrega sem erro com o plugin habilitado (smoke test headless).
- Toda a lógica de jogo dos 3 placements (buff de produção, contador de
  bônus, save/load desses campos) foi testada isoladamente no `GameManager`
  e passou.
- A integração de UI/sinais com o `Admob` real só pode ser confirmada
  visualmente num build Android de verdade (ou, no mínimo, rodando o
  projeto num Windows/macOS/Linux com o SDK Android configurado e um
  dispositivo/emulador conectado).
