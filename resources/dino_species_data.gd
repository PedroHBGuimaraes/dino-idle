class_name DinoSpeciesData
extends Resource

## Definição estática de uma espécie de dinossauro. Uma instância .tres por
## espécie vive em res://data/species/ e é lida pelo SpeciesDatabase.
##
## Cada espécie tem UM único dino: desbloqueado uma vez (unlock_cost) e
## depois sobe de nível 1 a MAX_LEVEL, gastando comida a cada "level up"
## (cost_for_level, crescendo geometricamente) e aumentando sua produção de
## forma contínua nível a nível (production_at_level) — não mais em 3
## saltos grandes. O sprite (Filhote/Jovem/Adulto) troca de faixa em faixa
## de nível (ver stage_for_level), mas isso é só arte: quem rege
## custo/produção é sempre o nível, nunca o estágio visual.
##
## A cada marco de nível (25/50/75/100) o dino desbloqueia uma passiva
## permanente — QUAL passiva é definida por espécie em passive_25/50/75/100
## (PassiveEffect), pra cada dino ter sua própria "identidade" de bônus em
## vez de um padrão igual pra todas. APLICAR o efeito (somar bônus entre
## espécies, tratar sinergias condicionais, o combo de cliques) é
## responsabilidade do GameManager, que é quem conhece o estado de todas as
## espécies de uma vez — esta classe só guarda QUAL passiva cada marco tem.

enum Stage { FILHOTE, JOVEM, ADULTO }

const STAGE_NAMES := ["Filhote", "Jovem", "Adulto"]
## Nível mínimo pra cada estágio visual entrar em cena — ver stage_for_level.
const STAGE_LEVEL_THRESHOLDS := [1, 25, 50]

const MAX_LEVEL := 100
const PASSIVE_LEVELS := [25, 50, 75, 100]

## Custo do level up N cresce geometricamente: level_cost_base * growth^(N-1).
const LEVEL_COST_GROWTH := 1.08
## Produção também cresce geometricamente com o nível (não linear!) — ver
## docs/economia.md ou o histórico de balance-check: produção linear contra
## custo geométrico faz o ROI marginal desabar por ordens de grandeza ao
## longo de 100 níveis. Usar a MESMA forma (geométrica) pros dois mantém a
## razão entre eles com uma decadência suave e previsível.
const PRODUCTION_GROWTH := 1.045

@export var id: StringName
@export var display_name: String
@export var placeholder_color: Color = Color.WHITE

## Se true, o dino já começa desbloqueado (usado só pelo Compsognathus).
@export var starts_unlocked: bool = false

## Custo único para desbloquear (comprar no nível 1) esta espécie.
@export var unlock_cost: float = 0.0

## Produção de comida/seg no nível 1.
@export var base_production: float = 0.1

## Custo-base do level up 1→2; os demais escalam a partir daqui via
## LEVEL_COST_GROWTH (ver cost_for_level).
@export var level_cost_base: float = 1.0

## Passiva concedida em cada marco de nível — ver PassiveEffect. Pode ficar
## null (nenhuma espécie deveria deixar, mas o GameManager trata null como
## "sem passiva nesse marco" com segurança).
@export var passive_25: PassiveEffect
@export var passive_50: PassiveEffect
@export var passive_75: PassiveEffect
@export var passive_100: PassiveEffect


## Nome de exibição já traduzido pro idioma atual. A chave de tradução é
## derivada do `id` ("trex" -> "SPECIES_TREX"), então o campo `display_name`
## do .tres continua servindo só como referência PT no editor / fallback.
func get_display_name() -> String:
	return Loc.t("SPECIES_" + String(id).to_upper())


func production_at_level(level: int) -> float:
	return base_production * pow(PRODUCTION_GROWTH, float(level - 1))


## Custo pra subir de `level` para `level + 1`. -1 se já no nível máximo.
func cost_for_level(level: int) -> float:
	if is_max_level(level):
		return -1.0
	return level_cost_base * pow(LEVEL_COST_GROWTH, float(level - 1))


func is_max_level(level: int) -> bool:
	return level >= MAX_LEVEL


## Índice do estágio visual (Stage.FILHOTE/JOVEM/ADULTO) — só decide qual
## sprite mostrar, nunca custo/produção.
func stage_for_level(level: int) -> int:
	var stage := 0
	for i in STAGE_LEVEL_THRESHOLDS.size():
		if level >= STAGE_LEVEL_THRESHOLDS[i]:
			stage = i
	return stage


## Quais marcos de passiva (25/50/75/100) já foram alcançados neste nível.
func passives_unlocked_at(level: int) -> Array:
	return PASSIVE_LEVELS.filter(func(milestone: int) -> bool: return level >= milestone)


## Passiva atribuída a um marco específico (25/50/75/100), ou null se o
## marco não existir ou não tiver passiva definida.
func get_passive_for_milestone(milestone: int) -> PassiveEffect:
	match milestone:
		25:
			return passive_25
		50:
			return passive_50
		75:
			return passive_75
		100:
			return passive_100
		_:
			return null


## As PassiveEffect (não nulas) já desbloqueadas neste nível.
func get_active_passives(level: int) -> Array[PassiveEffect]:
	var active: Array[PassiveEffect] = []
	for milestone: int in passives_unlocked_at(level):
		var passive := get_passive_for_milestone(milestone)
		if passive != null:
			active.append(passive)
	return active
