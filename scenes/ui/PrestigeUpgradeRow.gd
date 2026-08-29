extends PanelContainer

## Uma linha da loja de prestígio: nome + descrição do upgrade, nível atual,
## custo do próximo nível e um botão de comprar — mirror de AchievementRow,
## mas orientado a compra em vez de estado desbloqueado/bloqueado.

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _level_label: Label = %LevelLabel
@onready var _buy_button: Button = %BuyButton

var _upgrade: PrestigeUpgradeData


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	PrestigeManager.fossils_changed.connect(_on_fossils_changed)
	PrestigeManager.upgrade_purchased.connect(_on_upgrade_purchased)


func setup(upgrade: PrestigeUpgradeData) -> void:
	_upgrade = upgrade
	_name_label.text = upgrade.get_display_name()
	_description_label.text = upgrade.get_description()
	_refresh()


func _on_fossils_changed(_new_amount: float) -> void:
	_refresh_buy_button()


func _on_upgrade_purchased(upgrade_id: StringName, _new_level: int) -> void:
	if _upgrade != null and upgrade_id == _upgrade.id:
		_refresh()


func _on_buy_pressed() -> void:
	if PrestigeManager.buy_upgrade(_upgrade.id):
		AudioManager.play_click()


func _refresh() -> void:
	var level := PrestigeManager.get_upgrade_level(_upgrade.id)
	var bonus_percent := roundi(_upgrade.bonus_for_level(level) * 100.0)
	_level_label.text = Loc.t(
		"PRESTIGE_ROW_LEVEL", {"level": level, "max": _upgrade.max_level, "percent": bonus_percent}
	)
	_refresh_buy_button()


func _refresh_buy_button() -> void:
	if _upgrade == null:
		return
	var cost := PrestigeManager.cost_for_next_level(_upgrade.id)
	if cost < 0.0:
		_buy_button.text = Loc.t("PRESTIGE_ROW_MAX")
		_buy_button.disabled = true
		return
	_buy_button.text = Loc.t("PRESTIGE_ROW_BUY_COST", {"cost": FoodFormat.format(cost)})
	_buy_button.disabled = not PrestigeManager.can_afford(_upgrade.id)
