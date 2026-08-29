# Espécies (`data/species/*.tres`)

Uma instância `DinoSpeciesData` (`.tres`) por espécie, carregada e indexada
por `SpeciesDatabase` na inicialização — puramente data-driven, sem nenhum
código específico por espécie. Hoje são **32 espécies**: as 8 originais
(dinossauros terrestres) mais 24 adicionadas depois (mais terrestres +
répteis voadores + répteis marinhos), pra variedade visual entre
categorias.

## Progressão

Cada espécie é **desbloqueada uma vez** (`unlock_cost`) e depois sobe de
**nível 1 a 100**, gastando comida a cada "level up" — custo geométrico
(`level_cost_base * LEVEL_COST_GROWTH^(nível-1)`) e produção também
geométrica (`base_production * PRODUCTION_GROWTH^(nível-1)`); ambas usam a
MESMA forma (geométrica) de propósito — produção linear contra custo
geométrico faz o ROI marginal desabar por ordens de grandeza ao longo de
100 níveis (o "problema de ROI degradante"). O sprite (Filhote/Jovem/Adulto)
troca de faixa em faixa de nível (`DinoSpeciesData.stage_for_level`), mas
isso é só arte — quem rege custo/produção é sempre o nível.

## Passivas (`PassiveEffect`, `resources/passive_effect.gd`)

A cada marco de nível — **25, 50, 75, 100** — a espécie desbloqueia uma
passiva permanente. Cinco tipos existem hoje:

| Tipo | Efeito | Escopo |
|---|---|---|
| `species_production_boost` | +X% na produção da PRÓPRIA espécie | individual |
| `global_production_boost` | +X% na produção de TODAS as espécies | global, empilha por espécie que tiver |
| `tap_value_boost` | +X% no valor do toque manual | global, empilha por espécie que tiver |
| `threshold_synergy` | +X% na produção de toda espécie em nível >= limiar | global condicional (só quem bate o limiar recebe) |
| `combo_click_boost` | +X% no toque a cada N cliques seguidos, até um teto | jogo ATIVO só — zera após ~2.5s sem tocar |

Quem **aplica** os efeitos é `GameManager` (não `DinoSpeciesData`), porque
bônus globais/sinergias precisam olhar o estado de todas as espécies ao
mesmo tempo — ver `GameManager._collect_active_global_passives()` e
`_get_own_production_multiplier()`.

### Padrão de distribuição por espécie

Pra cada dino ter uma identidade própria em vez de um padrão igual pra
todos, o nível **25 e 50 são universais** (todo dino ganha
`species_production_boost +8%` no 25 e `tap_value_boost +5%` no 50 — a
"fase de crescimento" comum antes da personalidade aparecer), e os níveis
**75 e 100 são a ASSINATURA** da espécie: o mesmo tipo aparece nos dois
marcos (valor maior no 100), refletindo algo da sua personalidade real
(pequeno/ágil → combo; robusto/blindado → produção própria; apex predador
→ sinergia; etc.). Exceção: espécies com assinatura `combo_click_boost` só
recebem o combo no nível 100 (o 75 vira um `global_production_boost`
pequeno de preenchimento) — dar a MESMA curva de combo em 2 marcos
simultâneos empilharia de um jeito que distorce o teto pretendido pelo
design "+X% a cada N cliques até um teto único".

### Tabela completa

| Espécie | Categoria | Assinatura (75/100) | Detalhe |
|---|---|---|---|
| Compsognathus | Terrestre | `combo_click_boost` | pequeno e ágil — recompensa jogo ativo. +2%/10 cliques, teto 200 |
| Velociraptor | Terrestre | `threshold_synergy` (nível 20+) | caçador em bando |
| Estegossauro | Terrestre | `species_production_boost` | robusto/blindado |
| Triceratops | Terrestre | `species_production_boost` | robusto/blindado |
| Parassaurolofo | Terrestre | `global_production_boost` | crista ressonante, "chamado do rebanho" |
| Anquilossauro | Terrestre | `species_production_boost` | robusto/blindado |
| Braquiossauro | Terrestre | `global_production_boost` | gigante gentil, fartura pra todos |
| Tiranossauro Rex | Terrestre | `threshold_synergy` (nível 50+) | topo da cadeia alimentar |
| Iguanodonte | Terrestre | `species_production_boost` | herbívoro de rebanho |
| Alossauro | Terrestre | `threshold_synergy` (nível 30+) | predador ápice pré-T-Rex |
| Espinossauro | Terrestre | `tap_value_boost` | caçador semiaquático versátil/ativo |
| Carnotauro | Terrestre | `combo_click_boost` | corredor veloz. +2.2%/8 cliques, teto 160 |
| Deinoníquio | Terrestre | `threshold_synergy` (nível 35+) | caçador em bando (raptor) |
| Estiracossauro | Terrestre | `species_production_boost` | ceratopsídeo espinhoso/defensivo |
| Galimimo | Terrestre | `combo_click_boost` | o mais veloz. +1.8%/6 cliques, teto 180 |
| Centrossauro | Terrestre | `species_production_boost` | blindado |
| Paquicefalossauro | Terrestre | `tap_value_boost` | cabeçadas — literalmente sobre "toques" |
| Coritossauro | Terrestre | `global_production_boost` | crista ressonante, chamado social |
| Uranossauro | Terrestre | `species_production_boost` | herbívoro de vela dorsal |
| Giganotossauro | Terrestre | `threshold_synergy` (nível 55+) | rival do T-Rex em porte |
| Terizinossauro | Terrestre | `global_production_boost` | herbívoro gigante bizarro/provedor |
| Diplodoco | Terrestre | `global_production_boost` | gigante gentil (saurópode) |
| Pteranodonte | Voador | `global_production_boost` | sobrevoa a ilha inteira |
| Pterodáctilo | Voador | `combo_click_boost` | pequeno e ágil. +2%/10 cliques, teto 180 |
| Quetzalcoatlo | Voador | `threshold_synergy` (nível 40+) | maior voador conhecido, alcance imenso |
| Ranforrinco | Voador | `tap_value_boost` | mergulhos precisos |
| Dimorfodonte | Voador | `species_production_boost` | pterossauro primitivo, nicho próprio |
| Tapejara | Voador | `tap_value_boost` | crista vistosa, engajamento ativo |
| Plesiossauro | Aquático | `global_production_boost` | as profundezas provêm pra todos |
| Mossassauro | Aquático | `threshold_synergy` (nível 45+) | predador ápice dos mares |
| Ictiossauro | Aquático | `combo_click_boost` | nadador veloz. +1.8%/12 cliques, teto 240 |
| Elasmossauro | Aquático | `species_production_boost` | pescoço longo, caçador paciente |

Valores exatos de cada marco: rode
`python .claude/skills/balance-check/balance_check.py`, seção "Passivas por
espécie".

## Balanceamento

`unlock_cost`/`base_production`/`level_cost_base` seguem uma curva
geométrica única ao longo das 32 espécies (não é mais o fator antigo
pensado pra 8) — ~1.85x entre uma espécie e a próxima a partir do
Tiranossauro Rex, mantendo `base_production ≈ unlock_cost / 115` e
`level_cost_base = unlock_cost * 0.1` pra todas. Depois de editar qualquer
`.tres` (custo, produção OU passiva), rode o balance-check pra confirmar
que a curva e as passivas continuam saudáveis:

```bash
python .claude/skills/balance-check/balance_check.py
```

Ele reporta ROI por espécie (já considerando a passiva própria de produção
no nível 100), decadência do ROI marginal, e um cenário "roster inteiro no
nível 100" que soma todos os bônus globais/sinergia — útil pra pegar
passivas globais empilhando de um jeito absurdo entre muitas espécies.
Combo de cliques é reportado à parte (é bônus de jogo ATIVO — o toque
manual, não a produção idle — então não compete com a economia passiva:
mesmo no teto, o ganho total de uma sessão de cliques rápidos é pequeno
comparado à produção contínua depois que o jogo progride um pouco).

## Adicionar uma nova espécie

1. Duplique um `.tres` desta pasta, ajuste `id`, `display_name`,
   `placeholder_color`.
2. Escolha `unlock_cost`/`base_production` seguindo a curva das espécies
   vizinhas (rode o balance-check pra comparar) e derive
   `level_cost_base = unlock_cost * 0.1`.
3. Escolha uma **assinatura** (um dos 5 tipos de `PassiveEffect`) que
   combine com a "personalidade" da espécie, e monte os 4 `sub_resource`
   de passiva seguindo o padrão da tabela acima (25/50 universais,
   75/100 = assinatura). Não precisa seguir à risca — é só o padrão usado
   até aqui pra manter as coisas consistentes.
4. Rode o balance-check pra confirmar que não virou um outlier de ROI.
5. Pronto — `SpeciesDatabase` carrega tudo dinamicamente da pasta;
   `ShopPanel` cria um `DinoCard` por espécie automaticamente. Sem sprite
   ainda? `Dino.gd` desenha um placeholder colorido (círculo, cor de
   `placeholder_color`) até a arte real ser gerada.
