extends PanelContainer

## Uma linha da família: mostra o placeholder do dino, nome, nível atual e
## um botão único que ou desbloqueia a espécie (se ainda bloqueada) ou sobe
## seu nível (se já desbloqueada e não estiver no nível máximo). Um card
## por espécie, criado dinamicamente pelo ShopPanel.
##
## Também mostra até 4 selos (%PassiveBadges) pros marcos de passiva
## (nível 25/50/75/100) já alcançados — ver GameManager.get_passives_unlocked.
## O %InfoButton abre um popup com o detalhe de TODAS as passivas (incluindo
## as ainda bloqueadas) — os selos sozinhos dependiam de tooltip (hover), que
## não funciona em touch; ver `info_requested`.

signal info_requested(species: DinoSpeciesData)

const ICON_LOCK := preload("res://assets/ui/icon_lock.png")
const ICON_EVOLVE := preload("res://assets/ui/icon_evolve.png")
const ICON_CHECK := preload("res://assets/ui/icon_check.png")
const ShineSweepScene := preload("res://scenes/effects/ShineSweep.tscn")
const MAX_LEVEL_COLOR := Color(0.16, 0.55, 0.25)
const SILHOUETTE_COLOR := Color(0.02, 0.02, 0.02, 0.9)
const REVEALED_COLOR := Color(1, 1, 1, 1)

## Marcos de nível que concedem passiva — cada um tem seu selo (medalha
## bronze/prata/ouro/estrela lendária, ver assets/ui/badges_sheet.png,
## recortado em AtlasTexture no DinoCard.tscn).
const PASSIVE_MILESTONES := [25, 50, 75, 100]

var _species: DinoSpeciesData
var _ready_pulse_tween: Tween
var _is_ready_pulsing := false
var _shine: ShineSweep

@onready var _dino_visual = %DinoVisual
@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _production_label: Label = %ProductionLabel
@onready var _evolve_progress: ProgressBar = %EvolveProgress
@onready var _action_button: Button = %ActionButton
@onready var _badge_25: TextureRect = %Badge25
@onready var _badge_50: TextureRect = %Badge50
@onready var _badge_75: TextureRect = %Badge75
@onready var _badge_100: TextureRect = %Badge100
@onready var _info_button: Button = %InfoButton


func _ready() -> void:
	_action_button.pressed.connect(_on_action_pressed)
	_info_button.pressed.connect(_on_info_pressed)
	GameManager.dino_state_changed.connect(_on_dino_state_changed)
	GameManager.food_changed.connect(_on_food_changed)
	GameManager.production_boost_changed.connect(_on_production_boost_changed)

	_shine = ShineSweepScene.instantiate()
	_action_button.add_child(_shine)


func setup(species: DinoSpeciesData) -> void:
	_species = species
	_refresh()


## Troca de idioma em runtime: só o texto (nome, status, botão, tooltips dos
## selos) — sem re-rodar _refresh() inteiro, que reinicia a animação do dino.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _species != null:
		_refresh_text()


## Usado pelo ShopPanel pra localizar o card de uma espécie específica (ex.
## pelo tutorial de onboarding, que destaca o card do Velociraptor).
func get_species_id() -> StringName:
	return _species.id


func _on_dino_state_changed(species_id: StringName, _unlocked: bool, _level: int) -> void:
	if _species == null or species_id != _species.id:
		return
	_refresh()


func _on_food_changed(_new_amount: float) -> void:
	_refresh_action_button()


func _on_production_boost_changed(_active: bool, _expires_unix: float) -> void:
	_refresh_production_label()


func _on_info_pressed() -> void:
	AudioManager.play_click()
	info_requested.emit(_species)


func _on_action_pressed() -> void:
	if GameManager.is_unlocked(_species.id):
		var old_level := GameManager.get_level(_species.id)
		if GameManager.level_up_dino(_species.id):
			var new_level := GameManager.get_level(_species.id)
			var is_stage_transition := (
				_species.stage_for_level(old_level) != _species.stage_for_level(new_level)
			)
			# Só é "primeira vez" quando o level up ATUAL cruzou pro máximo —
			# não é revisitável depois (level nunca desce e can_level_up()
			# nunca mais libera outra chamada que passaria por aqui de novo).
			var just_reached_max := (
				new_level == DinoSpeciesData.MAX_LEVEL and old_level < DinoSpeciesData.MAX_LEVEL
			)
			if just_reached_max:
				AudioManager.play_milestone()
				Input.vibrate_handheld(60)
			else:
				AudioManager.play_evolve()
				Input.vibrate_handheld(25 if is_stage_transition else 12)
			# _refresh() já rodou (dino_state_changed é síncrono), então o
			# sprite já está na forma nova quando o pop de escala começa.
			_dino_visual.play_growth_effect(is_stage_transition)
			_spawn_reward_burst()
			if is_stage_transition:
				_spawn_growth_burst()
			if just_reached_max:
				_spawn_milestone_celebration()
	else:
		if GameManager.unlock_dino(_species.id):
			AudioManager.play_unlock()
			Input.vibrate_handheld(40)
			_spawn_reward_burst()


func _spawn_reward_burst() -> void:
	var center := _action_button.global_position + _action_button.size / 2.0
	EffectsManager.spawn_reward_burst(center)


## Burst extra, na posição do PRÓPRIO dino (não do botão) — só em
## transições de estágio, o momento mais marcante (ver play_growth_effect).
func _spawn_growth_burst() -> void:
	var center: Vector2 = _dino_visual.global_position + _dino_visual.size / 2.0
	EffectsManager.spawn_reward_burst(center)


## Celebração do marco de nível 100 (primeira vez), na posição do próprio
## dino — ver EffectsManager.spawn_milestone_celebration.
func _spawn_milestone_celebration() -> void:
	var center: Vector2 = _dino_visual.global_position + _dino_visual.size / 2.0
	EffectsManager.spawn_milestone_celebration(center)


func _refresh() -> void:
	var unlocked := GameManager.is_unlocked(_species.id)
	var level := GameManager.get_level(_species.id)

	if unlocked:
		_dino_visual.modulate = REVEALED_COLOR
		_dino_visual.setup(_species, level)
	else:
		# Silhueta escurecida do estágio Adulto — dá a sensação de "tem algo
		# esperando ali" em vez de deixar o espaço vazio. `animated = false`:
		# silhueta não precisa do AnimatedTexture de idle (ver Dino.setup).
		_dino_visual.modulate = SILHOUETTE_COLOR
		_dino_visual.setup(_species, DinoSpeciesData.MAX_LEVEL, false)

	_refresh_text()


func _refresh_text() -> void:
	var unlocked := GameManager.is_unlocked(_species.id)
	var level := GameManager.get_level(_species.id)

	_name_label.text = _species.get_display_name()
	_status_label.text = (
		Loc.t("CARD_LEVEL", {"level": level}) if unlocked else Loc.t("CARD_LOCKED")
	)
	_refresh_action_button()
	_refresh_production_label()
	_refresh_badges()


func _refresh_production_label() -> void:
	if not GameManager.is_unlocked(_species.id):
		_production_label.text = ""
		return
	var rate := GameManager.get_species_current_production(_species.id)
	_production_label.text = Loc.t("CARD_PRODUCTION_RATE", {"rate": FoodFormat.format_rate(rate)})


## Cada selo mostra/esconde por marco e ganha uma tooltip descrevendo a
## passiva ESPECÍFICA desta espécie naquele marco (varia por dino — ver
## PassiveEffect.describe()), mesmo pra marcos ainda não alcançados (ajuda
## o jogador a planejar pra onde investir comida).
func _refresh_badges() -> void:
	var unlocked := GameManager.is_unlocked(_species.id)
	var level := GameManager.get_level(_species.id) if unlocked else 0
	for milestone: int in PASSIVE_MILESTONES:
		var badge := _get_badge(milestone)
		badge.visible = unlocked and level >= milestone
		var passive := _species.get_passive_for_milestone(milestone)
		if passive != null:
			badge.tooltip_text = Loc.t(
				"CARD_BADGE_TOOLTIP", {"level": milestone, "effect": passive.describe()}
			)


func _get_badge(milestone: int) -> TextureRect:
	match milestone:
		25:
			return _badge_25
		50:
			return _badge_50
		75:
			return _badge_75
		_:
			return _badge_100


func _refresh_action_button() -> void:
	var unlocked := GameManager.is_unlocked(_species.id)

	if not unlocked:
		_action_button.icon = ICON_LOCK
		_action_button.text = Loc.t(
			"CARD_UNLOCK_BUTTON", {"cost": FoodFormat.format(_species.unlock_cost)}
		)
		_action_button.disabled = not GameManager.can_unlock(_species.id)
		_evolve_progress.visible = false
		_set_ready_pulse(false)
		return

	var level := GameManager.get_level(_species.id)
	if _species.is_max_level(level):
		_action_button.icon = ICON_CHECK
		_action_button.text = Loc.t("CARD_MAX_LEVEL_BUTTON")
		_action_button.disabled = true
		_action_button.add_theme_color_override("font_disabled_color", MAX_LEVEL_COLOR)
		_action_button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 1))
		_evolve_progress.visible = false
		_set_ready_pulse(false)
		return

	var cost := _species.cost_for_level(level)
	var can_level_up := GameManager.can_level_up(_species.id)
	_action_button.icon = ICON_EVOLVE
	_action_button.text = Loc.t("CARD_LEVELUP_BUTTON", {"cost": FoodFormat.format(cost)})
	_action_button.disabled = not can_level_up

	_evolve_progress.visible = true
	_evolve_progress.value = clampf(GameManager.food / cost, 0.0, 1.0) if cost > 0.0 else 1.0

	_set_ready_pulse(can_level_up)


## Liga/desliga o pulso de destaque no botão quando o jogador tem comida
## suficiente pra subir de nível. Idempotente — chamado a cada refresh
## (inclusive em todo `food_changed`), então só mexe no Tween quando o
## estado realmente muda.
func _set_ready_pulse(active: bool) -> void:
	_shine.set_active(active)

	if active == _is_ready_pulsing:
		return
	_is_ready_pulsing = active

	if _ready_pulse_tween and _ready_pulse_tween.is_valid():
		_ready_pulse_tween.kill()

	if not active:
		_action_button.modulate = Color(1, 1, 1, 1)
		return

	_ready_pulse_tween = create_tween().set_loops()
	(
		_ready_pulse_tween
		. tween_property(_action_button, "modulate", Color(1.7, 1.45, 0.55, 1), 0.4)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_ready_pulse_tween
		. tween_property(_action_button, "modulate", Color(1, 1, 1, 1), 0.4)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
