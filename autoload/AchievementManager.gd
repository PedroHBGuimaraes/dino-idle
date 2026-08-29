extends Node

## Autoload. Dono do sistema de conquistas: define a lista (código, não
## .tres — a CONDIÇÃO de cada uma é lógica de jogo, não dado estático),
## rastreia as estatísticas ao longo da vida da conta que as espécies não
## guardam sozinhas (toques totais, comida total ganha, streak de dias
## jogados) e avalia tudo de novo a cada mudança relevante de estado.
##
## Progresso é sempre monotônico (uma conquista nunca é perdida), então
## _evaluate_all() só precisa checar as ainda NÃO desbloqueadas — uma vez
## que as 12 estiverem desbloqueadas, vira só uma varredura de dicionário.

signal achievement_unlocked(achievement: AchievementData)

const DAY_SECONDS := 86400.0

var total_taps: int = 0
var total_food_earned: float = 0.0
var play_streak_days: int = 0

var _last_played_day: int = -1
var _unlocked_ids: Dictionary = {}  # StringName -> true
var _achievements: Array[AchievementData] = []
var _checks: Dictionary = {}  # StringName -> Callable


func _ready() -> void:
	_build_achievements()
	GameManager.food_changed.connect(_on_food_changed)
	GameManager.dino_state_changed.connect(_on_dino_state_changed)
	GameManager.food_earned.connect(_on_food_earned)
	GameManager.tapped.connect(_on_tapped)


func get_all_achievements() -> Array[AchievementData]:
	return _achievements


func is_unlocked(id: StringName) -> bool:
	return _unlocked_ids.has(id)


func get_unlocked_count() -> int:
	return _unlocked_ids.size()


## Chamado pelo Main.gd uma vez por sessão, depois que SaveManager.load_game()
## já aplicou o streak salvo — atualiza o streak de dias jogados
## consecutivos. Compara por "dia desde a epoch" (unix // 86400), não por
## calendário/fuso exato — simples o bastante pro que a conquista pede.
func register_daily_visit() -> void:
	var today := int(Time.get_unix_time_from_system() / DAY_SECONDS)
	if _last_played_day == -1:
		play_streak_days = 1
	elif today == _last_played_day:
		pass  # já contabilizado hoje
	elif today == _last_played_day + 1:
		play_streak_days += 1
	else:
		play_streak_days = 1
	_last_played_day = today
	_evaluate_all()


## Snapshot serializável pro SaveManager.
func get_save_state() -> Dictionary:
	var unlocked_list: Array = []
	for id: StringName in _unlocked_ids:
		unlocked_list.append(String(id))
	return {
		"unlocked": unlocked_list,
		"total_taps": total_taps,
		"total_food_earned": total_food_earned,
		"play_streak_days": play_streak_days,
		"last_played_day": _last_played_day,
	}


func load_state(data: Dictionary) -> void:
	_unlocked_ids.clear()
	for id_str in data.get("unlocked", []):
		_unlocked_ids[StringName(id_str)] = true
	total_taps = int(data.get("total_taps", 0))
	total_food_earned = float(data.get("total_food_earned", 0.0))
	play_streak_days = int(data.get("play_streak_days", 0))
	_last_played_day = int(data.get("last_played_day", -1))
	_evaluate_all()


func _on_food_changed(_new_amount: float) -> void:
	_evaluate_all()


func _on_dino_state_changed(_species_id: StringName, _unlocked: bool, _level: int) -> void:
	_evaluate_all()


func _on_food_earned(amount: float) -> void:
	total_food_earned += amount
	_evaluate_all()


func _on_tapped(_amount: float) -> void:
	total_taps += 1
	_evaluate_all()


func _evaluate_all() -> void:
	for achievement: AchievementData in _achievements:
		if _unlocked_ids.has(achievement.id):
			continue
		var check: Callable = _checks[achievement.id]
		if check.call():
			_unlocked_ids[achievement.id] = true
			achievement_unlocked.emit(achievement)


## Nome/descrição de cada conquista vêm da tradução (chaves derivadas do id:
## &"first_unlock" -> ACH_FIRST_UNLOCK_NAME / ACH_FIRST_UNLOCK_DESC). O último
## argumento opcional é a quantidade que a descrição interpola ({amount}) —
## só as conquistas de produção/toque/comida usam; nas demais a descrição é
## texto fixo.
func _build_achievements() -> void:
	_add(&"first_unlock", "ach_first_unlock.png", _check_first_unlock)
	_add(&"first_max_level", "ach_first_max_level.png", _check_first_max_level)
	_add(&"full_family", "ach_full_family.png", _check_full_family)
	_add(&"collection_complete", "ach_collection_complete.png", _check_collection_complete)
	_add(&"production_1k", "ach_production_1k.png", _check_production_1k, 1_000.0)
	_add(&"production_1m", "ach_production_1m.png", _check_production_1m, 1_000_000.0)
	_add(&"production_1b", "ach_production_1b.png", _check_production_1b, 1_000_000_000.0)
	_add(&"taps_1000", "ach_taps_1000.png", _check_taps_1000, 1_000.0)
	_add(&"taps_10000", "ach_taps_10000.png", _check_taps_10000, 10_000.0)
	_add(&"streak_3", "ach_streak_3.png", _check_streak_3)
	_add(&"streak_7", "ach_streak_7.png", _check_streak_7)
	_add(&"food_lifetime_1m", "ach_food_lifetime_1m.png", _check_food_lifetime_1m, 1_000_000.0)


func _add(
	id: StringName, icon_filename: String, check: Callable, desc_amount: float = -1.0
) -> void:
	_achievements.append(AchievementData.new(id, icon_filename, desc_amount))
	_checks[id] = check


func _check_first_unlock() -> bool:
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not species.starts_unlocked and GameManager.is_unlocked(species.id):
			return true
	return false


func _check_first_max_level() -> bool:
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if (
			GameManager.is_unlocked(species.id)
			and species.is_max_level(GameManager.get_level(species.id))
		):
			return true
	return false


func _check_full_family() -> bool:
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not GameManager.is_unlocked(species.id):
			return false
	return true


func _check_collection_complete() -> bool:
	return GameManager.is_collection_complete()


func _check_production_1k() -> bool:
	return GameManager.get_total_production_per_second() >= 1000.0


func _check_production_1m() -> bool:
	return GameManager.get_total_production_per_second() >= 1000000.0


func _check_production_1b() -> bool:
	return GameManager.get_total_production_per_second() >= 1000000000.0


func _check_taps_1000() -> bool:
	return total_taps >= 1000


func _check_taps_10000() -> bool:
	return total_taps >= 10000


func _check_streak_3() -> bool:
	return play_streak_days >= 3


func _check_streak_7() -> bool:
	return play_streak_days >= 7


func _check_food_lifetime_1m() -> bool:
	return total_food_earned >= 1000000.0
