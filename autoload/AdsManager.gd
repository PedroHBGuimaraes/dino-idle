extends Node

## Autoload (cena AdsManager.tscn, com um node filho Admob do plugin
## godot-sdk-integrations/godot-admob — ver addons/AdmobPlugin/). Único
## ponto de contato do resto do jogo com anúncios: ninguém mais deve
## referenciar $Admob diretamente.
##
## Hoje configurado em modo de TESTE (IDs de anúncio de teste do Google, ver
## AdsManager.tscn). Ver README.md para o passo a passo de trocar para IDs
## de produção antes de publicar.
##
## Anúncios só funcionam de verdade em build Android/iOS exportado — no
## Editor/desktop o plugin nativo não existe, então os métodos abaixo viram
## no-ops seguros (is_rewarded_ad_ready() sempre false).

## Emitido sempre que is_rewarded_ad_ready() pode ter mudado de valor
## (carregou OU falhou ao carregar) — a UI (ver HUD._on_ad_ready_changed)
## escuta isso pra reativar os botões assim que o anúncio ficar pronto, sem
## depender de algum outro evento não relacionado acontecer primeiro.
signal rewarded_ad_ready_changed

var _consent_resolved: bool = false
var _pending_callback: Callable
var _reward_earned_this_ad: bool = false

@onready var _admob: Admob = %Admob


func _ready() -> void:
	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(_on_consent_info_update_failed)
	_admob.consent_form_loaded.connect(_on_consent_form_loaded)
	_admob.consent_form_dismissed.connect(_on_consent_form_dismissed)
	_admob.consent_form_failed_to_load.connect(_on_consent_form_failed_to_load)
	_admob.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	_admob.rewarded_ad_user_earned_reward.connect(_on_rewarded_ad_user_earned_reward)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(
		_on_rewarded_ad_dismissed_full_screen_content
	)

	# O plugin nativo só existe em builds Android/iOS de verdade — nem tenta
	# inicializar no Editor/desktop, onde ele seria sempre um no-op.
	if OS.get_name() in ["Android", "iOS"]:
		_admob.initialize()


func is_rewarded_ad_ready() -> bool:
	return _admob.is_rewarded_ad_loaded()


## Mostra um anúncio recompensado genérico. `on_result` é chamada com
## (bool earned_reward) quando o anúncio fecha — ou imediatamente com
## `false` se não havia anúncio disponível. Use isso para efeitos "de uso
## único" definidos por quem chama (ex.: dobrar os ganhos offline exibidos
## num popup específico); para os efeitos padrão do jogo, prefira
## request_double_production_boost()/request_bonus_food() abaixo.
func show_rewarded_ad(on_result: Callable) -> void:
	if not is_rewarded_ad_ready():
		if on_result.is_valid():
			on_result.call(false)
		return

	_pending_callback = on_result
	_reward_earned_this_ad = false
	_admob.show_rewarded_ad()


## Anúncio recompensado #1: dobra a produção passiva por 30 minutos.
func request_double_production_boost() -> void:
	show_rewarded_ad(
		func(earned: bool) -> void:
			if earned:
				GameManager.activate_production_boost(2.0, 30.0 * 60.0)
	)


## Anúncio recompensado #3: comida bônus instantânea, liberado a cada
## GameManager.BONUS_AD_UNLOCK_INTERVAL espécies desbloqueadas.
func request_bonus_food() -> void:
	show_rewarded_ad(
		func(earned: bool) -> void:
			if earned:
				GameManager.claim_bonus_food()
	)


func _on_initialization_completed(_status_data: InitializationStatus) -> void:
	_admob.update_consent_info()


func _on_consent_info_updated() -> void:
	_process_consent_status(_admob.get_consent_status())


func _on_consent_info_update_failed(error_data: FormError) -> void:
	push_warning("AdsManager: falha ao atualizar consentimento: %s" % error_data.get_message())


func _process_consent_status(consent: UserConsent) -> void:
	match consent.status:
		UserConsent.Status.UNKNOWN:
			pass  # aguarda outro consent_info_updated; não deveria acontecer em uso normal.
		UserConsent.Status.NOT_REQUIRED, UserConsent.Status.OBTAINED:
			_consent_resolved = true
			_admob.load_rewarded_ad()
		UserConsent.Status.REQUIRED:
			_admob.load_consent_form()


func _on_consent_form_loaded() -> void:
	_admob.show_consent_form()


func _on_consent_form_failed_to_load(error_data: FormError) -> void:
	push_warning(
		"AdsManager: falha ao carregar formulário de consentimento: %s" % error_data.get_message()
	)


func _on_consent_form_dismissed(_error_data: FormError) -> void:
	_process_consent_status(_admob.get_consent_status())


func _on_rewarded_ad_loaded(_ad_info: AdInfo, _response_info: ResponseInfo) -> void:
	rewarded_ad_ready_changed.emit()


func _on_rewarded_ad_failed_to_load(_ad_info: AdInfo, error_data: LoadAdError) -> void:
	push_warning(
		"AdsManager: anúncio recompensado falhou ao carregar: %s" % error_data.get_message()
	)
	rewarded_ad_ready_changed.emit()


func _on_rewarded_ad_user_earned_reward(_ad_info: AdInfo, _reward_data: RewardItem) -> void:
	_reward_earned_this_ad = true


func _on_rewarded_ad_dismissed_full_screen_content(_ad_info: AdInfo) -> void:
	var earned := _reward_earned_this_ad
	var callback := _pending_callback

	_reward_earned_this_ad = false
	_pending_callback = Callable()

	if callback.is_valid():
		callback.call(earned)

	if _consent_resolved:
		_admob.load_rewarded_ad()  # pré-carrega o próximo
