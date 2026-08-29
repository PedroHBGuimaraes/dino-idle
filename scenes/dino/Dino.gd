extends TextureRect

## Visual de uma espécie: sprite pixel art (64x64, gerado via PixelLab MCP,
## ver docs/assets-prompts.md) trocado dinamicamente por espécie/nível — o
## sprite muda de faixa (Filhote/Jovem/Adulto) conforme
## DinoSpeciesData.stage_for_level, mas o nível em si (número) é mostrado
## pelo DinoCard, não aqui.
##
## Tem uma animação de "respiração" contínua e sutil (escala oscilando) —
## roda pra sempre, independente de espécie/nível/silhueta, já que só mexe
## em `scale`, nunca em `texture`/`modulate`. O "brilho lendário" (nível
## máximo) usa `self_modulate` em vez de `modulate` de propósito: quem
## controla `modulate` é o DinoCard (silhueta de bloqueado vs revelado) —
## os dois canais são independentes, então não brigam entre si.
##
## Espécies sem sprite ainda (arte real é gerada depois, espécie por
## espécie) caem num placeholder gerado na hora: um círculo colorido
## (placeholder_color da espécie), crescendo de tamanho por faixa de
## estágio — mesma ideia dos placeholders do início do projeto, antes da
## arte pixel art existir.
##
## No estágio Adulto, se existir uma animação de idle pra essa espécie
## (assets/dino/idle/dino_<id>_idle_0..4.png — 5 frames derivados do
## próprio sprite Adulto), ela substitui a textura estática por um
## AnimatedTexture (o próprio motor cicla os frames sozinho, sem precisar
## de Timer/script tocando isso a cada frame). A "respiração" de escala
## continua rodando em cima de qualquer uma das duas — são canais
## independentes (escala vs. textura), então não conflitam.

const ART_DIR := "res://assets/dino/"
const IDLE_ANIMATION_DIR := "res://assets/dino/idle/"
const IDLE_ANIMATION_FRAME_COUNT := 5
const IDLE_ANIMATION_FRAME_DURATION := 0.15
const IDLE_SCALE_X := 1.05
const IDLE_SCALE_Y := 0.95
const LEGENDARY_GLOW_COLOR := Color(1.5, 1.25, 0.6, 1.0)
const PLACEHOLDER_SIZE := 64
const PLACEHOLDER_STAGE_SCALE := [0.5, 0.72, 1.0]

## "Pop" de crescimento no level up — bem mais forte numa transição de
## estágio visual (Filhote→Jovem→Adulto, os momentos mais marcantes) do
## que num level up comum dentro da mesma faixa (ver play_growth_effect).
const GROWTH_POP_SCALE_STAGE := 1.45
const GROWTH_POP_SCALE_LEVEL := 1.15
const GROWTH_FLASH_COLOR := Color(1.9, 1.85, 1.4, 1.0)
const GROWTH_POP_DURATION := 0.14
const GROWTH_SETTLE_DURATION := 0.4
const GROWTH_FLASH_FADE_DURATION := 0.3

## Reação ao TOCAR o dino diretamente na lista (não a ação de
## desbloquear/upar) — um pulinho + guinada, aproximando "pular, virar a
## cabeça" sem precisar de arte de animação dedicada (não temos frames de
## cabeça-virando; a rotação sutil finge esse movimento).
const TAP_HOP_HEIGHT := 8.0
const TAP_HOP_UP_DURATION := 0.09
const TAP_HOP_DOWN_DURATION := 0.22
const TAP_WOBBLE_DEGREES := 10.0

## Intervalo (sorteado de novo a cada ciclo) entre "twitches" espontâneos —
## sem precisar de toque nenhum. Faixa larga e re-sorteada de propósito, pra
## vários dinos da lista não caírem em sincronia uns com os outros.
const IDLE_FIDGET_MIN_INTERVAL := 5.0
const IDLE_FIDGET_MAX_INTERVAL := 12.0

var _species_id: StringName
var _is_legendary := false
var _legendary_tween: Tween
var _breathing_tween: Tween
var _growth_tween: Tween
var _reaction_tween: Tween


func _ready() -> void:
	_start_idle_animation()
	_run_idle_fidget_loop()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		play_tap_reaction()
	elif event is InputEventScreenTouch and event.pressed:
		play_tap_reaction()


func setup(data: DinoSpeciesData, level: int) -> void:
	_species_id = data.id
	set_level(data, level)


func set_level(data: DinoSpeciesData, level: int) -> void:
	var stage := data.stage_for_level(level)
	var stage_name: String = String(DinoSpeciesData.STAGE_NAMES[stage]).to_lower()
	var path := "%sdino_%s_%s.png" % [ART_DIR, _species_id, stage_name]

	var idle_animation: AnimatedTexture = null
	if stage == DinoSpeciesData.Stage.ADULTO:
		idle_animation = _build_idle_animation()

	if idle_animation:
		texture = idle_animation
	elif ResourceLoader.exists(path):
		texture = load(path)
	else:
		texture = _build_placeholder_texture(data.placeholder_color, stage)

	set_legendary(data.is_max_level(level))


## Monta o AnimatedTexture de idle desta espécie, se os 5 frames existirem
## em IDLE_ANIMATION_DIR. Retorna null se faltar qualquer frame (nesse caso
## set_level() cai de volta pro sprite estático/placeholder).
func _build_idle_animation() -> AnimatedTexture:
	var frame_paths: Array[String] = []
	for i in IDLE_ANIMATION_FRAME_COUNT:
		var frame_path := "%sdino_%s_idle_%d.png" % [IDLE_ANIMATION_DIR, _species_id, i]
		if not ResourceLoader.exists(frame_path):
			return null
		frame_paths.append(frame_path)

	var animation := AnimatedTexture.new()
	animation.frames = IDLE_ANIMATION_FRAME_COUNT
	for i in IDLE_ANIMATION_FRAME_COUNT:
		animation.set_frame_texture(i, load(frame_paths[i]))
		animation.set_frame_duration(i, IDLE_ANIMATION_FRAME_DURATION)
	return animation


func _build_placeholder_texture(color: Color, stage: int) -> ImageTexture:
	var image := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	var radius: float = (PLACEHOLDER_SIZE / 2.0) * float(PLACEHOLDER_STAGE_SCALE[stage])
	var center := Vector2(PLACEHOLDER_SIZE / 2.0, PLACEHOLDER_SIZE / 2.0)
	for y in PLACEHOLDER_SIZE:
		for x in PLACEHOLDER_SIZE:
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## Liga/desliga o brilho pulsante dourado que marca uma espécie no nível
## máximo (100) — "completo/lendário", pedido explicitamente no design da
## passiva de nível 100.
func set_legendary(active: bool) -> void:
	if active == _is_legendary:
		return
	_is_legendary = active

	if _legendary_tween and _legendary_tween.is_valid():
		_legendary_tween.kill()

	if not active:
		self_modulate = Color(1, 1, 1, 1)
		return

	_legendary_tween = create_tween().set_loops()
	(
		_legendary_tween
		. tween_property(self, "self_modulate", LEGENDARY_GLOW_COLOR, 0.7)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_legendary_tween
		. tween_property(self, "self_modulate", Color(1, 1, 1, 1), 0.7)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _start_idle_animation() -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()

	# Duração levemente aleatória por instância pra várias dino-cards não
	# "respirarem" perfeitamente em sincronia.
	var half_duration := randf_range(0.85, 1.15)

	_breathing_tween = create_tween().set_loops()
	(
		_breathing_tween
		. tween_property(self, "scale", Vector2(IDLE_SCALE_X, IDLE_SCALE_Y), half_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_breathing_tween
		. tween_property(self, "scale", Vector2.ONE, half_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Efeito de "crescimento" tocado pelo DinoCard num level up bem-sucedido —
## chamar DEPOIS que o sprite/textura já foi atualizado pro novo nível (ver
## DinoCard._refresh(), disparado sincronamente por
## GameManager.dino_state_changed), pra o pop de escala já revelar a forma
## nova. `is_stage_transition` (Filhote→Jovem ou Jovem→Adulto) usa um pop
## maior + flash de luz; um level up comum dentro da mesma faixa só faz o
## pop, mais sutil, sem flash — senão o efeito vira ruído em runs de vários
## levels seguidos.
##
## Pausa a respiração e o brilho lendário durante o efeito (os 3 mexem em
## scale/self_modulate) e os retoma no fim, sem perder o estado de cada um.
func play_growth_effect(is_stage_transition: bool) -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()

	var was_legendary := _is_legendary
	if _legendary_tween and _legendary_tween.is_valid():
		_legendary_tween.kill()
	_is_legendary = false

	if _growth_tween and _growth_tween.is_valid():
		_growth_tween.kill()
	if _reaction_tween and _reaction_tween.is_valid():
		_reaction_tween.kill()

	scale = Vector2.ONE
	rotation = 0.0
	self_modulate = Color(1, 1, 1, 1)

	var pop_scale := GROWTH_POP_SCALE_STAGE if is_stage_transition else GROWTH_POP_SCALE_LEVEL

	_growth_tween = create_tween()
	_growth_tween.set_parallel(true)
	(
		_growth_tween
		. tween_property(self, "scale", Vector2(pop_scale, pop_scale * 0.82), GROWTH_POP_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	if is_stage_transition:
		(
			_growth_tween
			. tween_property(self, "self_modulate", GROWTH_FLASH_COLOR, GROWTH_POP_DURATION)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	_growth_tween.chain()
	(
		_growth_tween
		. tween_property(self, "scale", Vector2.ONE, GROWTH_SETTLE_DURATION)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	if is_stage_transition:
		(
			_growth_tween
			. tween_property(self, "self_modulate", Color(1, 1, 1, 1), GROWTH_FLASH_FADE_DURATION)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN)
		)
	_growth_tween.chain()
	_growth_tween.tween_callback(_start_idle_animation)
	_growth_tween.tween_callback(set_legendary.bind(was_legendary))


## Reação decorativa ao tocar o dino diretamente (ver _gui_input) — mesmo
## pulinho+giro de _play_hop_wobble(), mas com som (só o toque de verdade
## merece som; o twitch espontâneo de _play_idle_fidget() é silencioso, senão
## vira uma cacofonia de "poke" a cada poucos segundos com vários dinos
## desbloqueados na lista).
func play_tap_reaction() -> void:
	AudioManager.play_poke()
	_play_hop_wobble()


## Pulinho rápido com leve giro na aterrissagem, tipo "susto/curiosidade" —
## a ANIMAÇÃO em si, sem som (ver play_tap_reaction, que adiciona o som pro
## toque de verdade, e _play_idle_fidget, que chama isso sozinho, sem som).
## Não desbloqueia nem sobe nível nenhum, é só flavor. Interrompe/retoma a
## respiração como os outros efeitos; cede passagem também pra
## play_growth_effect se os dois colidirem (raro, mas possível se o
## jogador tocar o sprite bem na hora de um level up).
func _play_hop_wobble() -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()
	if _growth_tween and _growth_tween.is_valid():
		_growth_tween.kill()
	if _reaction_tween and _reaction_tween.is_valid():
		_reaction_tween.kill()

	scale = Vector2.ONE
	rotation = 0.0
	var base_y := position.y

	_reaction_tween = create_tween()
	(
		_reaction_tween
		. tween_property(self, "position:y", base_y - TAP_HOP_HEIGHT, TAP_HOP_UP_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_reaction_tween
		. tween_property(self, "position:y", base_y, TAP_HOP_DOWN_DURATION)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_reaction_tween
		. parallel()
		. tween_property(
			self, "rotation", deg_to_rad(TAP_WOBBLE_DEGREES), TAP_HOP_DOWN_DURATION * 0.5
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_reaction_tween
		. tween_property(self, "rotation", 0.0, TAP_HOP_DOWN_DURATION * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_reaction_tween.tween_callback(_start_idle_animation)


## Twitch espontâneo periódico (sem precisar de toque) — dá vida autônoma
## pra TODO estágio (inclusive Filhote/Jovem, que hoje só tinham a
## respiração) e também pra dinos ainda bloqueados (silhueta): reforça a
## ideia de "tem algo esperando ali" que o DinoCard já descreve pra
## silhueta, sem precisar que ninguém de fora avise este nó se está
## bloqueado ou não. Roda pra sempre (o nó nunca é destruído durante uma
## sessão normal — ShopPanel monta os cards uma vez só).
func _run_idle_fidget_loop() -> void:
	while true:
		await (
			get_tree()
			. create_timer(randf_range(IDLE_FIDGET_MIN_INTERVAL, IDLE_FIDGET_MAX_INTERVAL))
			. timeout
		)
		if not is_inside_tree():
			return
		_play_idle_fidget()


## Só dispara se nada mais importante estiver rolando agora (level up ou uma
## reação de toque de verdade) — o twitch espontâneo nunca deve interromper
## essas duas.
func _play_idle_fidget() -> void:
	if _growth_tween and _growth_tween.is_valid():
		return
	if _reaction_tween and _reaction_tween.is_valid():
		return
	_play_hop_wobble()
