extends Control

## Lista rolável com um DinoCard por espécie cadastrada no SpeciesDatabase.
## Um degradê no rodapé (%BottomFade) sinaliza que há mais itens pra rolar,
## e some quando o scroll já chegou no fim. Também emite `scrolled` com a
## posição normalizada (0..1) pro fundo da tela reagir com parallax.

signal scrolled(ratio: float)
## Repassado de cada DinoCard.info_requested — ver SpeciesDetailPopup.
signal species_info_requested(species: DinoSpeciesData)

const DinoCardScene := preload("res://scenes/ui/DinoCard.tscn")

@onready var _list: VBoxContainer = %List
@onready var _scroll: ScrollContainer = %Scroll
@onready var _bottom_fade: Control = %BottomFade


func _ready() -> void:
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		var card := DinoCardScene.instantiate()
		_list.add_child(card)
		card.setup(species)
		card.info_requested.connect(_on_card_info_requested)

	var v_scroll := _scroll.get_v_scroll_bar()
	v_scroll.changed.connect(_update_bottom_fade)
	v_scroll.value_changed.connect(_on_scroll_value_changed)
	call_deferred("_update_bottom_fade")


func _on_card_info_requested(species: DinoSpeciesData) -> void:
	species_info_requested.emit(species)


func _on_scroll_value_changed(_value: float) -> void:
	_update_bottom_fade()
	_emit_scroll_ratio()


func _update_bottom_fade() -> void:
	var v_scroll := _scroll.get_v_scroll_bar()
	var scrollable := v_scroll.max_value > v_scroll.page
	var at_bottom := v_scroll.value >= v_scroll.max_value - v_scroll.page - 1.0
	_bottom_fade.visible = scrollable and not at_bottom


func _emit_scroll_ratio() -> void:
	var v_scroll := _scroll.get_v_scroll_bar()
	var max_scroll := v_scroll.max_value - v_scroll.page
	var ratio := clampf(v_scroll.value / max_scroll, 0.0, 1.0) if max_scroll > 0.0 else 0.0
	scrolled.emit(ratio)


func get_card_for_species(species_id: StringName) -> Control:
	for card in _list.get_children():
		if card.get_species_id() == species_id:
			return card
	return null


## Rola a lista até o card da espécie ficar visível (usado pelo tutorial de
## onboarding, que destaca o Velociraptor). Retorna o card, ou null se a
## espécie não existir.
func scroll_to_species(species_id: StringName) -> Control:
	var card := get_card_for_species(species_id)
	if card:
		_scroll.ensure_control_visible(card)
	return card
