extends Node

## Autoload. Sistema de prestígio: dá um objetivo de longuíssimo prazo depois
## que a coleção já está bem avançada, deixando o jogador resetar o progresso
## da run (nível/comida — ver GameManager.reset_for_prestige) em troca de
## Fósseis Ancestrais, uma moeda PERMANENTE que sobrevive ao reset e compra
## multiplicadores permanentes de produção/toque.
##
## Estado independente do GameManager de propósito — reset_for_prestige()
## nunca toca em `fossils`/`_upgrade_levels`/`prestige_count`, e o SaveManager
## persiste os dois lados juntos no mesmo user://savegame.json (chave
## "prestige"), sem precisar de um arquivo separado.

const UPGRADES_DIR := "res://data/prestige/"

## Progresso mínimo de coleção (ver GameManager.get_collection_progress) pra
## habilitar o PRIMEIRO prestígio. Depois do primeiro, o botão nunca mais
## some (ver is_unlocked) — só esse piso inicial usa essa constante.
const PRESTIGE_MIN_PROGRESS := 0.5

## Fósseis ganhos = FOSSILS_PER_LEVEL_SUM * soma dos níveis de toda espécie
## DESBLOQUEADA (bloqueada não conta). Ver dino-idle-game-plano.md pros
## números de referência (50% de progresso ≈ 75-85 Fósseis).
const FOSSILS_PER_LEVEL_SUM := 0.05

signal fossils_changed(new_amount: float)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
## Emitido depois que o reset já aconteceu — `fossils_earned` é quanto essa
## run específica rendeu (não o saldo total, que já está refletido em
## fossils_changed).
signal prestige_performed(fossils_earned: float)

var fossils: float = 0.0
var prestige_count: int = 0

var _upgrade_levels: Dictionary = {}  # StringName -> int
var _by_id: Dictionary = {}  # StringName -> PrestigeUpgradeData
var _ordered: Array[PrestigeUpgradeData] = []


func _ready() -> void:
	_load_upgrade_definitions()


func _load_upgrade_definitions() -> void:
	var dir := DirAccess.open(UPGRADES_DIR)
	if dir == null:
		push_error("PrestigeManager: não consegui abrir %s" % UPGRADES_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Mesmo cuidado do SpeciesDatabase: build exportado converte .tres
			# pra binário e o listing devolve "nome.tres.remap" em vez de
			# "nome.tres" — sem isso nenhum upgrade seria encontrado fora do
			# Editor.
			var clean_name := file_name
			if clean_name.ends_with(".remap"):
				clean_name = clean_name.substr(0, clean_name.length() - ".remap".length())
			if clean_name.ends_with(".tres"):
				var res := load(UPGRADES_DIR + clean_name)
				if res is PrestigeUpgradeData:
					_by_id[res.id] = res
					_ordered.append(res)
					if not _upgrade_levels.has(res.id):
						_upgrade_levels[res.id] = 0
				else:
					push_warning("PrestigeManager: %s não é um PrestigeUpgradeData" % clean_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	_ordered.sort_custom(
		func(a: PrestigeUpgradeData, b: PrestigeUpgradeData) -> bool:
			return a.base_cost < b.base_cost
	)


func get_all_upgrades() -> Array[PrestigeUpgradeData]:
	return _ordered


func get_upgrade_level(upgrade_id: StringName) -> int:
	return _upgrade_levels.get(upgrade_id, 0)


## 1.0 + soma dos bônus de todo upgrade com target PRODUCTION já comprado.
func get_production_multiplier() -> float:
	return 1.0 + _sum_bonus_for_target(PrestigeUpgradeData.Target.PRODUCTION)


## 1.0 + soma dos bônus de todo upgrade com target TAP já comprado.
func get_tap_multiplier() -> float:
	return 1.0 + _sum_bonus_for_target(PrestigeUpgradeData.Target.TAP)


func _sum_bonus_for_target(target: PrestigeUpgradeData.Target) -> float:
	var total := 0.0
	for upgrade: PrestigeUpgradeData in _ordered:
		if upgrade.target == target:
			total += upgrade.bonus_for_level(get_upgrade_level(upgrade.id))
	return total


func cost_for_next_level(upgrade_id: StringName) -> float:
	var upgrade: PrestigeUpgradeData = _by_id.get(upgrade_id)
	if upgrade == null:
		return -1.0
	return upgrade.cost_for_level(get_upgrade_level(upgrade_id))


func can_afford(upgrade_id: StringName) -> bool:
	var cost := cost_for_next_level(upgrade_id)
	return cost >= 0.0 and fossils >= cost


func buy_upgrade(upgrade_id: StringName) -> bool:
	if not can_afford(upgrade_id):
		return false
	var cost := cost_for_next_level(upgrade_id)
	fossils -= cost
	var new_level: int = get_upgrade_level(upgrade_id) + 1
	_upgrade_levels[upgrade_id] = new_level

	fossils_changed.emit(fossils)
	upgrade_purchased.emit(upgrade_id, new_level)
	return true


## Coleção precisa estar em PRESTIGE_MIN_PROGRESS ou mais pra habilitar o
## PRIMEIRO prestígio (ver is_unlocked pra depois do primeiro).
func can_prestige() -> bool:
	return GameManager.get_collection_progress() >= PRESTIGE_MIN_PROGRESS


## Se o botão de prestígio deve aparecer na UI — true a partir do momento em
## que o jogador já prestigiou ao menos uma vez, mesmo que o progresso da run
## ATUAL tenha caído de novo abaixo de PRESTIGE_MIN_PROGRESS logo depois do
## reset. Sem isso o botão sumiria pro jogador exatamente depois de usá-lo.
func is_unlocked() -> bool:
	return prestige_count > 0 or can_prestige()


## Quantos Fósseis a run atual renderia se prestigiada agora — não muda
## nenhum estado, só pra UI mostrar antes do jogador confirmar.
func preview_fossils_gain() -> float:
	var level_sum := 0
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if GameManager.is_unlocked(species.id):
			level_sum += GameManager.get_level(species.id)
	return floorf(FOSSILS_PER_LEVEL_SUM * float(level_sum))


## Concede os Fósseis desta run e reseta o progresso (GameManager.food/nível/
## desbloqueios) — irreversível. Não mexe em conquistas (permanentes por
## design) nem no próprio saldo/upgrades de prestígio já comprados.
func perform_prestige() -> bool:
	if not can_prestige():
		return false

	var earned := preview_fossils_gain()
	fossils += earned
	prestige_count += 1

	GameManager.reset_for_prestige()

	fossils_changed.emit(fossils)
	prestige_performed.emit(earned)
	return true


func get_save_state() -> Dictionary:
	var levels := {}
	for id: StringName in _upgrade_levels:
		levels[String(id)] = _upgrade_levels[id]
	return {
		"fossils": fossils,
		"prestige_count": prestige_count,
		"upgrade_levels": levels,
	}


func load_state(data: Dictionary) -> void:
	fossils = float(data.get("fossils", 0.0))
	prestige_count = int(data.get("prestige_count", 0))

	var saved_levels: Dictionary = data.get("upgrade_levels", {})
	for upgrade: PrestigeUpgradeData in _ordered:
		var raw: int = int(saved_levels.get(String(upgrade.id), 0))
		_upgrade_levels[upgrade.id] = clampi(raw, 0, upgrade.max_level)

	fossils_changed.emit(fossils)
