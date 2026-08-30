extends MarginContainer

## Barra superior: comida acumulada, produção passiva atual, botão de
## configurações e os dois botões de anúncio recompensado que não dependem
## de contexto (dobrar produção / bônus de comida instantâneo). O terceiro
## anúncio (dobrar ganhos offline) fica no OfflineEarningsPopup.

signal settings_pressed
signal achievements_pressed
signal prestige_pressed

const ShineSweepScene := preload("res://scenes/effects/ShineSweep.tscn")

var _combo_tween: Tween
var _food_punch_tween: Tween
var _boost_shine: ShineSweep
var _bonus_shine: ShineSweep

## Última string de produção já escrita no label — evita remontar o texto
## (com Loc.t + dicionário) a cada frame quando o valor nem mudou.
var _last_production_text := ""

## Último estado de combo recebido — guardado só pra re-renderizar o label
## quando o idioma muda (o texto tem "Combo:" traduzido).
var _combo_count := 0
var _combo_bonus_mult := 1.0

@onready var _food_label: Label = %FoodLabel
@onready var _production_label: Label = %ProductionLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _achievements_button: TextureButton = %AchievementsButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _prestige_button: Button = %PrestigeButton
@onready var _boost_button: Button = %BoostButton
@onready var _bonus_button: Button = %BonusButton
@onready var _ad_buttons: HBoxContainer = %AdButtons


func _ready() -> void:
	GameManager.food_changed.connect(_on_food_changed)
	GameManager.food_earned.connect(_on_food_earned)
	GameManager.production_boost_changed.connect(_on_production_boost_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.dino_state_changed.connect(_on_dino_state_changed)
	AdsManager.rewarded_ad_ready_changed.connect(_on_ad_ready_changed)
	PrestigeManager.prestige_performed.connect(_on_prestige_performed)

	_achievements_button.pressed.connect(_on_achievements_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_prestige_button.pressed.connect(_on_prestige_button_pressed)
	_boost_button.pressed.connect(_on_boost_pressed)
	_bonus_button.pressed.connect(_on_bonus_pressed)

	_boost_shine = ShineSweepScene.instantiate()
	_boost_button.add_child(_boost_shine)
	_bonus_shine = ShineSweepScene.instantiate()
	_bonus_button.add_child(_bonus_shine)

	_on_food_changed(GameManager.food)
	_render_combo_label()
	_refresh_boost_button()
	_refresh_bonus_button()
	_refresh_prestige_button_visibility()


## Troca de idioma em runtime: re-renderiza tudo que é texto montado por
## código. A produção se conserta sozinha no próximo _process; o resto é
## reavaliado aqui na hora.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_on_food_changed(GameManager.food)
		_render_combo_label()
		_refresh_boost_button()
		_refresh_bonus_button()


func _process(_delta: float) -> void:
	var production_text := Loc.t(
		"HUD_PRODUCTION",
		{"rate": FoodFormat.format_rate(GameManager.get_total_production_per_second())}
	)
	if production_text != _last_production_text:
		_last_production_text = production_text
		_production_label.text = production_text
	if GameManager.is_production_boost_active():
		_refresh_boost_button()


func _on_food_changed(new_amount: float) -> void:
	_food_label.text = Loc.t("HUD_FOOD", {"amount": FoodFormat.format(new_amount)})


## "Pancada" no contador de comida quando entra um ganho DISCRETO relevante
## (toque com combo, bônus de anúncio, ganhos offline) — não o pingo
## constante da produção passiva, que faria o número tremer sem parar.
func _on_food_earned(amount: float) -> void:
	var passive_drip := GameManager.get_total_production_per_second() * 0.5
	if amount < maxf(passive_drip, 2.0):
		return
	_punch_food_label()


func _punch_food_label() -> void:
	_food_label.pivot_offset = Vector2(0.0, _food_label.size.y / 2.0)
	if _food_punch_tween and _food_punch_tween.is_valid():
		_food_punch_tween.kill()
	_food_punch_tween = create_tween()
	(
		_food_punch_tween
		. tween_property(_food_label, "scale", Vector2(1.12, 1.12), 0.07)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_food_punch_tween
		. tween_property(_food_label, "scale", Vector2.ONE, 0.16)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


func _on_production_boost_changed(_active: bool, _expires_unix: float) -> void:
	_refresh_boost_button()


## Único jeito de sabermos que um anúncio recompensado terminou de carregar
## (ou falhou) — sem isso os botões ficam travados no estado desabilitado do
## boot pra sempre, já que nada mais reavalia is_rewarded_ad_ready() depois
## do _ready() enquanto nenhum boost está ativo (ver _process()).
func _on_ad_ready_changed() -> void:
	_refresh_boost_button()
	_refresh_bonus_button()


## Mostra "Combo: Nx" (+ o bônus atual, se algum COMBO_CLICK_BOOST já
## estiver desbloqueado) enquanto o combo estiver ativo, com uma pequena
## "pancada" a cada toque. O label fica sempre visível (mesmo em "Combo: 0x"
## parado) de propósito — alternar visible=true/false mudava a altura do
## VBox a cada início/fim de combo, deslocando o resto do HUD pra cima e
## pra baixo o tempo todo.
func _on_combo_changed(count: int, bonus_multiplier: float) -> void:
	_combo_count = count
	_combo_bonus_mult = bonus_multiplier
	_render_combo_label()
	if count > 0:
		_punch_combo_label()


func _render_combo_label() -> void:
	if _combo_count <= 0:
		_combo_label.text = Loc.t("HUD_COMBO_ZERO")
		return

	var bonus_percent := roundi((_combo_bonus_mult - 1.0) * 100.0)
	_combo_label.text = (
		Loc.t("HUD_COMBO_BONUS", {"count": _combo_count, "percent": bonus_percent})
		if bonus_percent > 0
		else Loc.t("HUD_COMBO", {"count": _combo_count})
	)


func _punch_combo_label() -> void:
	_combo_label.pivot_offset = _combo_label.size / 2.0

	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()

	_combo_tween = create_tween()
	(
		_combo_tween
		. tween_property(_combo_label, "scale", Vector2(1.15, 1.15), 0.06)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_combo_tween
		. tween_property(_combo_label, "scale", Vector2.ONE, 0.14)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


## Progresso mudando pode cruzar o piso de prestígio pela primeira vez — o
## botão precisa aparecer sozinho, sem exigir reabrir o app.
func _on_dino_state_changed(_species_id: StringName, _unlocked: bool, _level: int) -> void:
	_refresh_prestige_button_visibility()


func _on_prestige_performed(_fossils_earned: float) -> void:
	_refresh_prestige_button_visibility()


func _refresh_prestige_button_visibility() -> void:
	_prestige_button.visible = PrestigeManager.is_unlocked()


func _on_achievements_pressed() -> void:
	AudioManager.play_click()
	achievements_pressed.emit()


func _on_settings_pressed() -> void:
	AudioManager.play_click()
	settings_pressed.emit()


func _on_prestige_button_pressed() -> void:
	AudioManager.play_click()
	prestige_pressed.emit()


func _on_boost_pressed() -> void:
	AudioManager.play_click()
	AdsManager.request_double_production_boost()


func _on_bonus_pressed() -> void:
	AudioManager.play_click()
	AdsManager.request_bonus_food()


func _refresh_bonus_button() -> void:
	_bonus_button.disabled = not AdsManager.is_rewarded_ad_ready()
	_bonus_shine.set_active(not _bonus_button.disabled)


## Usado pelo tutorial de onboarding pra destacar os dois botões de anúncio
## recompensado juntos, como um único alvo.
func get_ad_buttons_container() -> Control:
	return _ad_buttons


func _refresh_boost_button() -> void:
	if GameManager.is_production_boost_active():
		var remaining := (
			GameManager.production_boost_expires_unix - Time.get_unix_time_from_system()
		)
		var minutes := int(remaining / 60.0)
		var seconds := int(remaining) % 60
		_boost_button.text = Loc.t("HUD_BOOST_ACTIVE", {"time": "%d:%02d" % [minutes, seconds]})
		_boost_button.disabled = true
	else:
		_boost_button.text = Loc.t("HUD_BOOST_BUTTON")
		_boost_button.disabled = not AdsManager.is_rewarded_ad_ready()
	_boost_shine.set_active(not _boost_button.disabled)
