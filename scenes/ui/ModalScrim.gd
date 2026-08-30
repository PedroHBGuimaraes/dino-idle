class_name ModalScrim
extends ColorRect

## Fundo escurecido único, compartilhado por todos os popups que passam pelo
## PopupTransition. Fica no PopupLayer (CanvasLayer), como PRIMEIRO filho, pra
## desenhar atrás dos popups. Some sozinho quando o último popup fecha.
##
## Também bloqueia o toque no jogo por trás (mouse_filter = STOP) e, ao ser
## tocado na área livre em volta do popup, pede pro popup do topo fechar
## (grupo "modal_popup" + método request_close()).

const DIM_COLOR := Color(0.02, 0.015, 0.01, 0.62)
const FADE_DURATION := 0.16

var _fade_tween: Tween


func _ready() -> void:
	add_to_group(&"modal_scrim")
	color = Color(DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b, 0.0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	gui_input.connect(_on_gui_input)


func show_scrim() -> void:
	visible = true
	_fade_to(DIM_COLOR.a)


func hide_scrim() -> void:
	_fade_to(0.0)
	_fade_tween.tween_callback(_hide_if_transparent)


## Só esconde de fato se ninguém reacendeu o scrim no meio do fade (outro
## popup abrindo cancela o fade e sobe a opacidade de novo).
func _hide_if_transparent() -> void:
	if color.a <= 0.01:
		visible = false


func _fade_to(target_alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "color:a", target_alpha, FADE_DURATION)


func _on_gui_input(event: InputEvent) -> void:
	var released: bool = (
		(event is InputEventMouseButton and not event.pressed)
		or (event is InputEventScreenTouch and not event.pressed)
	)
	if not released:
		return
	var top: Node = null
	for node in get_tree().get_nodes_in_group(&"modal_popup"):
		if node is CanvasItem and node.visible and node.has_method("request_close"):
			top = node
	if top:
		top.request_close()
