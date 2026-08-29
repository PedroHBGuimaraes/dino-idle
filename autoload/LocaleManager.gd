extends Node

## Autoload. Dono da preferência de idioma do jogo.
##
## Primeiro boot (ou save sem idioma gravado): detecta pelo idioma do
## sistema (OS.get_locale()) e cai em Português se não for um dos 5
## suportados. A partir daí usa o que estiver no save. A escolha manual no
## SettingsPopup (ver Etapa 4) sobrescreve a detecção dali em diante.
##
## Espelha o padrão do AudioManager: guarda a preferência, expõe um setter
## que persiste, e o SaveManager chama load_prefs() ao carregar o save.

signal language_changed(locale: String)

var language: String = Loc.FALLBACK_LOCALE


func _ready() -> void:
	# Aplica um idioma sensato já no boot, ANTES do save carregar (load_game
	# só roda depois que a Main monta a UI) — sem isso a splash e os
	# primeiros frames piscariam sempre em pt. load_prefs() corrige logo em
	# seguida se o jogador já tem preferência salva.
	_apply(detect_system_language())


## Idioma do sistema reduzido a um dos suportados (ou pt de fallback).
## `raw` só é usado nos testes; em runtime lê OS.get_locale().
func detect_system_language(raw: String = "") -> String:
	return Loc.resolve_supported_locale(raw if not raw.is_empty() else OS.get_locale())


## Chamado pelo SaveManager.load_game(). Retorna `true` quando o save não
## tinha idioma gravado (jogador novo ou save pré-i18n) — sinal pro
## SaveManager persistir o idioma detectado agora, cumprindo "salvo na
## primeira vez que o app abre".
func load_prefs(saved: String) -> bool:
	if saved.strip_edges().is_empty():
		return true
	_apply(saved if saved in Loc.SUPPORTED_LOCALES else Loc.FALLBACK_LOCALE)
	return false


## Troca manual de idioma (SettingsPopup). Persiste na hora.
func set_language(locale: String) -> void:
	if locale not in Loc.SUPPORTED_LOCALES or locale == language:
		return
	_apply(locale)
	SaveManager.save_game()


func _apply(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
	language_changed.emit(locale)
