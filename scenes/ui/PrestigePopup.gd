extends PanelContainer

## Loja de upgrades permanentes de prestígio + botão de prestigiar — aberta
## pelo botão de prestígio no HUD, só visível/habilitado quando
## PrestigeManager.is_unlocked(). Mirror estrutural de AchievementsPopup
## (lista rolável de linhas), com uma seção extra pro botão de prestigiar em
## si, que pede confirmação inline (toque duas vezes) por ser destrutivo —
## reseta nível e comida da run atual (ver GameManager.reset_for_prestige).

const PrestigeUpgradeRowScene := preload("res://scenes/ui/PrestigeUpgradeRow.tscn")
const ShineSweepScene := preload("res://scenes/effects/ShineSweep.tscn")

var _popup_tween: Tween
var _awaiting_confirmation := false
var _shine: ShineSweep

@onready var _fossils_label: Label = %FossilsLabel
@onready var _production_list: VBoxContainer = %ProductionList
@onready var _tap_list: VBoxContainer = %TapList
@onready var _confirm_warning_label: Label = %ConfirmWarningLabel
@onready var _prestige_button: Button = %PrestigeButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	PrestigeManager.fossils_changed.connect(_on_fossils_changed)
	GameManager.dino_state_changed.connect(_on_dino_state_changed)

	_shine = ShineSweepScene.instantiate()
	_prestige_button.add_child(_shine)

	hide()


func open() -> void:
	_awaiting_confirmation = false
	_refresh()

	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_open(self)


func _on_close_pressed() -> void:
	AudioManager.play_click()
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_close(self)


func _on_fossils_changed(_new_amount: float) -> void:
	_refresh_fossils_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_refresh()


## Nível/desbloqueio mudando pode ter cruzado o piso de prestígio, ou mudado
## quanto a run atual renderia — só importa reavaliar com o popup aberto.
func _on_dino_state_changed(_species_id: StringName, _unlocked: bool, _level: int) -> void:
	if visible:
		_refresh_prestige_button()


func _refresh() -> void:
	_refresh_fossils_label()
	_populate_list(_production_list, PrestigeUpgradeData.Target.PRODUCTION)
	_populate_list(_tap_list, PrestigeUpgradeData.Target.TAP)
	_refresh_prestige_button()


func _refresh_fossils_label() -> void:
	_fossils_label.text = Loc.t(
		"PRESTIGE_FOSSILS", {"amount": FoodFormat.format(PrestigeManager.fossils)}
	)


func _populate_list(list: VBoxContainer, target: PrestigeUpgradeData.Target) -> void:
	for child in list.get_children():
		child.queue_free()
	for upgrade: PrestigeUpgradeData in PrestigeManager.get_all_upgrades():
		if upgrade.target != target:
			continue
		var row := PrestigeUpgradeRowScene.instantiate()
		list.add_child(row)
		row.setup(upgrade)


func _refresh_prestige_button() -> void:
	if not PrestigeManager.can_prestige():
		_awaiting_confirmation = false
		_confirm_warning_label.visible = false
		_prestige_button.text = Loc.t(
			"PRESTIGE_INSUFFICIENT",
			{"percent": roundi(PrestigeManager.PRESTIGE_MIN_PROGRESS * 100.0)}
		)
		_prestige_button.disabled = true
		_shine.set_active(false)
		return

	if _awaiting_confirmation:
		_confirm_warning_label.visible = true
		_prestige_button.text = Loc.t("PRESTIGE_CONFIRM")
	else:
		_confirm_warning_label.visible = false
		var preview := PrestigeManager.preview_fossils_gain()
		_prestige_button.text = Loc.t(
			"PRESTIGE_BUTTON_PREVIEW", {"amount": FoodFormat.format(preview)}
		)
	_prestige_button.disabled = false
	_shine.set_active(not _awaiting_confirmation)


func _on_prestige_pressed() -> void:
	AudioManager.play_click()
	if not _awaiting_confirmation:
		_awaiting_confirmation = true
		_refresh_prestige_button()
		return

	_awaiting_confirmation = false
	if PrestigeManager.perform_prestige():
		_refresh()
