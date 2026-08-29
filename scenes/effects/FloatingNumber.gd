extends Label

## Texto que sobe e desaparece — feedback de "+X" ao tocar/coletar comida.
## Não faz parte da árvore permanente da cena: se auto-destrói no fim.
##
## `start_pos` é o ponto exato do toque (em coordenadas de viewport) — o
## texto fica CENTRADO ali, não com o canto superior esquerdo ali, senão
## números maiores ("+123.4K" vs "+1") apareceriam deslocados do toque de
## verdade. Centralizar exige saber o tamanho já renderizado do texto, por
## isso o cálculo acontece em _ready() (depois de `text` já ter sido
## setado em setup()), não em setup() em si.

const RISE_DISTANCE := 60.0
const DURATION := 0.8

var _start_position: Vector2


func setup(value_text: String, start_pos: Vector2) -> void:
	text = value_text
	_start_position = start_pos


func _ready() -> void:
	position = _start_position - get_minimum_size() / 2.0
	modulate.a = 1.0

	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_delay(0.25)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
