---
name: balance-check
description: Analisa a curva econômica do sistema de níveis (data/species/*.tres) — produção/custo/ROI de cada espécie ao longo dos 100 níveis — e aponta possíveis desequilíbrios. Use quando o usuário pedir para balancear/revisar a economia do jogo, ou depois de editar level_cost_base/base_production de uma espécie.
disable-model-invocation: false
---

# Balance check

Roda uma análise puramente numérica (não abre o Godot) da curva de
custo/produção definida em `data/species/*.tres`, usando as fórmulas de
`resources/dino_species_data.gd`: cada espécie sobe de nível 1 a 100,
`production_at_level = base_production * PRODUCTION_GROWTH^(nível-1)` e
`cost_for_level = level_cost_base * LEVEL_COST_GROWTH^(nível-1)`.

## Como usar

Rode o script bundled com esta skill a partir da raiz do projeto:

```bash
python .claude/skills/balance-check/balance_check.py
```

Ele imprime: uma tabela (custo de desbloqueio, produção no nível 1, payback
do nível 1, investimento total até nível 100, ROI@100 = produção-no-nível100
/ investimento-total) ordenada por custo de desbloqueio; produção e custo
acumulado nos marcos 1/25/50/75/100 por espécie; outliers de ROI@100 fora de
0.5x-2x da mediana; e a decadência do ROI marginal do nível 1 ao 99 (mesma
para todas as espécies, já que ambas as curvas — custo e produção — são
geométricas).

## Como interpretar o resultado

- **ROI@100** muito acima da mediana = a espécie compensa demais investir
  nela por uma margem grande (provável desbalanceamento a favor do
  jogador). Muito abaixo = a espécie é uma armadilha de fim de jogo.
- **Decadência do ROI marginal** é o quanto cada nível individual "vale
  menos" que o anterior — é esperado que caia (progressão de 100 níveis
  tem retornos decrescentes por design, incentivando diversificar entre
  espécies), mas uma queda catastrófica (ex. produção linear contra custo
  geométrico) faz os níveis tardios parecerem inúteis. O script avisa se a
  razão marginal(99)/marginal(1) cair abaixo de 0.5%.
- Isso é um guia, não uma verdade absoluta — variação intencional (ex.: uma
  espécie "prestígio" mais cara e menos eficiente, mas visualmente
  desejável) é uma escolha de design válida. Use os números pra embasar a
  conversa com o usuário, não pra reescrever `.tres` sozinho sem confirmar.

Depois de qualquer ajuste em `data/species/*.tres` ou nas constantes de
`resources/dino_species_data.gd`, rode de novo pra confirmar que a curva
ainda faz sentido.
