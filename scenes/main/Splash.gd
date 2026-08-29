extends Control

## Tela de abertura mostrada sempre que o app é aberto, antes da tela
## principal carregar — evita a transição abrupta pra tela preta padrão do
## Godot. Ver também `application/boot_splash/*` em project.godot pro
## instante inicial antes até desta cena rodar (o "flash preto" real do
## engine, que nenhuma cena consegue cobrir).
##
## Main.tscn é bem pesado pra instanciar (HUD, todos os popups, e o
## ShopPanel monta um DinoCard por espécie cadastrada) — trocar de cena com
## `change_scene_to_file()` primeiro LIBERA a Splash e só depois carrega e
## instancia o Main, então por um instante nada é desenhado (a tela cinza
## que sobra é o clear color padrão do viewport). Em vez disso, carregamos
## Main.tscn em background (ResourceLoader threaded) com a Splash inteira
## ainda na tela, e só instanciamos/trocamos quando ele já estiver pronto —
## a Splash fica por cima até o fade final, então em nenhum momento fica
## vazio.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const FADE_IN_DURATION := 0.25
const MIN_HOLD_DURATION := 0.6
const FADE_OUT_DURATION := 0.4

@onready var _content: Control = %Content

var _hold_elapsed := 0.0
var _min_hold_reached := false
var _main_scene: PackedScene


func _ready() -> void:
	modulate.a = 1.0
	_content.modulate.a = 0.0

	# Começa a carregar Main.tscn em paralelo com o fade-in, pra aproveitar
	# a splash inteira como tempo de carregamento (não só o HOLD depois).
	ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)
	set_process(true)

	var tween := create_tween()
	tween.tween_property(_content, "modulate:a", 1.0, FADE_IN_DURATION)


func _process(delta: float) -> void:
	_hold_elapsed += delta
	_min_hold_reached = _hold_elapsed >= MIN_HOLD_DURATION

	if _main_scene == null:
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_main_scene = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Splash: falha ao carregar %s em background" % MAIN_SCENE_PATH)
				_main_scene = load(MAIN_SCENE_PATH)  # fallback síncrono, melhor que travar aqui

	# Espera os dois: nunca corta a splash antes do tempo mínimo (mesmo se o
	# carregamento for instantâneo), e nunca troca antes do Main estar
	# pronto de verdade (mesmo se demorar mais que o mínimo).
	if _main_scene != null and _min_hold_reached:
		set_process(false)
		_go_to_main()


func _go_to_main() -> void:
	var main := _main_scene.instantiate()
	get_tree().root.add_child(main)
	# A Splash continua por cima (é o último filho == desenhado por último)
	# até terminar de sumir, revelando o Main já pronto por trás em vez de
	# cortar direto pra ele.
	get_tree().root.move_child(self, get_tree().root.get_child_count() - 1)
	get_tree().current_scene = main

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(queue_free)
