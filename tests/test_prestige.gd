extends SceneTree

## Teste headless do sistema de prestígio (ver PrestigeManager/
## GameManager.reset_for_prestige) — não usa nenhum framework (o projeto não
## tem GUT/gdUnit instalado, ver dino-idle-game-plano.md), só um script
## SceneTree simples no padrão nativo do Godot. Autoloads (SpeciesDatabase,
## GameManager, PrestigeManager, ...) já sobem normalmente nesse modo, sem
## precisar carregar Main.tscn.
##
## Roda com:
##   godot --headless -s tests/test_prestige.gd --path .
## (a partir da raiz do projeto). Imprime PASS/FAIL por checagem e sai com
## código 0 se tudo passou, 1 se algo falhou.
##
## Cuidado: mexe de verdade no estado em memória de GameManager/PrestigeManager
## (desbloqueia/nivela espécies, prestigia, compra upgrades) — não salva nada
## em disco (save_game() nunca é chamado aqui), então não sobrescreve o save
## real de ninguém que rodar isso.

var _pass_count := 0
var _fail_count := 0


func _initialize() -> void:
	print("=== test_prestige.gd ===")

	_test_reset_correctness()
	_test_fossil_persistence()
	_test_production_multiplier()

	print("")
	print("%d passou, %d falhou" % [_pass_count, _fail_count])
	quit(0 if _fail_count == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("  PASS - %s" % label)
	else:
		_fail_count += 1
		print("  FAIL - %s" % label)


## reset_for_prestige() precisa zerar comida, devolver toda espécie pro
## nível 1, e só deixar desbloqueada quem tem starts_unlocked == true.
func _test_reset_correctness() -> void:
	print("\n-- GameManager.reset_for_prestige() --")

	var all_species := SpeciesDatabase.get_all()
	_check("há espécies carregadas", all_species.size() > 0)
	if all_species.is_empty():
		return

	GameManager.add_food(1e12)
	var sample := all_species.slice(0, mini(5, all_species.size()))
	for species: DinoSpeciesData in sample:
		if not GameManager.is_unlocked(species.id):
			GameManager.unlock_dino(species.id)
		for i in 10:
			if not GameManager.level_up_dino(species.id):
				break

	var any_leveled := false
	for species: DinoSpeciesData in sample:
		if GameManager.get_level(species.id) > 1:
			any_leveled = true
	_check("setup: pelo menos uma espécie subiu de nível antes do reset", any_leveled)

	GameManager.reset_for_prestige()

	_check("reset: food == 0", GameManager.food == 0.0)

	var all_level_one := true
	for species: DinoSpeciesData in all_species:
		if GameManager.get_level(species.id) != 1:
			all_level_one = false
	_check("reset: todas as espécies voltaram pro nível 1", all_level_one)

	var starters_match := true
	for species: DinoSpeciesData in all_species:
		if GameManager.is_unlocked(species.id) != species.starts_unlocked:
			starters_match = false
	_check("reset: só espécies com starts_unlocked continuam desbloqueadas", starters_match)


## get_save_state()/load_state() do PrestigeManager precisam ir e voltar sem
## perder fósseis, contagem de prestígios ou níveis de upgrade comprados —
## esse é o contrato que o SaveManager depende pra sobreviver a fechar/abrir
## o app. Não toca no save real em disco.
func _test_fossil_persistence() -> void:
	print("\n-- persistência de PrestigeManager (get_save_state/load_state) --")

	var all_species := SpeciesDatabase.get_all()
	GameManager.add_food(1e15)
	for species: DinoSpeciesData in all_species:
		if not GameManager.is_unlocked(species.id):
			GameManager.unlock_dino(species.id)
		while GameManager.level_up_dino(species.id):
			pass

	_check(
		"setup: progresso da coleção já cruzou o piso de prestígio", PrestigeManager.can_prestige()
	)

	var fossils_before := PrestigeManager.fossils
	var performed := PrestigeManager.perform_prestige()
	_check("perform_prestige() retornou true com progresso suficiente", performed)
	_check("fossils aumentou depois de prestigiar", PrestigeManager.fossils > fossils_before)

	var upgrades := PrestigeManager.get_all_upgrades()
	_check("há upgrades de prestígio carregados de data/prestige/", upgrades.size() > 0)

	var bought_id: StringName = &""
	if not upgrades.is_empty():
		var upgrade: PrestigeUpgradeData = upgrades[0]
		if PrestigeManager.buy_upgrade(upgrade.id):
			bought_id = upgrade.id
	_check("conseguiu comprar ao menos 1 nível de upgrade com os fósseis ganhos", bought_id != &"")

	var saved := PrestigeManager.get_save_state()
	var expected_fossils := PrestigeManager.fossils
	var expected_count := PrestigeManager.prestige_count
	var expected_level := PrestigeManager.get_upgrade_level(bought_id)

	# Simula abrir uma sessão nova: zera tudo via API pública e recarrega só
	# a partir do snapshot serializado.
	PrestigeManager.load_state({})
	_check("load_state({}) zera fossils", PrestigeManager.fossils == 0.0)

	PrestigeManager.load_state(saved)
	_check(
		"load_state(saved): fossils bate com o valor salvo",
		PrestigeManager.fossils == expected_fossils
	)
	_check(
		"load_state(saved): prestige_count bate com o valor salvo",
		PrestigeManager.prestige_count == expected_count
	)
	if bought_id != &"":
		_check(
			"load_state(saved): nível do upgrade comprado sobrevive à volta",
			PrestigeManager.get_upgrade_level(bought_id) == expected_level
		)


## Os 3 pontos de aplicação do multiplicador em GameManager
## (get_total_production_per_second, get_species_current_production,
## _get_global_tap_multiplier via tap) precisam refletir exatamente o
## multiplicador que PrestigeManager calcula — se algum ficar pra trás, a UI
## e a produção real divergem.
func _test_production_multiplier() -> void:
	print("\n-- multiplicador de prestígio aplicado à produção/toque --")

	GameManager.reset_for_prestige()
	PrestigeManager.load_state({})

	var species_id: StringName = SpeciesDatabase.get_all()[0].id
	GameManager.add_food(1e12)
	if not GameManager.is_unlocked(species_id):
		GameManager.unlock_dino(species_id)
	for i in 5:
		GameManager.level_up_dino(species_id)

	var production_before := GameManager.get_total_production_per_second()
	var species_production_before := GameManager.get_species_current_production(species_id)

	var production_upgrade: PrestigeUpgradeData = null
	for upgrade: PrestigeUpgradeData in PrestigeManager.get_all_upgrades():
		if upgrade.target == PrestigeUpgradeData.Target.PRODUCTION:
			production_upgrade = upgrade
			break
	_check("há upgrade de produção pra testar", production_upgrade != null)
	if production_upgrade == null:
		return

	PrestigeManager.fossils = 1000.0
	PrestigeManager.buy_upgrade(production_upgrade.id)
	var level := PrestigeManager.get_upgrade_level(production_upgrade.id)
	var expected_multiplier := 1.0 + production_upgrade.bonus_for_level(level)

	var production_after := GameManager.get_total_production_per_second()
	var species_production_after := GameManager.get_species_current_production(species_id)

	_check(
		"get_total_production_per_second() escalou pelo multiplicador esperado",
		is_equal_approx(production_after, production_before * expected_multiplier)
	)
	_check(
		"get_species_current_production() escalou pelo MESMO multiplicador (não diverge da UI)",
		is_equal_approx(species_production_after, species_production_before * expected_multiplier)
	)

	var tap_upgrade: PrestigeUpgradeData = null
	for upgrade: PrestigeUpgradeData in PrestigeManager.get_all_upgrades():
		if upgrade.target == PrestigeUpgradeData.Target.TAP:
			tap_upgrade = upgrade
			break
	_check("há upgrade de toque pra testar", tap_upgrade != null)
	if tap_upgrade == null:
		return

	var tap_multiplier_before := PrestigeManager.get_tap_multiplier()
	PrestigeManager.fossils = 1000.0
	PrestigeManager.buy_upgrade(tap_upgrade.id)
	var tap_multiplier_after := PrestigeManager.get_tap_multiplier()
	_check(
		"get_tap_multiplier() aumentou depois de comprar upgrade de toque",
		tap_multiplier_after > tap_multiplier_before
	)
