extends Node

## Autoload. Carrega todas as DinoSpeciesData de res://data/species/ na
## inicialização e expõe lookups por id e a lista ordenada por custo base.

const SPECIES_DIR := "res://data/species/"

var _by_id: Dictionary = {}  # StringName -> DinoSpeciesData
var _ordered: Array[DinoSpeciesData] = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir := DirAccess.open(SPECIES_DIR)
	if dir == null:
		push_error("SpeciesDatabase: não consegui abrir %s" % SPECIES_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Builds exportados convertem .tres para binário e o listing
			# devolve "nome.tres.remap" em vez de "nome.tres" — sem isso
			# nenhuma espécie é encontrada fora do editor.
			var clean_name := file_name
			if clean_name.ends_with(".remap"):
				clean_name = clean_name.substr(0, clean_name.length() - ".remap".length())
			if clean_name.ends_with(".tres"):
				var res := load(SPECIES_DIR + clean_name)
				if res is DinoSpeciesData:
					_by_id[res.id] = res
					_ordered.append(res)
				else:
					push_warning("SpeciesDatabase: %s não é um DinoSpeciesData" % clean_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	_ordered.sort_custom(
		func(a: DinoSpeciesData, b: DinoSpeciesData) -> bool: return a.unlock_cost < b.unlock_cost
	)


func get_all() -> Array[DinoSpeciesData]:
	return _ordered


func get_by_id(id: StringName) -> DinoSpeciesData:
	return _by_id.get(id)


func has_id(id: StringName) -> bool:
	return _by_id.has(id)
