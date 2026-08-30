extends Node

## Autoload. Persiste o progresso em user://savegame.json (JSON puro, não
## binário — mais seguro que salvar Resources e fácil de inspecionar/migrar)
## e calcula produção offline ao carregar.
##
## load_game() deve ser chamado explicitamente pela cena principal (Main.gd)
## depois que a UI já estiver na árvore e conectada aos sinais do
## GameManager, para que o refresh de estado carregado chegue na tela.

signal offline_earnings_ready(amount: float, offline_seconds: float)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL_SEC := 30.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0  # teto de 8h de produção offline
## Abaixo disto não vale mostrar o popup de "bem-vindo de volta" — fechar e
## reabrir o app rápido não deveria disparar uma tela de "você ganhou X em
## 0 min". A comida do intervalo curto ainda é creditada, sem popup.
const MIN_OFFLINE_POPUP_SECONDS := 120.0

## Mobile pode matar o app sem aviso — salva em qualquer sinal de perda de foco/saída.
const _SAVE_TRIGGER_NOTIFICATIONS := [
	NOTIFICATION_WM_CLOSE_REQUEST,
	NOTIFICATION_APPLICATION_PAUSED,
	NOTIFICATION_APPLICATION_FOCUS_OUT,
]

## Falso até o jogador terminar ou pular o tutorial de onboarding (Main.gd
## só o mostra quando isso for falso). Ausente no save = jogador novo.
var tutorial_completed: bool = false

var _autosave_timer: Timer


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)


func _notification(what: int) -> void:
	if what in _SAVE_TRIGGER_NOTIFICATIONS:
		save_game()


func save_game() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"food": GameManager.food,
		"last_save_unix": Time.get_unix_time_from_system(),
		"species": GameManager.get_save_species_state(),
		"production_boost_multiplier": GameManager.production_boost_multiplier,
		"production_boost_expires_unix": GameManager.production_boost_expires_unix,
		"audio_muted": AudioManager.muted,
		"audio_music_volume": AudioManager.music_volume,
		"audio_sfx_volume": AudioManager.sfx_volume,
		"language": LocaleManager.language,
		"tutorial_completed": tutorial_completed,
		"achievements": AchievementManager.get_save_state(),
		"prestige": PrestigeManager.get_save_state(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error(
			(
				"SaveManager: falha ao abrir %s para escrita (erro %d)"
				% [SAVE_PATH, FileAccess.get_open_error()]
			)
		)
		return
	file.store_string(JSON.stringify(payload))
	file.close()


## Carrega o save (se existir), aplica ao GameManager e calcula/aplica
## produção offline. Emite offline_earnings_ready só quando há ganho > 0.
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		# Jogador novo, sem save ainda — mesmo assim conta como "dia 1" de
		# streak (register_daily_visit trata _last_played_day == -1 como
		# primeira visita) em vez de só começar a contar na PRÓXIMA sessão.
		AchievementManager.register_daily_visit()
		# Grava o save já com o idioma detectado no boot (LocaleManager._ready),
		# pra cumprir "salvo na primeira vez que o app abre" mesmo se a sessão
		# durar menos que o intervalo do autosave.
		save_game()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error(
			(
				"SaveManager: falha ao abrir %s para leitura (erro %d)"
				% [SAVE_PATH, FileAccess.get_open_error()]
			)
		)
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: savegame corrompido, ignorando.")
		return

	var data: Dictionary = parsed
	var saved_food: float = float(data.get("food", 0.0))
	var saved_species: Dictionary = data.get("species", {})
	var last_save_unix: float = float(data.get("last_save_unix", Time.get_unix_time_from_system()))
	var saved_boost_multiplier: float = float(data.get("production_boost_multiplier", 1.0))
	var saved_boost_expires_unix: float = float(data.get("production_boost_expires_unix", 0.0))

	GameManager.load_state(
		saved_food, saved_species, saved_boost_multiplier, saved_boost_expires_unix
	)

	AudioManager.load_prefs(
		bool(data.get("audio_muted", false)),
		float(data.get("audio_music_volume", AudioManager.music_volume)),
		float(data.get("audio_sfx_volume", AudioManager.sfx_volume))
	)

	tutorial_completed = bool(data.get("tutorial_completed", false))

	# Save pré-i18n (ou sem a chave): LocaleManager mantém o idioma detectado
	# no boot; persiste ao final de load_game (aqui NÃO — os load_state de
	# achievement/prestige ainda não rodaram, e save_game os incluiria vazios).
	var persist_language := LocaleManager.load_prefs(str(data.get("language", "")))

	AchievementManager.load_state(data.get("achievements", {}))
	AchievementManager.register_daily_visit()
	PrestigeManager.load_state(data.get("prestige", {}))

	var elapsed: float = float(Time.get_unix_time_from_system() - last_save_unix)
	elapsed = clampf(elapsed, 0.0, MAX_OFFLINE_SECONDS)

	if elapsed > 0.0:
		# Usa a produção BASE (sem o buff de anúncio) de propósito: um buff
		# temporário de 30min não deve "reviver" e valer pelas horas inteiras
		# em que o app ficou fechado — senão dá pra explorar isso ativando o
		# buff e fechando o app logo em seguida.
		var rate := GameManager.get_base_production_per_second()
		var offline_food := rate * elapsed
		if offline_food > 0.0:
			GameManager.add_food(offline_food)
			if elapsed >= MIN_OFFLINE_POPUP_SECONDS:
				offline_earnings_ready.emit(offline_food, elapsed)

	# Agora todo o estado já foi carregado — seguro regravar pra fixar o
	# idioma detectado num save que ainda não o tinha.
	if persist_language:
		save_game()


## Chamado pelo OnboardingOverlay ao terminar (ou ser pulado). Salva na hora
## pra não repetir o tutorial se o app fechar antes do próximo autosave.
func mark_tutorial_completed() -> void:
	tutorial_completed = true
	save_game()
