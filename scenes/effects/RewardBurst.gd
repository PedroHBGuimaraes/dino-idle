extends CPUParticles2D

## Explosão rápida de partículas (confete/brilho) pra desbloqueio/evolução.
## Não faz parte da árvore permanente da cena: se auto-destrói no fim.


func _ready() -> void:
	one_shot = true
	emitting = true
	await get_tree().create_timer(lifetime + 0.15).timeout
	queue_free()
