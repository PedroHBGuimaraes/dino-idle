extends PanelContainer

## Popup de configurações: volume de música e efeitos (separados), mudo
## geral e seletor de idioma. Aberto pelo botão de engrenagem do HUD.

const ICON_SOUND_ON := preload("res://assets/ui/icon_sound_on.png")
const ICON_SOUND_OFF := preload("res://assets/ui/icon_sound_off.png")

var _popup_tween: Tween

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _language_option: OptionButton = %LanguageOption
@onready var _mute_button: Button = %MuteButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	add_to_group(&"modal_popup")
	_music_slider.value = AudioManager.music_volume
	_sfx_slider.value = AudioManager.sfx_volume
	_populate_language_option()
	_refresh_mute_button()

	_music_slider.value_changed.connect(AudioManager.set_music_volume)
	_sfx_slider.value_changed.connect(AudioManager.set_sfx_volume)
	_language_option.item_selected.connect(_on_language_selected)
	_mute_button.pressed.connect(AudioManager.toggle_muted)
	_close_button.pressed.connect(_on_close_pressed)

	AudioManager.muted_changed.connect(_on_muted_changed)


## O texto dos labels estáticos se atualiza sozinho (auto-translate); aqui
## só o que é montado por código: o botão de mudo e a seleção do dropdown
## (cujos itens ficam nos nomes nativos, mas o item selecionado tem que
## refletir o idioma atual).
func _notification(what: int) -> void:
	# TRANSLATION_CHANGED chega antes de _ready() também (ao entrar na árvore),
	# quando os @onready ainda são null — daí o is_node_ready().
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_mute_button()
		_select_current_language()


func open() -> void:
	AudioManager.play_click()
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_open(self)


## Fechar pelo toque no fundo escurecido (ver ModalScrim) — mesma coisa que
## o botão Fechar.
func request_close() -> void:
	_on_close_pressed()


func _on_close_pressed() -> void:
	AudioManager.play_click()
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = PopupTransition.animate_close(self)


func _on_muted_changed(_muted: bool) -> void:
	_refresh_mute_button()


func _refresh_mute_button() -> void:
	_mute_button.icon = ICON_SOUND_OFF if AudioManager.muted else ICON_SOUND_ON
	_mute_button.text = Loc.t("SETTINGS_UNMUTE") if AudioManager.muted else Loc.t("SETTINGS_MUTE")


## Cada item usa o nome do idioma NO PRÓPRIO idioma (Loc.LOCALE_NATIVE_NAMES),
## pra ficar reconhecível seja qual for o idioma atual. Índice do item ==
## índice em Loc.SUPPORTED_LOCALES.
func _populate_language_option() -> void:
	_language_option.clear()
	for i in Loc.SUPPORTED_LOCALES.size():
		var locale: String = Loc.SUPPORTED_LOCALES[i]
		_language_option.add_item(Loc.LOCALE_NATIVE_NAMES[locale], i)
	_select_current_language()


func _select_current_language() -> void:
	var idx := Loc.SUPPORTED_LOCALES.find(LocaleManager.language)
	if idx >= 0:
		_language_option.selected = idx


func _on_language_selected(index: int) -> void:
	AudioManager.play_click()
	LocaleManager.set_language(Loc.SUPPORTED_LOCALES[index])
