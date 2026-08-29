class_name PrestigeUpgradeData
extends Resource

## Definição estática de um upgrade permanente comprado com Fósseis Ancestrais
## (ver PrestigeManager). Uma instância .tres por upgrade vive em
## res://data/prestige/ e é lida pelo PrestigeManager, no mesmo espírito de
## DinoSpeciesData/data/species/.
##
## Cada upgrade é comprável várias vezes (nível 0 em diante, sem teto até
## max_level), com custo geométrico igual ao level-up de espécie
## (cost_for_level) e um bônus que cresce LINEARMENTE por nível
## (bonus_for_level) — o multiplicador final de todos os upgrades do mesmo
## `target` soma entre si e vira UM `1.0 + soma` (ver
## PrestigeManager.get_production_multiplier/get_tap_multiplier), em vez de
## multiplicar cada upgrade entre si, pra não empilhar multiplicadores
## multiplicativos e os números saírem do controle.

enum Target { PRODUCTION, TAP }

@export var id: StringName
@export var display_name: String
@export var description: String
@export var target: Target = Target.PRODUCTION

## Custo (em Fósseis) do nível 1; os demais escalam via cost_growth.
@export var base_cost: float = 1.0
@export var cost_growth: float = 1.15

## Bônus percentual concedido POR NÍVEL — 0.02 = +2% por nível.
@export var value_per_level: float = 0.02

## Teto de níveis compráveis (soft cap; evita grind infinito degenerado).
@export var max_level: int = 20


## Nome/descrição já traduzidos. As chaves derivam do `id`
## (&"prod_1" -> PRESTIGE_UP_PROD_1_NAME / PRESTIGE_UP_PROD_1_DESC); os campos
## display_name/description do .tres viram só referência PT no editor.
func get_display_name() -> String:
	return Loc.t("PRESTIGE_UP_" + String(id).to_upper() + "_NAME")


func get_description() -> String:
	return Loc.t("PRESTIGE_UP_" + String(id).to_upper() + "_DESC")


## Custo pra comprar o próximo nível, partindo de `current_level`. -1.0 se já
## no teto.
func cost_for_level(current_level: int) -> float:
	if is_max_level(current_level):
		return -1.0
	return base_cost * pow(cost_growth, float(current_level))


func is_max_level(current_level: int) -> bool:
	return current_level >= max_level


## Bônus total (0.10 = +10%) concedido por `level` níveis já comprados.
func bonus_for_level(level: int) -> float:
	return float(level) * value_per_level
