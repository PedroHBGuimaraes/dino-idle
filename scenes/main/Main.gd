extends Control

## Cena raiz. Liga o toque manual ao GameManager e dispara o carregamento do
## save DEPOIS que a UI filha (HUD/ShopPanel/Popup) já está pronta e
## conectada aos sinais, para que o estado carregado (e os ganhos offline)
## cheguem corretamente na tela. Também inicia a música de fundo, liga o
## botão de configurações do HUD ao popup de áudio, dá o feedback de "juice"
## do toque (número flutuante + squash&stretch), e move as camadas de fundo
## (montanha/palmeiras) em velocidades diferentes conforme a lista de dinos
## rola, pra dar sensação de profundidade.

const PARALLAX_FAR_PIXELS := 10.0
const PARALLAX_NEAR_PIXELS := 22.0
const BACKGROUND_BASE_Y := -30.0

const ShineSweepScene := preload("res://scenes/effects/ShineSweep.tscn")

## Cenário vivo: conforme o progresso geral da coleção (ver
## GameManager.get_collection_progress) avança, o fundo vai ganhando vida —
## puramente decorativo, nunca bloqueia interação. Cada elemento aparece
## uma única vez (progresso é monotônico, nunca regride) e fica.
const SCENERY_FLOWER_THRESHOLD := 0.25
const SCENERY_DISTANT_DINO_THRESHOLD := 0.6
const SCENERY_GOLDEN_GLOW_THRESHOLD := 0.9
const SCENERY_FADE_DURATION := 1.4
const GOLDEN_GLOW_COLOR := Color(1.08, 1.02, 0.92, 1.0)

var _tap_bounce_tween: Tween
var _last_tap_local_pos: Vector2 = Vector2.ZERO
var _has_tap_position: bool = false

var _flower_shown := false
var _distant_dino_shown := false
var _golden_glow_shown := false

## Espécie "estrela" mostrada na área central de alimentar — a desbloqueada
## de maior nível (empate: ordem do SpeciesDatabase). Recalculada a cada
## desbloqueio/level up.
var _feed_star_id: StringName = &""
var _feed_bowl_tween: Tween

@onready var _tap_area: Button = %TapArea
@onready var _feed_dino = %FeedDino
@onready var _feed_bowl: TextureRect = %FeedBowl
@onready var _hud = %HUD
@onready var _settings_popup = %SettingsPopup
@onready var _shop_panel = %ShopPanel
@onready var _bg_far: TextureRect = %BackgroundFar
@onready var _bg_near: TextureRect = %BackgroundNear
@onready var _flower_cluster: TextureRect = %FlowerCluster
@onready var _distant_dino: TextureRect = %DistantDino
@onready var _collection_complete_popup = %CollectionCompletePopup
@onready var _species_detail_popup = %SpeciesDetailPopup
@onready var _achievements_popup = %AchievementsPopup
@onready var _prestige_popup = %PrestigePopup
@onready var _onboarding = %OnboardingOverlay


func _ready() -> void:
	_tap_area.gui_input.connect(_on_tap_area_gui_input)
	_tap_area.pressed.connect(_on_tap_area_pressed)
	_hud.settings_pressed.connect(_settings_popup.open)
	_hud.achievements_pressed.connect(_achievements_popup.open)
	_hud.prestige_pressed.connect(_prestige_popup.open)
	_shop_panel.scrolled.connect(_on_shop_scrolled)
	_shop_panel.species_info_requested.connect(_species_detail_popup.open)
	GameManager.collection_completed.connect(_collection_complete_popup.open)
	GameManager.dino_state_changed.connect(_update_scenery_progress)
	GameManager.dino_state_changed.connect(_on_dino_state_changed_for_feed)

	# TapArea é a ação central do jogo — brilho constante, estilo "máquina
	# ligada" de cassino, sempre convidando o toque.
	var tap_shine := ShineSweepScene.instantiate()
	_tap_area.add_child(tap_shine)
	tap_shine.set_active(true)

	SaveManager.load_game()
	AudioManager.play_music()

	if not SaveManager.tutorial_completed:
		_start_onboarding()

	_update_scenery_progress()
	_refresh_feed_star()


## Passa os controles reais que cada passo do tutorial destaca. O card do
## Velociraptor precisa estar visível na lista (rolada até ele) antes de
## medir sua posição pra recortar o "buraco" ao redor dele.
func _start_onboarding() -> void:
	var velociraptor_card: Control = _shop_panel.scroll_to_species(&"velociraptor")
	_onboarding.start(_tap_area, velociraptor_card, _hud.get_ad_buttons_container())


func _on_shop_scrolled(ratio: float) -> void:
	_bg_far.position.y = BACKGROUND_BASE_Y - ratio * PARALLAX_FAR_PIXELS
	_bg_near.position.y = BACKGROUND_BASE_Y - ratio * PARALLAX_NEAR_PIXELS


## Guarda a posição exata do toque/clique (em coordenadas locais do
## TapArea) assim que ele acontece — `Button.pressed` só dispara depois,
## e `get_global_mouse_position()` naquele momento pode não refletir mais
## onde o dedo realmente tocou. Usada só pra posicionar o número flutuante.
func _on_tap_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_last_tap_local_pos = event.position
		_has_tap_position = true
	elif event is InputEventScreenTouch and event.pressed:
		_last_tap_local_pos = event.position
		_has_tap_position = true


func _on_tap_area_pressed() -> void:
	var amount := GameManager.tap()
	AudioManager.play_tap(GameManager.get_combo_count())
	Input.vibrate_handheld(12)

	# O número sai de cima do dino que está sendo alimentado (não do ponto do
	# dedo) — reforça "eu alimentei ESTE dino", e fica legível mesmo com o
	# polegar cobrindo a área.
	var pos: Vector2 = _feed_dino.global_position + _feed_dino.size * Vector2(0.5, 0.3)
	_has_tap_position = false

	EffectsManager.spawn_floating_number("+%s" % FoodFormat.format(amount), pos)
	_bounce_tap_area()
	_bump_feed_bowl()
	if _feed_dino.has_method("play_feed_reaction"):
		_feed_dino.play_feed_reaction()
	_onboarding.register_tap()


## Um "chega mais" da tigela a cada alimentada — micro-squash rápido.
func _bump_feed_bowl() -> void:
	_feed_bowl.pivot_offset = _feed_bowl.size / 2.0
	if _feed_bowl_tween and _feed_bowl_tween.is_valid():
		_feed_bowl_tween.kill()
	_feed_bowl_tween = create_tween()
	(
		_feed_bowl_tween
		. tween_property(_feed_bowl, "scale", Vector2(1.12, 0.9), 0.05)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_feed_bowl_tween
		. tween_property(_feed_bowl, "scale", Vector2.ONE, 0.18)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


## Escolhe a espécie estrela (desbloqueada de maior nível) e atualiza o
## visual central. Chamado ao carregar e a cada mudança de estado de dino.
func _refresh_feed_star() -> void:
	var best: DinoSpeciesData = null
	var best_level := -1
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not GameManager.is_unlocked(species.id):
			continue
		var level := GameManager.get_level(species.id)
		if level > best_level:
			best_level = level
			best = species
	if best == null:
		return
	if best.id == _feed_star_id:
		_feed_dino.set_level(best, best_level)
	else:
		_feed_star_id = best.id
		_feed_dino.setup(best, best_level)


func _on_dino_state_changed_for_feed(_species_id: StringName, _unlocked: bool, _level: int) -> void:
	_refresh_feed_star()


func _bounce_tap_area() -> void:
	_tap_area.pivot_offset = _tap_area.size / 2.0

	if _tap_bounce_tween and _tap_bounce_tween.is_valid():
		_tap_bounce_tween.kill()

	_tap_bounce_tween = create_tween()
	(
		_tap_bounce_tween
		. tween_property(_tap_area, "scale", Vector2(1.06, 0.92), 0.06)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tap_bounce_tween
		. tween_property(_tap_area, "scale", Vector2(1.0, 1.0), 0.16)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


## Revela os elementos decorativos do cenário vivo conforme o progresso
## geral da coleção cruza cada marco — chamado uma vez ao carregar o save
## (pra sincronizar com o progresso já existente) e de novo a cada
## desbloqueio/level up. Cada marco só anima uma vez (flags _*_shown); como
## o progresso nunca regride, não precisa reverter nada.
func _update_scenery_progress(
	_species_id: StringName = &"", _unlocked: bool = false, _level: int = 0
) -> void:
	var progress := GameManager.get_collection_progress()

	if not _flower_shown and progress >= SCENERY_FLOWER_THRESHOLD:
		_flower_shown = true
		_fade_in_scenery(_flower_cluster)

	if not _distant_dino_shown and progress >= SCENERY_DISTANT_DINO_THRESHOLD:
		_distant_dino_shown = true
		_fade_in_scenery(_distant_dino)

	if not _golden_glow_shown and progress >= SCENERY_GOLDEN_GLOW_THRESHOLD:
		_golden_glow_shown = true
		_fade_golden_glow()


func _fade_in_scenery(node: TextureRect) -> void:
	(
		create_tween()
		. tween_property(node, "modulate:a", 1.0, SCENERY_FADE_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


## Banha o horizonte e a ilha numa luz dourada suave quando a coleção está
## quase completa — a variação de "hora do dia" prometida pelo cenário vivo,
## sem precisar de arte nova (só um tween de cor sobre o que já existe).
func _fade_golden_glow() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bg_far, "modulate", GOLDEN_GLOW_COLOR, SCENERY_FADE_DURATION * 1.4)
	tween.tween_property(_bg_near, "modulate", GOLDEN_GLOW_COLOR, SCENERY_FADE_DURATION * 1.4)
