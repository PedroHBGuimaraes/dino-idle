extends Node

## Autoload. Fila de notificações passageiras ("toasts") no topo da tela —
## conquista desbloqueada é a primeira fonte; buff acabando / bônus de
## anúncio disponível podem ser plugados aqui depois. Mantém sua própria
## CanvasLayer, acima da UI normal mas abaixo do overlay de onboarding.

const ToastScene := preload("res://scenes/ui/Toast.tscn")
const ACH_ICON_DIR := "res://assets/achievements/"
const MAX_VISIBLE := 3

var _column: VBoxContainer
## Última leitura do buff de produção — pra avisar só quando ele EXPIRA
## durante o jogo (transição ativo→inativo), não em toda emissão do sinal.
var _boost_was_active := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)

	_column = VBoxContainer.new()
	_column.anchor_left = 0.5
	_column.anchor_right = 0.5
	_column.anchor_top = 0.0
	_column.offset_top = 58.0
	_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_column.grow_vertical = Control.GROW_DIRECTION_END
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 8)
	layer.add_child(_column)

	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	GameManager.production_boost_changed.connect(_on_production_boost_changed)


## `icon` opcional. Toast mais novo entra no topo da pilha; se passar de
## MAX_VISIBLE, o mais antigo é dispensado na hora.
func show_toast(text: String, icon: Texture2D = null) -> void:
	var toast := ToastScene.instantiate()
	_column.add_child(toast)
	_column.move_child(toast, 0)
	toast.setup(text, icon)

	while _column.get_child_count() > MAX_VISIBLE:
		var oldest := _column.get_child(_column.get_child_count() - 1)
		if oldest.has_method("dismiss"):
			oldest.dismiss()
		else:
			oldest.queue_free()


func _on_achievement_unlocked(achievement: AchievementData) -> void:
	var path := ACH_ICON_DIR + achievement.icon_filename
	var icon: Texture2D = load(path) if ResourceLoader.exists(path) else null
	show_toast(Loc.t("TOAST_ACHIEVEMENT", {"name": achievement.get_display_name()}), icon)


func _on_production_boost_changed(active: bool, _expires_unix: float) -> void:
	if _boost_was_active and not active:
		show_toast(Loc.t("TOAST_BOOST_OFF"), null)
	_boost_was_active = active
