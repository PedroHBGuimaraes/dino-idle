---
name: new-species
description: Adiciona uma nova espécie de dinossauro ao jogo — cria o .tres em data/species/ seguindo o schema de DinoSpeciesData, com custos coerentes com as espécies vizinhas na curva econômica. Use quando o usuário pedir para adicionar/criar um novo dinossauro/espécie.
---

# Adicionar nova espécie

Cada espécie é um `Resource` (`DinoSpeciesData`, ver `resources/dino_species_data.gd`)
salvo como `.tres` em `data/species/`. `SpeciesDatabase` (autoload) carrega
todos os `.tres` dessa pasta dinamicamente — basta o arquivo existir lá para
`ShopPanel` criar um `DinoCard` para ele automaticamente. Nenhum outro
arquivo de código precisa mudar.

## Passos

1. **Reúna os dados que faltam** do usuário, se não foram dados: nome de
   exibição (PT-BR), e opcionalmente uma cor placeholder e onde ela deve
   entrar na ordem de custo (ex.: "entre Triceratops e Parassaurolofo").

2. **Leia todas as `.tres` existentes em `data/species/`** para ver a curva
   atual: `unlock_cost`, `base_production`, `evolve_costs` de cada uma,
   ordenadas por `unlock_cost`. Note o fator de crescimento aproximado entre
   espécies vizinhas (hoje gira em torno de 5-6x de `unlock_cost` a cada
   espécie, ver README.md).

3. **Escolha os valores da nova espécie por interpolação/extrapolação**
   geométrica em relação às vizinhas (não invente números aleatórios):
   - `unlock_cost`: entre o `unlock_cost` das duas espécies vizinhas (ou
     acima da mais cara, seguindo o mesmo fator de crescimento, se for uma
     espécie "endgame").
   - `base_production`: mesma lógica, mantendo a razão
     `unlock_cost / base_production` (payback time) parecida com as
     vizinhas — não deixe uma espécie muito mais/menos lucrativa que as
     outras sem motivo.
   - `evolve_costs`: `[Filhote→Jovem, Jovem→Adulto]`, tipicamente ~4x e
     ~25x o `unlock_cost` (olhe as vizinhas pra confirmar a proporção).
   - Se tiver a skill `balance-check` disponível, rode-a depois de escrever
     o arquivo pra confirmar que a nova espécie não quebra a curva.

4. **Escolha um `id`** em snake_case, único, sem espaços/acentos (é o nome
   do arquivo também: `data/species/<id>.tres`).

5. **Escreva o `.tres`** seguindo exatamente este formato (veja
   `data/species/velociraptor.tres` como referência):

   ```
   [gd_resource type="Resource" script_class="DinoSpeciesData" load_steps=2 format=3]

   [ext_resource type="Script" path="res://resources/dino_species_data.gd" id="1"]

   [resource]
   script = ExtResource("1")
   id = &"<id>"
   display_name = "<Nome de Exibição>"
   placeholder_color = Color(<r>, <g>, <b>, 1)
   starts_unlocked = false
   unlock_cost = <float>
   base_production = <float>
   evolve_costs = Array[float]([<filhote_para_jovem>, <jovem_para_adulto>])
   ```

   (`starts_unlocked = true` só se for uma espécie gratuita inicial, como o
   Compsognathus — normalmente não é o caso de uma espécie nova.)

6. **Confirme** com o usuário os valores escolhidos antes de escrever, já
   que são decisões de game design/balanceamento, não só técnicas.
