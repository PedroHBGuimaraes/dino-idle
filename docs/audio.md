# Áudio — Dino Mobile

## Efeitos sonoros (sintetizados por código)

Os 4 SFX em `assets/audio/sfx/` foram gerados programaticamente (ondas
quadradas simples com envelope de ataque/decay, estilo 8-bit/chiptune) —
sem depender de bibliotecas de áudio de terceiros. Script de geração:
`docs/gen_sfx.py` (usa só `wave`/`struct` da stdlib do Python; rode
`python docs/gen_sfx.py` de dentro de `assets/audio/sfx/` pra regenerar).

| Arquivo | Uso | Desenho sonoro |
|---|---|---|
| `tap.wav` | Toque na área de alimentar | Blip curto de 2 notas agudas (C6→G6), ~0.1s |
| `unlock.wav` | Desbloquear uma espécie | Arpejo de 2 notas ascendente (C5→E5) |
| `evolve.wav` | Evoluir de estágio | Arpejo de 4 notas ascendente (C5→E5→G5→C6) + um "brilho" uma oitava acima na nota final — mais longo/recompensador que os outros, de propósito |
| `click.wav` | Clique genérico de UI (botões de anúncio, fechar popup, configurações) | Blip neutro e baixo, ~0.035s, discreto |

## Onde cada som dispara

- `Main.gd` — `AudioManager.play_tap()` no toque da área principal.
- `DinoCard.gd` — `play_unlock()`/`play_evolve()` só quando a ação
  realmente aconteceu (checa o retorno de `GameManager.unlock_dino()`/
  `evolve_dino()` — não toca em falha, nem durante `load_state()` no
  carregamento do save).
- `HUD.gd`, `OfflineEarningsPopup.gd`, `SettingsPopup.gd` — `play_click()`
  nos botões de ação/fechar.

## Música de fundo

Ver seção "Áudio" do `README.md` para a faixa escolhida, licença e
atribuição (se exigida).

## Volume e mudo

`AudioManager` (autoload) controla dois barramentos de áudio do Godot
(`Music`, `SFX`, ambos filhos de `Master` — ver
`resources/audio/bus_layout.tres`), com volume independente pra cada um e
um mudo geral. Preferências persistem no save (`audio_muted`,
`audio_music_volume`, `audio_sfx_volume`). Acessível pelo botão de
engrenagem no HUD (`SettingsPopup`).
