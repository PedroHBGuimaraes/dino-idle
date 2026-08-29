extends Node

## Autoload. Dono de toda a áudio do jogo: música de fundo (loop), efeitos
## sonoros (pool de players pra permitir sobreposição — ex. toques rápidos)
## e as preferências de volume/mudo, que o SaveManager persiste.
##
## Sons sintetizados por código (script em docs/gen_sfx.py — não faz parte
## do projeto Godot, não é importado pela Editor) — sem depender de assets
## de terceiros pros SFX. A música é uma faixa royalty-free carregada
## dinamicamente (ver MUSIC_PATH) — se o arquivo não existir, o jogo
## continua funcionando normalmente, só sem música. Detalhes de licença no
## README.md, seção Áudio.

signal muted_changed(muted: bool)
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SFX_POOL_SIZE := 6
const MUSIC_PATH := "res://assets/audio/music/island_theme.ogg"

## Ganho fixo aplicado ao player de música, por cima do volume do barramento
## (que é controlado pelo slider/preferências). Deixa a trilha mais presente
## sem mexer no que o jogador configurou.
const MUSIC_MAKEUP_GAIN_DB := 4.0

## O clique de UI é o SFX mais repetitivo do jogo — toca mais baixo que os
## demais efeitos pra não cansar. Relativo ao volume do barramento SFX.
const CLICK_VOLUME_DB := -8.0

const SFX_TAP := preload("res://assets/audio/sfx/tap.wav")
const SFX_UNLOCK := preload("res://assets/audio/sfx/unlock.wav")
const SFX_EVOLVE := preload("res://assets/audio/sfx/evolve.wav")
const SFX_CLICK := preload("res://assets/audio/sfx/click.wav")
const SFX_POKE := preload("res://assets/audio/sfx/poke.wav")
const SFX_MILESTONE := preload("res://assets/audio/sfx/milestone.wav")

var muted: bool = false
var music_volume: float = 0.7
var sfx_volume: float = 0.8

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = MUSIC_MAKEUP_GAIN_DB
	if ResourceLoader.exists(MUSIC_PATH):
		var stream: AudioStream = load(MUSIC_PATH)
		if stream is AudioStreamOggVorbis:
			# Não confiar no default do importador — força o loop explicitamente.
			stream.loop = true
		_music_player.stream = stream
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_pool.append(player)

	_apply_volumes()


## Toca a música em loop, se ainda não estiver tocando (o loop é forçado
## explicitamente em _ready(), não depende do default do importador).
func play_music() -> void:
	if _music_player.stream != null and not _music_player.playing:
		_music_player.play()


func play_tap() -> void:
	_play(SFX_TAP)


func play_unlock() -> void:
	_play(SFX_UNLOCK)


func play_evolve() -> void:
	_play(SFX_EVOLVE)


func play_click() -> void:
	_play(SFX_CLICK, CLICK_VOLUME_DB)


## Tocado quando o jogador toca um dino específico na lista (reação
## decorativa — ver Dino.gd play_tap_reaction), não a área geral de
## alimentar (play_tap) nem um botão de UI genérico (play_click).
func play_poke() -> void:
	_play(SFX_POKE)


## Tocado quando qualquer dino individual alcança o nível 100 pela primeira
## vez — distinto de play_evolve (que toca em todo level up) pra marcar esse
## momento como mais especial. Ver DinoCard._on_action_pressed().
func play_milestone() -> void:
	_play(SFX_MILESTONE)


func _play(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	player.stream = stream
	# Os players do pool são reaproveitados — sempre reatribui o volume, senão
	# um _play com ganho custom "vaza" pro próximo som que cair nesse player.
	player.volume_db = volume_db
	player.play()


func toggle_muted() -> void:
	set_muted(not muted)


func set_muted(value: bool) -> void:
	muted = value
	_apply_volumes()
	muted_changed.emit(muted)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	music_volume_changed.emit(music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	sfx_volume_changed.emit(sfx_volume)


func _apply_volumes() -> void:
	var music_idx := AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_idx := AudioServer.get_bus_index(SFX_BUS)
	AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(music_idx, muted)
	AudioServer.set_bus_mute(sfx_idx, muted)


## Usado pelo SaveManager pra restaurar as preferências de áudio salvas.
func load_prefs(saved_muted: bool, saved_music_volume: float, saved_sfx_volume: float) -> void:
	muted = saved_muted
	music_volume = saved_music_volume
	sfx_volume = saved_sfx_volume
	_apply_volumes()
	muted_changed.emit(muted)
	music_volume_changed.emit(music_volume)
	sfx_volume_changed.emit(sfx_volume)
