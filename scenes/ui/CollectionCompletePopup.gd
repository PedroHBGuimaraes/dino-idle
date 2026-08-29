extends Control

## Tela de celebração especial — maior e mais chamativa que os popups padrão
## (OfflineEarningsPopup/SettingsPopup) — mostrada quando GameManager emite
## `collection_completed` (todas as espécies cadastradas desbloqueadas e no
## nível máximo — ver GameManager.is_collection_complete).
##
## Diferente dos popups menores (que são só um painel central, animado via
## PopupTransition), esta cena tem duas partes com animações independentes:
## um fundo escurecido em tela cheia (bloqueia clique atrás) e o painel
## comemorativo em si, que também dispara confete em escala maior.

const FADE_DURATION := 0.25
const PANEL_HIDDEN_SCALE := Vector2(0.85, 0.85)

var _tween: Tween

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _close_button: Button = %CloseButton
@onready var _confetti: CPUParticles2D = %Confetti


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)


func open() -> void:
	show()
	if _tween and _tween.is_valid():
		_tween.kill()

	PopupTransition.fit_pivot_to_size(_panel)
	_dim.modulate.a = 0.0
	_panel.scale = PANEL_HIDDEN_SCALE
	_panel.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, FADE_DURATION)
	(
		_tween
		. tween_property(_panel, "scale", Vector2.ONE, FADE_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_DURATION)

	_confetti.restart()
	_confetti.emitting = true


func _on_close_pressed() -> void:
	AudioManager.play_click()
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, FADE_DURATION)
	(
		_tween
		. tween_property(_panel, "scale", PANEL_HIDDEN_SCALE, FADE_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_DURATION)
	_tween.set_parallel(false)
	_tween.tween_callback(hide)
