class_name ShineSweep
extends Control

## Faixa diagonal clara que desliza da esquerda pra direita em loop por cima
## de um botão — brilho estilo cassino/gacha sem precisar de shader (mesma
## técnica do degradê de ShopPanel.BottomFade, mesmo padrão de loop do brilho
## lendário/pulso de "pronto" já usados em Dino.gd/DinoCard.gd).
##
## Uso: `var shine := ShineSweepScene.instantiate(); button.add_child(shine)`
## — preenche o retângulo do pai sozinho (button não é Container, então isso
## não mexe em layout de ninguém) e só balança quando set_active(true).
##
## mouse_filter = IGNORE é essencial: como fica por cima do botão (último
## filho = desenhado por último), sem isso ele rouba o toque do botão —
## mesma lição já aplicada em DinoCard.tscn pro bug de scroll no
## ScrollContainer.

const SWEEP_DURATION := 0.9
const PAUSE_DURATION := 1.6
const STREAK_WIDTH_RATIO := 0.35

@export var streak_color: Color = Color(1.0, 0.97, 0.85, 0.55)

var _streak: TextureRect
var _sweep_tween: Tween
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	anchor_right = 1.0
	anchor_bottom = 1.0

	_streak = TextureRect.new()
	_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak.texture = _build_streak_texture()
	_streak.rotation_degrees = 20.0
	add_child(_streak)

	resized.connect(_layout_streak)
	_layout_streak()


func _build_streak_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	var transparent := Color(streak_color.r, streak_color.g, streak_color.b, 0.0)
	gradient.colors = PackedColorArray([transparent, streak_color, transparent])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 0.0)
	return texture


## Chamado sempre que o botão pai muda de tamanho (não só uma vez) — evita o
## mesmo tipo de bug de "tamanho errado no primeiro frame" já visto neste
## projeto (retângulo do tutorial de onboarding).
func _layout_streak() -> void:
	var streak_width := maxf(size.x * STREAK_WIDTH_RATIO, 16.0)
	var streak_height := size.y * 1.6  # mais alto que o botão pra cobrir a rotação
	_streak.size = Vector2(streak_width, streak_height)
	_streak.position = Vector2(-streak_width, (size.y - streak_height) / 2.0)
	if _active:
		_loop_sweep()


## Só balança quando `active` — reserva o brilho pros momentos em que o
## botão está de fato acionável, em vez de ficar constante em tudo.
func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	if active:
		_loop_sweep()
	elif _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()


func _loop_sweep() -> void:
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()

	var start_x := -_streak.size.x
	var end_x := size.x + _streak.size.x
	_streak.position.x = start_x

	_sweep_tween = create_tween().set_loops()
	(
		_sweep_tween
		. tween_property(_streak, "position:x", end_x, SWEEP_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_sweep_tween.tween_interval(PAUSE_DURATION)
