class_name AchievementData
extends RefCounted

## Definição de uma conquista — puramente em código (não .tres como as
## espécies), porque a CONDIÇÃO de desbloqueio de cada uma é lógica de jogo
## (produção atual, contagem de toques, etc.), não dado estático; ver
## AchievementManager._build_achievements(). `icon_filename` é procurado em
## res://assets/achievements/ — se não existir ainda, AchievementRow cai
## num ícone placeholder (mesmo espírito do placeholder dos dinos).
##
## Nome e descrição vêm da tradução: as chaves são derivadas do `id`
## (&"first_unlock" -> ACH_FIRST_UNLOCK_NAME / ACH_FIRST_UNLOCK_DESC). Ver
## get_display_name()/get_description().

var id: StringName
var icon_filename: String

## Quantidade que a descrição interpola no placeholder {amount} (conquistas
## de produção/toque/comida). -1.0 = descrição sem placeholder.
var _desc_amount: float


func _init(p_id: StringName, p_icon_filename: String, p_desc_amount: float = -1.0) -> void:
	id = p_id
	icon_filename = p_icon_filename
	_desc_amount = p_desc_amount


func get_display_name() -> String:
	return Loc.t("ACH_" + String(id).to_upper() + "_NAME")


func get_description() -> String:
	var key := "ACH_" + String(id).to_upper() + "_DESC"
	if _desc_amount >= 0.0:
		return Loc.t(key, {"amount": FoodFormat.format(_desc_amount)})
	return Loc.t(key)
