extends PanelContainer

## Popup de detalhes de uma espécie: mostra as passivas dos 4 marcos de
## nível (25/50/75/100), incluindo as ainda BLOQUEADAS — o pedido explícito
## foi deixar o jogador ver o que cada passiva faz (e o que vem a seguir)
## ANTES de gastar comida subindo de nível, não só depois. Aberto pelo
## %InfoButton de cada DinoCard (ver ShopPanel.species_info_requested).

const MILESTONES := [25, 50, 75, 100]

const STATUS_UNLOCKED_COLOR := Color(0.6, 0.9, 0.65, 1)
const STATUS_NEXT_COLOR := Color(1.0, 0.84, 0.3, 1)
const STATUS_LOCKED_COLOR := Color(0.55, 0.52, 0.5, 1)

var _species: DinoSpeciesData
var _popup_tween: Tween

@onready var _name_label: Label = %NameLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _row_25: Label = %Row25
@onready var _row_50: Label = %Row50
@onready var _row_75: Label = %Row75
@onready var _row_100: Label = %Row100
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	add_to_group(&"modal_popup")
	_close_button.pressed.connect(_on_close_pressed)
	hide()


## Fechar pelo toque no fundo escurecido (ver ModalScrim).
func request_close() -> void:
	_on_close_pressed()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_TRANSLATION_CHANGED
		and is_node_ready()
		and visible
		and _species != null
	):
		_refresh()


func open(species: DinoSpeciesData) -> void:
	_species = species
	_refresh()

	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_open(self)


func _on_close_pressed() -> void:
	AudioManager.play_click()
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_close(self)


func _refresh() -> void:
	var unlocked := GameManager.is_unlocked(_species.id)
	var level := GameManager.get_level(_species.id) if unlocked else 0

	_name_label.text = _species.get_display_name()
	_subtitle_label.text = (
		Loc.t("CARD_LEVEL", {"level": level})
		if unlocked
		else Loc.t(
			"SPECIES_DETAIL_SUBTITLE_LOCKED", {"cost": FoodFormat.format(_species.unlock_cost)}
		)
	)

	# Só existe um "próximo marco" se a espécie já estiver desbloqueada — pra
	# uma espécie ainda bloqueada, o próximo passo é desbloqueá-la (já dito
	# na subtitle), não avançar rumo a um marco de nível.
	var next_milestone := -1
	if unlocked:
		for milestone: int in MILESTONES:
			if level < milestone:
				next_milestone = milestone
				break

	var rows := {25: _row_25, 50: _row_50, 75: _row_75, 100: _row_100}
	for milestone: int in MILESTONES:
		var row: Label = rows[milestone]
		var passive := _species.get_passive_for_milestone(milestone)
		var description := passive.describe() if passive else "—"
		var params := {"level": milestone, "effect": description}

		if level >= milestone:
			row.text = Loc.t("SPECIES_DETAIL_ROW_UNLOCKED", params)
			row.add_theme_color_override("font_color", STATUS_UNLOCKED_COLOR)
		elif milestone == next_milestone:
			row.text = Loc.t("SPECIES_DETAIL_ROW_NEXT", params)
			row.add_theme_color_override("font_color", STATUS_NEXT_COLOR)
		else:
			row.text = Loc.t("SPECIES_DETAIL_ROW_LOCKED", params)
			row.add_theme_color_override("font_color", STATUS_LOCKED_COLOR)
