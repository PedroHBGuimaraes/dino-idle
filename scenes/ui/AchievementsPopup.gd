extends PanelContainer

## Tela de conquistas — acessível pelo botão de troféu no HUD. Mostra as 12
## conquistas (ver AchievementManager), desbloqueadas em cor cheia e
## bloqueadas em silhueta (ver AchievementRow). Reconstrói a lista inteira
## a cada abertura/desbloqueio em vez de atualizar linha a linha — só 12
## linhas, simples e barato o bastante pra não precisar de nada mais fino.

const AchievementRowScene := preload("res://scenes/ui/AchievementRow.tscn")

var _popup_tween: Tween

@onready var _progress_label: Label = %ProgressLabel
@onready var _list: VBoxContainer = %List
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	add_to_group(&"modal_popup")
	_close_button.pressed.connect(_on_close_pressed)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	hide()


## Fechar pelo toque no fundo escurecido (ver ModalScrim).
func request_close() -> void:
	_on_close_pressed()


func open() -> void:
	_refresh()
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_open(self)


func _on_close_pressed() -> void:
	AudioManager.play_click()
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_close(self)


func _on_achievement_unlocked(_achievement: AchievementData) -> void:
	if visible:
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var achievements := AchievementManager.get_all_achievements()
	_progress_label.text = Loc.t(
		"ACHIEVEMENTS_PROGRESS",
		{"unlocked": AchievementManager.get_unlocked_count(), "total": achievements.size()}
	)

	for achievement: AchievementData in achievements:
		var row := AchievementRowScene.instantiate()
		_list.add_child(row)
		row.setup(achievement, AchievementManager.is_unlocked(achievement.id))
