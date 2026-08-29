extends PanelContainer

## Popup de "bem-vindo de volta" com o total de comida ganho enquanto o app
## estava fechado. Fica invisível até SaveManager.offline_earnings_ready
## disparar. Oferece um anúncio recompensado pra dobrar esse ganho.

const ICON_AD_PLAY := preload("res://assets/ui/icon_ad_play.png")

var _last_amount: float = 0.0
var _last_minutes: int = 0
var _bonus_claimed := false
var _popup_tween: Tween

@onready var _message_label: Label = %MessageLabel
@onready var _close_button: Button = %CloseButton
@onready var _double_button: Button = %DoubleButton


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_double_button.pressed.connect(_on_double_button_pressed)
	SaveManager.offline_earnings_ready.connect(_on_offline_earnings_ready)


func _on_close_pressed() -> void:
	AudioManager.play_click()
	_animate_close()


func _on_offline_earnings_ready(amount: float, offline_seconds: float) -> void:
	_last_amount = amount
	_last_minutes = int(offline_seconds / 60.0)
	_bonus_claimed = false
	_rebuild_message()
	_double_button.icon = ICON_AD_PLAY
	_double_button.text = Loc.t("OFFLINE_DOUBLE_BUTTON")
	_double_button.visible = true
	_double_button.disabled = not AdsManager.is_rewarded_ad_ready()
	_animate_open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_rebuild_message()
		_double_button.text = Loc.t("OFFLINE_DOUBLE_BUTTON")


func _rebuild_message() -> void:
	var text := Loc.t(
		"OFFLINE_BODY", {"amount": FoodFormat.format(_last_amount), "minutes": _last_minutes}
	)
	if _bonus_claimed:
		text += Loc.t("OFFLINE_BONUS_SUFFIX", {"amount": FoodFormat.format(_last_amount)})
	_message_label.text = text


func _on_double_button_pressed() -> void:
	AudioManager.play_click()
	_double_button.disabled = true
	AdsManager.show_rewarded_ad(_on_double_reward)


func _on_double_reward(earned: bool) -> void:
	if earned:
		GameManager.add_food(_last_amount)
		_bonus_claimed = true
		_rebuild_message()
		_double_button.visible = false
	else:
		_double_button.disabled = not AdsManager.is_rewarded_ad_ready()


func _animate_open() -> void:
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_open(self)


func _animate_close() -> void:
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_close(self)
