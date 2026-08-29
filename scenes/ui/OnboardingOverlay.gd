extends CanvasLayer

## Tutorial de 3 passos mostrado só na primeira vez que o jogador abre o app
## (ver SaveManager.tutorial_completed, checado pelo Main.gd). Cada passo
## escurece a tela inteira com 4 ColorRects ao redor do controle real sendo
## explicado, deixando um "buraco" sem nada por cima — o controle continua
## visível e tocável de verdade (o passo 1 conta toques reais na área de
## alimentar). Pulável a qualquer momento via %SkipButton.

signal finished

const PADDING := 10.0
const TAP_GOAL := 3
const STEP_COUNT := 3

var _step := 0
var _tap_count := 0
var _tap_area: Control
var _dino_card: Control
var _ad_buttons: Control
var _highlight_pulse_tween: Tween

@onready var _dim_top: ColorRect = %DimTop
@onready var _dim_bottom: ColorRect = %DimBottom
@onready var _dim_left: ColorRect = %DimLeft
@onready var _dim_right: ColorRect = %DimRight
@onready var _highlight: Panel = %Highlight
@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _step_label: Label = %StepLabel
@onready var _next_button: Button = %NextButton
@onready var _skip_button: Button = %SkipButton


func _ready() -> void:
	_next_button.pressed.connect(_on_next_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	hide()


## Chamado pelo Main.gd depois que a UI real já está pronta e o save
## carregado, passando os controles de verdade que cada passo destaca.
## `dino_card`/`ad_buttons` podem ser null (ex. cena ainda não montada
## direito) — o passo correspondente é pulado nesse caso.
func start(tap_area: Control, dino_card: Control, ad_buttons: Control) -> void:
	_tap_area = tap_area
	_dino_card = dino_card
	_ad_buttons = ad_buttons
	_tap_count = 0
	show()
	_show_step(0)


## Chamado pelo Main.gd a cada toque real na área de alimentar. Só conta
## enquanto o passo 1 estiver ativo.
func register_tap() -> void:
	if not visible or _step != 0:
		return
	_tap_count += 1
	if _tap_count >= TAP_GOAL:
		_advance()


func _show_step(step: int) -> void:
	_step = step
	_step_label.text = "%d/%d" % [step + 1, STEP_COUNT]

	match step:
		0:
			_title_label.text = Loc.t("ONBOARDING_1_TITLE")
			_description_label.text = Loc.t("ONBOARDING_1_BODY")
			_next_button.visible = false
			_highlight_target(_tap_area)
		1:
			_title_label.text = Loc.t("ONBOARDING_2_TITLE")
			_description_label.text = Loc.t("ONBOARDING_2_BODY")
			_next_button.visible = true
			if _dino_card:
				_highlight_target(_dino_card)
			else:
				_advance()
		2:
			_title_label.text = Loc.t("ONBOARDING_3_TITLE")
			_description_label.text = Loc.t("ONBOARDING_3_BODY")
			_next_button.visible = true
			if _ad_buttons:
				_highlight_target(_ad_buttons)
			else:
				_advance()


func _highlight_target(target: Control) -> void:
	# Dois frames, não um: no primeiro show (logo após o boot), o ShopPanel
	# ainda está montando os DinoCards e rolando até o Velociraptor no mesmo
	# instante — um único frame não é garantia de que esse layout (aninhado
	# em containers) já assentou, e o retângulo sai errado só na primeira vez.
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var hole := target.get_global_rect().grow(PADDING)
	hole = hole.intersection(Rect2(Vector2.ZERO, viewport_size))

	_dim_top.position = Vector2.ZERO
	_dim_top.size = Vector2(viewport_size.x, hole.position.y)

	_dim_bottom.position = Vector2(0.0, hole.position.y + hole.size.y)
	_dim_bottom.size = Vector2(viewport_size.x, viewport_size.y - _dim_bottom.position.y)

	_dim_left.position = Vector2(0.0, hole.position.y)
	_dim_left.size = Vector2(hole.position.x, hole.size.y)

	_dim_right.position = Vector2(hole.position.x + hole.size.x, hole.position.y)
	_dim_right.size = Vector2(viewport_size.x - _dim_right.position.x, hole.size.y)

	_highlight.position = hole.position
	_highlight.size = hole.size

	_pulse_highlight()


func _pulse_highlight() -> void:
	if _highlight_pulse_tween and _highlight_pulse_tween.is_valid():
		_highlight_pulse_tween.kill()

	_highlight.modulate.a = 1.0
	_highlight_pulse_tween = create_tween().set_loops()
	(
		_highlight_pulse_tween
		. tween_property(_highlight, "modulate:a", 0.55, 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_highlight_pulse_tween
		. tween_property(_highlight, "modulate:a", 1.0, 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _advance() -> void:
	if _step >= STEP_COUNT - 1:
		_finish()
	else:
		_show_step(_step + 1)


func _on_next_pressed() -> void:
	AudioManager.play_click()
	_advance()


func _on_skip_pressed() -> void:
	AudioManager.play_click()
	_finish()


func _finish() -> void:
	if _highlight_pulse_tween and _highlight_pulse_tween.is_valid():
		_highlight_pulse_tween.kill()
	SaveManager.mark_tutorial_completed()
	hide()
	finished.emit()
