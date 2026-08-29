extends CPUParticles2D

## Explosão de confete maior/mais colorida que RewardBurst — reservada pro
## marco de um dino individual alcançar o nível 100 pela primeira vez (ver
## DinoCard._on_action_pressed() e EffectsManager.spawn_milestone_celebration).
## Não faz parte da árvore permanente da cena: se auto-destrói no fim.


func _ready() -> void:
	one_shot = true
	emitting = true
	await get_tree().create_timer(lifetime + 0.15).timeout
	queue_free()
