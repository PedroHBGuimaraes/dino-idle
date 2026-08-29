class_name PassiveEffect
extends Resource

## Um bônus permanente concedido por uma espécie ao alcançar um dos marcos
## de nível (25/50/75/100 — ver DinoSpeciesData.passive_25/50/75/100).
## Um único Resource cobre todos os tipos (mais simples que subclasses,
## consistente com o resto do projeto: os campos que um tipo não usa
## simplesmente ficam com o valor default e são ignorados por
## GameManager._apply_passive()).

enum Type {
	SPECIES_PRODUCTION_BOOST,  ## +value na produção da PRÓPRIA espécie
	GLOBAL_PRODUCTION_BOOST,  ## +value na produção de TODAS as espécies
	TAP_VALUE_BOOST,  ## +value no valor do toque manual (global)
	THRESHOLD_SYNERGY,  ## +value na produção de toda espécie em nível >= threshold_level
	COMBO_CLICK_BOOST,  ## +value a cada combo_clicks_per_step cliques seguidos, até combo_max_clicks
}

@export var type: Type = Type.SPECIES_PRODUCTION_BOOST

## Bônus percentual — 0.15 = +15%. Significado exato varia por tipo (ver
## Type acima); pra COMBO_CLICK_BOOST é o bônus concedido POR STEP, não o
## total.
@export var value: float = 0.0

## Só usado por THRESHOLD_SYNERGY: nível mínimo que uma espécie precisa
## ter pra receber o bônus.
@export var threshold_level: int = 25

## Só usados por COMBO_CLICK_BOOST.
@export var combo_clicks_per_step: int = 10
@export var combo_max_clicks: int = 200


## Texto curto pra tooltip/UI (badges do DinoCard).
func describe() -> String:
	var percent := "%d%%" % roundi(value * 100.0)
	match type:
		Type.SPECIES_PRODUCTION_BOOST:
			return Loc.t("PASSIVE_SPECIES_PRODUCTION", {"percent": percent})
		Type.GLOBAL_PRODUCTION_BOOST:
			return Loc.t("PASSIVE_GLOBAL_PRODUCTION", {"percent": percent})
		Type.TAP_VALUE_BOOST:
			return Loc.t("PASSIVE_TAP_VALUE", {"percent": percent})
		Type.THRESHOLD_SYNERGY:
			return Loc.t(
				"PASSIVE_THRESHOLD_SYNERGY", {"percent": percent, "level": threshold_level}
			)
		Type.COMBO_CLICK_BOOST:
			return (
				Loc
				. t(
					"PASSIVE_COMBO_CLICK",
					{
						"percent": percent,
						"clicks": combo_clicks_per_step,
						"max": combo_max_clicks,
					}
				)
			)
		_:
			return ""
