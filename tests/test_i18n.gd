extends SceneTree

## Smoke test da estrutura de tradução (Etapa 2). Roda headless:
##   godot --headless -s tests/test_i18n.gd --path .
## Confere: CSV importado, chaves resolvem em pt, fallback pt funciona pros
## idiomas ainda vazios, placeholders via Loc.t() interpolam, "\n" vira
## quebra real, e a lista de locales do projeto está completa.


func _initialize() -> void:
	var failures := 0

	# 1. Locales configurados
	var locales := TranslationServer.get_loaded_locales()
	for expected in ["pt", "en", "es", "de", "fr"]:
		if not locales.has(expected):
			printerr("FAIL: locale '%s' não carregado (loaded: %s)" % [expected, locales])
			failures += 1

	# 2. Chave simples resolve em pt
	TranslationServer.set_locale("pt")
	var close_pt := TranslationServer.translate("COMMON_CLOSE")
	if close_pt != "Fechar":
		printerr("FAIL: COMMON_CLOSE em pt = '%s' (esperado 'Fechar')" % close_pt)
		failures += 1

	# 3. Cada idioma tem tradução própria (Etapa 5 preenchida)
	var expected_close := {"en": "Close", "es": "Cerrar", "de": "Schließen", "fr": "Fermer"}
	for lc: String in expected_close:
		TranslationServer.set_locale(lc)
		var got := TranslationServer.translate("COMMON_CLOSE")
		if got != expected_close[lc]:
			printerr(
				"FAIL: COMMON_CLOSE em %s = '%s' (esperado '%s')" % [lc, got, expected_close[lc]]
			)
			failures += 1

	# 3b. Fallback pt: chave que só existe em pt cai pra pt em qualquer locale
	# (garantido pelo project.godot locale/fallback="pt"). Testado com uma
	# chave real conferindo que set_locale não some com nada.
	TranslationServer.set_locale("de")
	if Loc.t("PRESTIGE_TITLE") != "Prestige":
		printerr("FAIL: PRESTIGE_TITLE em de")
		failures += 1

	# 4. Placeholder interpola (em outro idioma, pra pegar template errado)
	TranslationServer.set_locale("fr")
	var food := Loc.t("HUD_FOOD", {"amount": "1.20K"})
	if food != "Nourriture : 1.20K":
		printerr("FAIL: Loc.t HUD_FOOD (fr) = '%s'" % food)
		failures += 1
	TranslationServer.set_locale("pt")

	# 5. "\n" vira quebra real
	var unlock := Loc.t("CARD_UNLOCK_BUTTON", {"cost": "500"})
	if not unlock.contains("\n") or unlock.contains("\\n"):
		printerr("FAIL: CARD_UNLOCK_BUTTON não quebrou linha: %s" % unlock.replace("\n", "<LF>"))
		failures += 1

	# 6. Chaves derivadas (espécie / prestígio)
	var trex := load("res://data/species/trex.tres") as DinoSpeciesData
	if trex == null or trex.get_display_name() != "Tiranossauro Rex":
		var got: String = trex.get_display_name() if trex else "<nil>"
		printerr("FAIL: trex.get_display_name() = '%s'" % got)
		failures += 1
	var prod1 := load("res://data/prestige/prod_1.tres") as PrestigeUpgradeData
	if prod1 == null or prod1.get_display_name() != "Sedimento Fértil":
		printerr("FAIL: prod_1.get_display_name()")
		failures += 1

	# 6b. Detecção de idioma do sistema: variantes regionais colapsam pro
	# idioma suportado; qualquer coisa fora dos 5 cai em pt.
	var cases := {
		"en_US": "en",
		"en_GB": "en",
		"en": "en",
		"pt_BR": "pt",
		"pt_PT": "pt",
		"es_ES": "es",
		"es_419": "es",
		"de_DE": "de",
		"de_AT": "de",
		"fr_FR": "fr",
		"fr-CA": "fr",
		"zh_Hans_CN": "pt",
		"ja_JP": "pt",
		"": "pt",
	}
	for raw: String in cases:
		var got := Loc.resolve_supported_locale(raw)
		if got != cases[raw]:
			printerr(
				(
					"FAIL: resolve_supported_locale('%s') = '%s' (esperado '%s')"
					% [raw, got, cases[raw]]
				)
			)
			failures += 1

	# 7. Toda chave resolve (não-vazio) nos 5 idiomas + placeholders {x}
	# preservados em todas as traduções (senão o String.format quebra).
	var re := RegEx.new()
	re.compile("\\{[a-z_]+\\}")
	for key: String in _csv_keys():
		var pt := ""
		var pt_holders: PackedStringArray = []
		for lc in ["pt", "en", "es", "de", "fr"]:
			TranslationServer.set_locale(lc)
			var val := TranslationServer.translate(key)
			if val == key or val.strip_edges().is_empty():
				printerr("FAIL: %s sem tradução em %s" % [key, lc])
				failures += 1
				continue
			var holders: PackedStringArray = []
			for m in re.search_all(val):
				holders.append(m.get_string())
			holders.sort()
			if lc == "pt":
				pt = val
				pt_holders = holders
			elif holders != pt_holders:
				printerr(
					(
						"FAIL: %s placeholders diferem em %s: %s vs pt %s"
						% [key, lc, holders, pt_holders]
					)
				)
				failures += 1
	TranslationServer.set_locale("pt")

	if failures == 0:
		print("OK: i18n smoke test passou (", locales.size(), " locales)")
		quit(0)
	else:
		printerr("=== %d falha(s) ===" % failures)
		quit(1)


func _csv_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	for row in FileAccess.get_file_as_string("res://translations.csv").split("\n"):
		var key := row.split(",")[0].strip_edges()
		if key != "" and key != "keys":
			keys.append(key)
	return keys
