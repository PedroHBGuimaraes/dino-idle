extends PanelContainer

## Uma linha da tela de conquistas: ícone + nome + descrição. Conquista
## ainda bloqueada usa a MESMA silhueta escurecida já usada pros dinos
## bloqueados (pedido explícito — reaproveitar o padrão visual em vez de
## inventar um novo), via `modulate` no ícone.

const ICON_DIR := "res://assets/achievements/"
const PLACEHOLDER_SIZE := 40
const SILHOUETTE_COLOR := Color(0.02, 0.02, 0.02, 0.9)
const REVEALED_COLOR := Color(1, 1, 1, 1)
const LOCKED_TEXT_COLOR := Color(0.55, 0.52, 0.5, 1)

@onready var _icon_rect: TextureRect = %IconRect
@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel


func setup(achievement: AchievementData, unlocked: bool) -> void:
	_name_label.text = achievement.get_display_name()
	_description_label.text = achievement.get_description()

	var path := ICON_DIR + achievement.icon_filename
	_icon_rect.texture = load(path) if ResourceLoader.exists(path) else _build_placeholder_texture()

	_icon_rect.modulate = REVEALED_COLOR if unlocked else SILHOUETTE_COLOR
	_name_label.add_theme_color_override(
		"font_color", REVEALED_COLOR if unlocked else LOCKED_TEXT_COLOR
	)


## Ícone genérico (quadrado dourado) pra qualquer conquista sem ícone
## gerado ainda — mesmo espírito do placeholder colorido dos dinos.
func _build_placeholder_texture() -> ImageTexture:
	var image := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.75, 0.6, 0.25, 1))
	return ImageTexture.create_from_image(image)
