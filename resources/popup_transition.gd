class_name PopupTransition
extends RefCounted

## Animação compartilhada de abrir/fechar popup (fade + scale), usada por
## OfflineEarningsPopup e SettingsPopup para não aparecer/sumir instantâneo.
## O pivot é recalculado a cada abertura a partir do tamanho atual do popup,
## então o scale sempre parte do centro real mesmo quando o popup não tem
## tamanho fixo (ver `fit_pivot_to_size`).

const OPEN_DURATION := 0.18
const CLOSE_DURATION := 0.12
const HIDDEN_SCALE := Vector2(0.85, 0.85)


## `popup.size` pode estar um frame atrasado em relação a uma mudança de
## conteúdo que acabou de acontecer na mesma chamada (labels/linhas trocadas
## logo antes de abrir) — o layout dos containers só assenta de verdade no
## próximo frame. `get_combined_minimum_size()` já dá o tamanho mínimo real
## na hora, sem esperar; usamos o maior entre os dois porque um popup
## ancorado numa fração da tela (ex. AchievementsPopup) pode ser bem maior
## que seu conteúdo mínimo, e aí é o `size` atual que manda.
static func fit_pivot_to_size(popup: Control) -> void:
	popup.pivot_offset = popup.size.max(popup.get_combined_minimum_size()) / 2.0


static func animate_open(popup: Control) -> Tween:
	fit_pivot_to_size(popup)
	popup.scale = HIDDEN_SCALE
	popup.modulate.a = 0.0
	popup.show()

	var tween := popup.create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(popup, "scale", Vector2.ONE, OPEN_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(popup, "modulate:a", 1.0, OPEN_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	return tween


static func animate_close(popup: Control) -> Tween:
	var tween := popup.create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(popup, "scale", HIDDEN_SCALE, CLOSE_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. tween_property(popup, "modulate:a", 0.0, CLOSE_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	tween.set_parallel(false)
	tween.tween_callback(popup.hide)
	return tween
