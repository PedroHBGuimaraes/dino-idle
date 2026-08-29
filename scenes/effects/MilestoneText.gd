extends Label

## Texto maior que FloatingNumber que sobe e desaparece — reservado pro
## marco de um dino individual alcançar o nível 100 pela primeira vez (ver
## EffectsManager.spawn_milestone_celebration). Não faz parte da árvore
## permanente da cena: se auto-destrói no fim.

const RISE_DISTANCE := 46.0
const DURATION := 1.1

var _start_position: Vector2


func setup(value_text: String, start_pos: Vector2) -> void:
	text = value_text
	_start_position = start_pos


func _ready() -> void:
	position = _start_position - get_minimum_size() / 2.0
	modulate.a = 1.0
	scale = Vector2(0.7, 0.7)
	pivot_offset = get_minimum_size() / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_delay(0.5)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
