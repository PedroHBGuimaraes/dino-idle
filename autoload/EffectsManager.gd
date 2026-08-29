extends Node

## Autoload. Ponto único pra disparar feedback visual efêmero ("juice") de
## qualquer lugar do jogo — números flutuantes e partículas de recompensa —
## sem precisar passar referência de nó entre cenas. Mantém sua própria
## CanvasLayer, sempre por cima do resto da UI.

const FloatingNumberScene := preload("res://scenes/effects/FloatingNumber.tscn")
const RewardBurstScene := preload("res://scenes/effects/RewardBurst.tscn")
const MilestoneBurstScene := preload("res://scenes/effects/MilestoneBurst.tscn")
const MilestoneTextScene := preload("res://scenes/effects/MilestoneText.tscn")

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)


## `global_pos` é posição em coordenadas de viewport (ex.: `get_global_mouse_position()`
## ou `algum_control.global_position`).
func spawn_floating_number(text: String, global_pos: Vector2) -> void:
	var label := FloatingNumberScene.instantiate()
	# setup() TEM que rodar antes de entrar na árvore: FloatingNumber._ready()
	# já usa `text`/a posição pra se posicionar, e add_child() dispara
	# _ready() na hora — se setup() viesse depois, _ready() calcularia a
	# posição em cima do texto/posição padrão do .tscn (canto 0,0), não do
	# ponto real do toque.
	label.setup(text, global_pos)
	_layer.add_child(label)


func spawn_reward_burst(global_pos: Vector2) -> void:
	var burst := RewardBurstScene.instantiate()
	_layer.add_child(burst)
	burst.global_position = global_pos


## Celebração leve (confete + texto subindo) pro marco de um dino individual
## alcançar o nível 100 pela primeira vez — não interrompe o jogo (sem dim
## de tela, sem popup), só mais chamativa que spawn_reward_burst pra marcar
## o momento. Texto propositalmente curto (sem o nome da espécie, que já
## está óbvio pela posição — o card dela está bem ali) pra caber em telas
## estreitas sem estourar a largura. Ver DinoCard._on_action_pressed().
func spawn_milestone_celebration(global_pos: Vector2) -> void:
	var burst := MilestoneBurstScene.instantiate()
	_layer.add_child(burst)
	burst.global_position = global_pos

	var label := MilestoneTextScene.instantiate()
	# Mesmo motivo do spawn_floating_number: setup() antes de add_child().
	label.setup(Loc.t("MILESTONE_MAX_LEVEL"), global_pos)
	_layer.add_child(label)
