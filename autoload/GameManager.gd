extends Node

## Autoload. Fonte única de verdade do estado de jogo: comida e o estado de
## cada espécie (desbloqueada? em que nível?). UI e SaveManager conversam
## com o jogo só por aqui (nunca direto com DinoSpeciesData/SpeciesDatabase
## para mutar estado).
##
## Cada espécie tem UM único dino: desbloqueado uma vez (unlock_cost) e
## depois sobe de nível 1 a DinoSpeciesData.MAX_LEVEL, gastando comida a
## cada "level up" (custo geométrico) e aumentando sua produção de forma
## contínua nível a nível — não mais em 3 saltos grandes. O sprite ainda
## troca em 3 faixas (Filhote/Jovem/Adulto), mas isso é só visual (ver
## DinoSpeciesData.stage_for_level); custo e produção são sempre por nível.
##
## A cada marco de nível (25/50/75/100) a espécie desbloqueia a passiva
## definida em DinoSpeciesData.passive_25/50/75/100 (um PassiveEffect) —
## cada dino tem sua própria combinação de tipos, não um padrão fixo igual
## pra todas. APLICAR os efeitos é responsabilidade deste autoload (que é
## quem conhece o estado de todas as espécies pra somar bônus globais e
## resolver sinergias condicionais — ver _collect_active_global_passives).
##
## O combo de cliques (PassiveEffect.Type.COMBO_CLICK_BOOST) é um estado à
## parte (não é "de uma espécie", é do JOGADOR): cada toque incrementa um
## contador, que zera sozinho depois de COMBO_TIMEOUT_SECONDS sem tocar —
## ver _register_combo_tap/_get_combo_tap_multiplier e o sinal combo_changed
## (a UI usa isso pra mostrar/esconder o indicador de combo).
##
## Também guarda o buff temporário de produção em dobro (anúncio
## recompensado). Quem dispara o anúncio em si é o AdsManager; este autoload
## só aplica o efeito já concedido.

signal food_changed(new_amount: float)
## Disparado quando uma espécie é desbloqueada ou sobe de nível (e também ao
## carregar o save, para sincronizar a UI já conectada).
signal dino_state_changed(species_id: StringName, unlocked: bool, level: int)
## Disparado quando o buff de produção em dobro é ativado ou expira.
signal production_boost_changed(active: bool, expires_unix: float)
## Disparado uma única vez, no exato momento em que a última espécie
## bloqueada/imatura alcança "desbloqueada + nível 100" — nunca reemitido
## depois (level_up_dino() só chega nesse estado uma vez, já que progresso
## é sempre monotônico: uma vez completa, can_level_up() nunca mais libera
## outra chamada que passaria por aqui de novo).
signal collection_completed
## Disparado a cada toque (novo count) e quando o combo zera por inatividade
## (count=0, bonus_multiplier=1.0) — a UI usa isso pra mostrar/esconder o
## indicador "Combo: Nx".
signal combo_changed(count: int, bonus_multiplier: float)
## Disparado a cada toque MANUAL na área de alimentar (não passiva/produção,
## não bônus de anúncio) — usado pelo AchievementManager pra contar toques
## ao longo da vida da conta ("Dedo Ligeiro"/"Dedo de Aço").
signal tapped(amount: float)
## Disparado toda vez que comida é GANHA (toque, produção passiva, bônus de
## anúncio, offline) — diferente de food_changed, que reporta o saldo NOVO;
## este reporta só o delta positivo, então dá pra somar "comida ganha na
## vida da conta" mesmo depois de gastar em desbloqueios/level ups (usado
## pelo AchievementManager).
signal food_earned(amount: float)

const TAP_VALUE: float = 1.0
const BONUS_AD_PRODUCTION_SECONDS: float = 120.0
const BONUS_AD_MINIMUM_FOOD: float = 10.0

## Tempo de inatividade (sem tocar) que zera o combo de cliques.
const COMBO_TIMEOUT_SECONDS := 2.5

## Migração de saves antigos (sistema de 3 estágios) pro sistema de níveis:
## stage 0 (Filhote) → nível 1, stage 1 (Jovem) → nível 25, stage 2
## (Adulto) → nível 50 — mantém o dino na mesma faixa visual que já estava.
const _LEGACY_STAGE_TO_LEVEL := [1, 25, 50]

var food: float = 0.0
var species_unlocked: Dictionary = {}  # StringName -> bool
var species_level: Dictionary = {}  # StringName -> int (1..MAX_LEVEL)

var production_boost_multiplier: float = 1.0
var production_boost_expires_unix: float = 0.0  # 0 = nenhum buff ativo

var _combo_count: int = 0
var _combo_last_tap_unix: float = 0.0


func _ready() -> void:
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		species_unlocked[species.id] = species.starts_unlocked
		species_level[species.id] = 1


func _process(delta: float) -> void:
	var production := get_total_production_per_second()
	if production > 0.0:
		add_food(production * delta)

	if _combo_count > 0 and _combo_seconds_since_last_tap() > COMBO_TIMEOUT_SECONDS:
		_combo_count = 0
		combo_changed.emit(0, 1.0)

	if (
		production_boost_expires_unix > 0.0
		and Time.get_unix_time_from_system() >= production_boost_expires_unix
	):
		production_boost_expires_unix = 0.0
		production_boost_changed.emit(false, 0.0)


## Retorna a quantidade de comida realmente ganha (já com os multiplicadores
## de passiva/combo aplicados) — quem chama usa isso pro número flutuante
## de feedback, em vez do TAP_VALUE cru, que não reflete bônus nenhum.
func tap() -> float:
	_register_combo_tap()
	var multiplier := _get_global_tap_multiplier() * _get_combo_tap_multiplier()
	var amount := TAP_VALUE * multiplier
	add_food(amount)
	tapped.emit(amount)
	return amount


func add_food(amount: float) -> void:
	if amount == 0.0:
		return
	food += amount
	food_changed.emit(food)
	if amount > 0.0:
		food_earned.emit(amount)


func is_unlocked(species_id: StringName) -> bool:
	return species_unlocked.get(species_id, false)


func get_level(species_id: StringName) -> int:
	return species_level.get(species_id, 1)


func can_unlock(species_id: StringName) -> bool:
	if is_unlocked(species_id):
		return false
	var data := SpeciesDatabase.get_by_id(species_id)
	if data == null:
		return false
	return food >= data.unlock_cost


## Compra o nível 1 desta espécie pela primeira vez. Retorna true se ocorreu.
func unlock_dino(species_id: StringName) -> bool:
	if not can_unlock(species_id):
		return false
	var data := SpeciesDatabase.get_by_id(species_id)

	food -= data.unlock_cost
	species_unlocked[species_id] = true
	species_level[species_id] = 1

	food_changed.emit(food)
	dino_state_changed.emit(species_id, true, 1)
	return true


func can_level_up(species_id: StringName) -> bool:
	if not is_unlocked(species_id):
		return false
	var data := SpeciesDatabase.get_by_id(species_id)
	if data == null:
		return false
	var level := get_level(species_id)
	if data.is_max_level(level):
		return false
	return food >= data.cost_for_level(level)


## Sobe o dino desta espécie em 1 nível. Retorna true se ocorreu.
func level_up_dino(species_id: StringName) -> bool:
	if not can_level_up(species_id):
		return false
	var data := SpeciesDatabase.get_by_id(species_id)
	var level := get_level(species_id)
	var cost := data.cost_for_level(level)

	food -= cost
	var new_level := level + 1
	species_level[species_id] = new_level

	food_changed.emit(food)
	dino_state_changed.emit(species_id, true, new_level)

	if is_collection_complete():
		collection_completed.emit()
	return true


## Verdadeiro quando toda espécie cadastrada está desbloqueada e no nível
## máximo. Usado pra disparar a tela de celebração (uma vez só, ver
## collection_completed) e reaproveitável se a UI precisar checar o estado
## a qualquer momento (ex. depois de um load_state()).
func is_collection_complete() -> bool:
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not is_unlocked(species.id) or not species.is_max_level(get_level(species.id)):
			return false
	return true


## Progresso geral da coleção, de 0.0 a 1.0: média, entre todas as espécies
## cadastradas, de "nível atual / MAX_LEVEL" (0.0 se ainda bloqueada). Usado
## pelo cenário vivo do fundo (Main.gd) pra decidir quando revelar elementos
## decorativos — sobe de forma suave e monotônica, nunca desce, já que nível
## e desbloqueio nunca regridem.
func get_collection_progress() -> float:
	var all_species := SpeciesDatabase.get_all()
	if all_species.is_empty():
		return 0.0
	var total := 0.0
	for species: DinoSpeciesData in all_species:
		if is_unlocked(species.id):
			total += float(get_level(species.id)) / float(DinoSpeciesData.MAX_LEVEL)
	return total / all_species.size()


## Quais marcos de passiva (25/50/75/100) essa espécie já desbloqueou.
func get_passives_unlocked(species_id: StringName) -> Array:
	var data := SpeciesDatabase.get_by_id(species_id)
	if data == null:
		return []
	return data.passives_unlocked_at(get_level(species_id))


## As PassiveEffect (não nulas) já desbloqueadas por esta espécie — usado
## pelo DinoCard pra montar tooltips descritivas nos selos de passiva.
func get_active_passives(species_id: StringName) -> Array[PassiveEffect]:
	var data := SpeciesDatabase.get_by_id(species_id)
	if data == null:
		return []
	return data.get_active_passives(get_level(species_id))


## Soma a produção "base" das espécies (já com as passivas PERMANENTES
## aplicadas, mas sem o buff temporário de anúncio). Usada pelo SaveManager
## para calcular produção offline, que não deve levar em conta um buff
## temporário que já expirou enquanto o app estava fechado.
func get_base_production_per_second() -> float:
	var aggregate := _collect_active_global_passives()
	var total := 0.0
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not is_unlocked(species.id):
			continue
		var level := get_level(species.id)
		var base := species.production_at_level(level)
		base *= _get_own_production_multiplier(species.id)
		base *= _get_global_production_multiplier_for(level, aggregate)
		total += base
	# Multiplicador PERMANENTE de prestígio (ver PrestigeManager) — diferente
	# do buff de anúncio abaixo, este entra aqui (na produção BASE) de
	# propósito, porque também deve valer pra produção offline calculada pelo
	# SaveManager, que parte desta função.
	total *= PrestigeManager.get_production_multiplier()
	return total


func get_total_production_per_second() -> float:
	var total := get_base_production_per_second()
	if is_production_boost_active():
		total *= production_boost_multiplier
	return total


## Produção/seg de UMA espécie específica agora mesmo (0 se bloqueada), já
## incluindo suas passivas permanentes e o buff de anúncio se estiver
## ativo. Usado pelo DinoCard pra mostrar quanto cada dino está rendendo.
func get_species_current_production(species_id: StringName) -> float:
	if not is_unlocked(species_id):
		return 0.0
	var data := SpeciesDatabase.get_by_id(species_id)
	if data == null:
		return 0.0

	var level := get_level(species_id)
	var aggregate := _collect_active_global_passives()
	var base := data.production_at_level(level)
	base *= _get_own_production_multiplier(species_id)
	base *= _get_global_production_multiplier_for(level, aggregate)
	base *= PrestigeManager.get_production_multiplier()
	return base * production_boost_multiplier if is_production_boost_active() else base


func is_production_boost_active() -> bool:
	return production_boost_expires_unix > Time.get_unix_time_from_system()


## Concede o buff de produção (chamado pelo AdsManager após o usuário
## assistir ao anúncio recompensado). Se já houver um buff ativo, estende a
## partir de agora em vez de empilhar multiplicadores.
func activate_production_boost(multiplier: float, duration_seconds: float) -> void:
	production_boost_multiplier = multiplier
	production_boost_expires_unix = Time.get_unix_time_from_system() + duration_seconds
	production_boost_changed.emit(true, production_boost_expires_unix)


## Bônus de comida instantâneo do anúncio recompensado — disponível desde o
## início do jogo (chamado pelo AdsManager após o usuário assistir ao
## anúncio). O valor escala com a produção atual do jogador (equivalente a
## ~2 minutos de produção, com um piso mínimo) em vez de um número fixo,
## pra continuar relevante em qualquer estágio do jogo — incluindo o começo,
## quando a produção ainda é baixa ou zero.
func claim_bonus_food() -> void:
	var bonus := maxf(
		get_total_production_per_second() * BONUS_AD_PRODUCTION_SECONDS, BONUS_AD_MINIMUM_FOOD
	)
	add_food(bonus)


## Usado pelo SaveManager para aplicar um estado carregado do disco.
## saved_species: { "<id>": {"unlocked": bool, "level": int}, ... } no
## formato atual — também aceita o formato antigo {"unlocked": bool,
## "stage": int} de saves salvos antes do sistema de níveis (ver
## _migrate_level_from_entry). Emite os sinais de atualização para que a UI
## (já conectada em seus próprios _ready) se sincronize, mesmo que tenha
## desenhado com zero antes.
func load_state(
	saved_food: float,
	saved_species: Dictionary,
	saved_boost_multiplier: float = 1.0,
	saved_boost_expires_unix: float = 0.0
) -> void:
	food = saved_food
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		var entry: Dictionary = saved_species.get(String(species.id), {})
		species_unlocked[species.id] = bool(entry.get("unlocked", species.starts_unlocked))
		species_level[species.id] = _migrate_level_from_entry(entry)

	production_boost_multiplier = saved_boost_multiplier
	production_boost_expires_unix = saved_boost_expires_unix

	food_changed.emit(food)
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		dino_state_changed.emit(species.id, is_unlocked(species.id), get_level(species.id))
	production_boost_changed.emit(is_production_boost_active(), production_boost_expires_unix)


## Chamado pelo PrestigeManager depois de conceder os Fósseis Ancestrais da
## run — zera comida e devolve toda espécie ao estado inicial (mesma lógica
## de _ready(): só quem tem starts_unlocked volta desbloqueada, todo mundo no
## nível 1) e encerra qualquer buff de anúncio em andamento. NÃO mexe em
## conquistas (permanentes por design) nem no estado do próprio
## PrestigeManager (Fósseis/upgrades) — só o que este autoload possui.
func reset_for_prestige() -> void:
	food = 0.0
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		species_unlocked[species.id] = species.starts_unlocked
		species_level[species.id] = 1

	production_boost_multiplier = 1.0
	production_boost_expires_unix = 0.0

	food_changed.emit(food)
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		dino_state_changed.emit(species.id, is_unlocked(species.id), get_level(species.id))
	production_boost_changed.emit(false, 0.0)


## Snapshot serializável (Dictionaries/valores base) para o SaveManager.
func get_save_species_state() -> Dictionary:
	var out := {}
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		out[String(species.id)] = {
			"unlocked": is_unlocked(species.id),
			"level": get_level(species.id),
		}
	return out


## Lê o nível de uma entrada salva, migrando do formato antigo (stage
## 0/1/2) se for o caso. Um save nunca deveria ter os dois campos, mas se
## tiver por algum motivo, "level" (o formato atual) tem prioridade.
func _migrate_level_from_entry(entry: Dictionary) -> int:
	if entry.has("level"):
		return clampi(int(entry["level"]), 1, DinoSpeciesData.MAX_LEVEL)
	if entry.has("stage"):
		var stage: int = clampi(int(entry["stage"]), 0, _LEGACY_STAGE_TO_LEVEL.size() - 1)
		return _LEGACY_STAGE_TO_LEVEL[stage]
	return 1


## Bônus permanente (multiplicador) na produção da PRÓPRIA espécie, das
## passivas SPECIES_PRODUCTION_BOOST ativas dela mesma (empilham entre si
## se a espécie tiver mais de uma nesse marco, embora o padrão seja 1 por
## espécie).
func _get_own_production_multiplier(species_id: StringName) -> float:
	var multiplier := 1.0
	for passive: PassiveEffect in get_active_passives(species_id):
		if passive.type == PassiveEffect.Type.SPECIES_PRODUCTION_BOOST:
			multiplier += passive.value
	return multiplier


## Varre as passivas ativas de TODAS as espécies desbloqueadas uma única
## vez e agrupa o que é "global" (independe de qual espécie está sendo
## calculada) — evita repetir essa varredura pra cada espécie na hora de
## calcular produção total.
func _collect_active_global_passives() -> Dictionary:
	var flat_production_bonus := 0.0
	var flat_tap_bonus := 0.0
	var synergies: Array[PassiveEffect] = []

	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not is_unlocked(species.id):
			continue
		for passive: PassiveEffect in get_active_passives(species.id):
			match passive.type:
				PassiveEffect.Type.GLOBAL_PRODUCTION_BOOST:
					flat_production_bonus += passive.value
				PassiveEffect.Type.TAP_VALUE_BOOST:
					flat_tap_bonus += passive.value
				PassiveEffect.Type.THRESHOLD_SYNERGY:
					synergies.append(passive)

	return {
		"flat_production_bonus": flat_production_bonus,
		"flat_tap_bonus": flat_tap_bonus,
		"synergies": synergies,
	}


## Multiplicador de produção global pra uma espécie no nível `target_level`
## — soma o bônus "flat" (GLOBAL_PRODUCTION_BOOST, vale pra todo mundo) com
## o de toda THRESHOLD_SYNERGY cujo limiar o `target_level` já alcança.
func _get_global_production_multiplier_for(target_level: int, aggregate: Dictionary) -> float:
	var multiplier := 1.0 + float(aggregate["flat_production_bonus"])
	for passive: PassiveEffect in aggregate["synergies"]:
		if target_level >= passive.threshold_level:
			multiplier += passive.value
	return multiplier


func _get_global_tap_multiplier() -> float:
	var multiplier := 1.0 + float(_collect_active_global_passives()["flat_tap_bonus"])
	return multiplier * PrestigeManager.get_tap_multiplier()


func _combo_seconds_since_last_tap() -> float:
	return Time.get_unix_time_from_system() - _combo_last_tap_unix


func _register_combo_tap() -> void:
	if _combo_count == 0 or _combo_seconds_since_last_tap() <= COMBO_TIMEOUT_SECONDS:
		_combo_count += 1
	else:
		_combo_count = 1
	_combo_last_tap_unix = Time.get_unix_time_from_system()
	combo_changed.emit(_combo_count, _get_combo_tap_multiplier())


## Bônus de toque do combo de cliques ativo agora — soma toda passiva
## COMBO_CLICK_BOOST desbloqueada, escalando em degraus de
## `combo_clicks_per_step` cliques seguidos até o teto `combo_max_clicks`.
func _get_combo_tap_multiplier() -> float:
	var multiplier := 1.0
	for species: DinoSpeciesData in SpeciesDatabase.get_all():
		if not is_unlocked(species.id):
			continue
		for passive: PassiveEffect in get_active_passives(species.id):
			if passive.type == PassiveEffect.Type.COMBO_CLICK_BOOST:
				var effective_clicks := mini(_combo_count, passive.combo_max_clicks)
				var steps := effective_clicks / passive.combo_clicks_per_step
				multiplier += float(steps) * passive.value
	return multiplier
