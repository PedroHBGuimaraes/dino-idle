extends PanelContainer

## Notificação passageira que desliza no topo da tela (ver ToastManager) —
## ícone + texto, aparece, segura alguns segundos e some sozinha. Empilha
## com outras num VBox; se destrói ao terminar.

const LIFETIME := 3.2

var _dismissed := false


func setup(text: String, icon: Texture2D = null) -> void:
	%Label.text = text
	if icon != null:
		%Icon.texture = icon
	else:
		%Icon.visible = false


func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	await get_tree().process_frame
	pivot_offset = Vector2(size.x / 2.0, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.set_parallel(false)
	tween.tween_interval(LIFETIME)
	tween.tween_callback(dismiss)


func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.22)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
