extends Node

## Teste de integração da troca de idioma em runtime (Etapa 4). Roda a Main
## de verdade, troca o idioma e confere que o texto montado por código (HUD,
## DinoCard) e os labels estáticos (auto-translate) se atualizam SEM reload.
##
##   godot --headless tests/test_locale_switch.tscn --quit-after 400 --path .

const MainScene := preload("res://scenes/main/Main.tscn")

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = MainScene.instantiate()
	add_child(_main)
	_run.call_deferred()


func _run() -> void:
	# Deixa a Main montar UI + carregar save.
	for i in 30:
		await get_tree().process_frame

	var locale_manager := get_node("/root/LocaleManager")
	var food_label := _main.find_child("FoodLabel", true, false) as Label
	var lang_option := _main.find_child("LanguageOption", true, false) as OptionButton

	_check("achou FoodLabel", food_label != null)
	_check("achou LanguageOption no SettingsPopup", lang_option != null)
	if food_label == null:
		_finish()
		return

	locale_manager.set_language("pt")
	await get_tree().process_frame
	var pt_text: String = food_label.text
	_check("HUD em pt começa com 'Comida:'", pt_text.begins_with("Comida:"))

	# Troca pra alemão
	locale_manager.set_language("de")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("HUD reagiu à troca (pt != de)", food_label.text != pt_text)
	_check("HUD em de começa com 'Futter:'", food_label.text.begins_with("Futter:"))
	_check("locale salvo = de", locale_manager.language == "de")

	# O OptionButton de idioma segue o locale atual
	if lang_option != null:
		_check(
			"OptionButton selecionou 'Deutsch'",
			lang_option.get_item_text(lang_option.selected) == "Deutsch"
		)

	# Volta pra fr e confere de novo
	locale_manager.set_language("fr")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("HUD em fr", food_label.text.begins_with("Nourriture"))

	locale_manager.set_language("pt")
	_finish()


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  PASS - ", label)
	else:
		printerr("  FAIL - ", label)
		_failures += 1


func _finish() -> void:
	if _failures == 0:
		print("OK: troca de idioma em runtime funciona")
	else:
		printerr("=== %d falha(s) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
