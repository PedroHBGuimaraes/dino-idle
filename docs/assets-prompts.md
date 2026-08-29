# Plano de assets visuais — Dino Mobile

Lista completa de prompts pra revisão **antes** de gastar créditos no PixelLab.
Nada foi gerado ainda. Depois de aprovado, seguimos o fluxo da seção
[Ordem de geração](#ordem-de-geração) no final deste arquivo.

## Guia de estilo (aplica a tudo)

| Aspecto | Definição |
|---|---|
| Perspectiva | Retrato/3-quarto frontal (estilo "criatura de coleção" — corpo inteiro, de frente, sem rotação/side-view) |
| Canvas dos dinos | 64×64px, fundo transparente, para todos os 3 estágios da mesma espécie (o crescimento fica na própria arte — a criatura ocupa mais/menos do quadro — e não no tamanho do arquivo) |
| Canvas dos ícones | 32×32px, fundo transparente |
| Canvas do background | 224×400px (bem próximo da proporção do viewport 720×1280 — `create_image_pixflux` exige largura/altura múltiplas de 4 nesse tamanho, então 225 foi ajustado pra 224; o Godot escala/corta minimamente pra tela cheia via `STRETCH_KEEP_ASPECT_COVERED`), opaco |
| Contorno | Linha externa preta, 1px, consistente em todas as peças |
| Nível de detalhe | Pixel art "16-bit / SNES-ish" — nem ultra minimalista (8-bit blocão), nem hiper-detalhado/dithering pesado |
| Paleta | Não fixamos hex antes de gerar — a **primeira peça aprovada define a paleta/estilo de referência**, e as seguintes usam ela como referência de estilo (mecanismo exato de "reference image" do PixelLab a confirmar ao vivo, ver nota no rodapé) |
| Iluminação | Luz vindo de cima-esquerda, sombra simples de 1 tom, sem gradientes complexos |

**Progressão visual por estágio** (aplica às 8 espécies):
- **Filhote**: corpo pequeno e arredondado, proporções "bebê" (cabeça grande em relação ao corpo, olhos grandes), textura simples, pose curiosa/desajeitada.
- **Jovem**: tamanho médio, proporções já mais próximas do adulto, características distintivas da espécie começando a aparecer (chifres/placas/crista menores, ainda em desenvolvimento).
- **Adulto**: tamanho cheio, proporções adultas, todas as características distintivas da espécie completamente desenvolvidas, pose confiante/imponente.

## Dinos (8 espécies × 3 estágios = 24 sprites)

Ordem = curva de custo do jogo (`data/species/*.tres`).

### 1. Compsognathus (`dino_compsognathus_*.png`)
Cor guia: verde-amarelado. Pequeno dinossauro bípede, ágil, corpo esguio, cauda longa, focinho pontudo com dentes pequenos, postura alerta.

- **Filhote**: `Pixel art creature portrait, baby Compsognathus, small round green-yellow bipedal dinosaur, oversized head and eyes, tiny stubby tail, curious wobbly pose, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Compsognathus, lean green-yellow bipedal dinosaur, longer tail, alert posture, sharp small teeth visible, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Compsognathus, sleek agile green-yellow bipedal dinosaur, long balancing tail, sharp teeth, confident predatory stance, full detail, 64x64, transparent background, black outline, clean flat shading`

### 2. Velociraptor (`dino_velociraptor_*.png`)
Cor guia: verde. Bípede penado, corpo magro, garras curvas nas patas, cauda com penas, postura predatória.

- **Filhote**: `Pixel art creature portrait, baby Velociraptor, small fluffy green feathered bipedal dinosaur, oversized head and eyes, short tail, clumsy curious pose, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Velociraptor, lean green feathered bipedal dinosaur, visible curved foot claw, longer feathered tail, alert stance, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Velociraptor, athletic green feathered bipedal raptor, prominent curved sickle claw, feathered tail, predatory hunting stance, full detail, 64x64, transparent background, black outline, clean flat shading`

### 3. Estegossauro (`dino_estegossauro_*.png`)
Cor guia: verde-oliva. Quadrúpede, fileira de placas dorsais, cauda com espinhos (thagomizer), cabeça pequena.

- **Filhote**: `Pixel art creature portrait, baby Stegosaurus, small round olive green quadruped dinosaur, tiny soft back plates, short spikeless tail, big eyes, clumsy pose, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Stegosaurus, olive green quadruped dinosaur, developing row of back plates, small tail spikes forming, sturdier stance, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Stegosaurus, sturdy olive green quadruped dinosaur, full row of large back plates, sharp thagomizer tail spikes, small head, full detail, 64x64, transparent background, black outline, clean flat shading`

### 4. Triceratops (`dino_triceratops_*.png`)
Cor guia: marrom/bege. Quadrúpede robusto, três chifres faciais, grande babado (frill) craniano.

- **Filhote**: `Pixel art creature portrait, baby Triceratops, small round tan-brown quadruped dinosaur, tiny nub horns, small soft frill, big eyes, wobbly stance, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Triceratops, tan-brown quadruped dinosaur, short developing horns, medium frill, sturdier build, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Triceratops, powerful tan-brown quadruped dinosaur, three long sharp facial horns, large bony frill, sturdy muscular build, full detail, 64x64, transparent background, black outline, clean flat shading`

### 5. Parassaurolofo (`dino_parassaurolofo_*.png`)
Cor guia: verde-azulado/teal. Hadrossauro bico-de-pato, crista craniana curva característica.

- **Filhote**: `Pixel art creature portrait, baby Parasaurolophus, small round teal duck-billed dinosaur, tiny nub head crest, big eyes, soft rounded body, curious pose, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Parasaurolophus, teal duck-billed dinosaur, medium curved head crest forming, sturdier legs, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Parasaurolophus, teal duck-billed dinosaur, long curved backward head crest, sturdy bipedal-quadruped stance, full detail, 64x64, transparent background, black outline, clean flat shading`

### 6. Anquilossauro (`dino_anquilossauro_*.png`)
Cor guia: cinza. Quadrúpede baixo, corpo fortemente blindado com placas, cauda em forma de maça.

- **Filhote**: `Pixel art creature portrait, baby Ankylosaurus, small round gray armored quadruped dinosaur, soft small armor bumps, tiny stub tail, big eyes, low stance, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Ankylosaurus, gray armored quadruped dinosaur, developing armor plates, small tail club forming, low sturdy stance, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Ankylosaurus, heavily armored gray quadruped dinosaur, full body armor plates and spikes, large bony tail club, low wide stance, full detail, 64x64, transparent background, black outline, clean flat shading`

### 7. Braquiossauro (`dino_braquiossauro_*.png`)
Cor guia: roxo/violeta. Quadrúpede gigante, pescoço muito longo, cabeça pequena, cauda longa.

- **Filhote**: `Pixel art creature portrait, baby Brachiosaurus, small round purple long-necked quadruped dinosaur, short thick neck, tiny head, big eyes, soft rounded body, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Brachiosaurus, purple long-necked quadruped dinosaur, longer neck forming, sturdier legs, small head, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Brachiosaurus, massive purple long-necked quadruped dinosaur, very long neck held high, tiny head, thick sturdy legs, long tail, full detail, 64x64, transparent background, black outline, clean flat shading`

### 8. Tiranossauro Rex (`dino_trex_*.png`)
Cor guia: vermelho. Bípede predador ápice, cabeça grande, mandíbula poderosa, braços minúsculos, pernas musculosas.

- **Filhote**: `Pixel art creature portrait, baby Tyrannosaurus Rex, small round red bipedal dinosaur, oversized head and eyes, tiny stub arms, wobbly clumsy pose, 64x64, transparent background, black outline, clean flat shading`
- **Jovem**: `Pixel art creature portrait, juvenile Tyrannosaurus Rex, lean red bipedal dinosaur, larger head with visible teeth, small arms, sturdier legs, alert stance, 64x64, transparent background, black outline, clean flat shading`
- **Adulto**: `Pixel art creature portrait, adult Tyrannosaurus Rex, massive powerful red bipedal apex predator dinosaur, huge head with sharp teeth, tiny arms, thick muscular legs and tail, dominant stance, full detail, 64x64, transparent background, black outline, clean flat shading`

## Ícones de UI (6 conceitos → 7 arquivos)

O "som on/off" pedido são 2 estados visuais distintos → 2 arquivos. Todos
32×32, fundo transparente, mesmo estilo de contorno dos dinos.

| Arquivo | Prompt |
|---|---|
| `icon_food.png` | `Pixel art icon, raw meat drumstick/bone, dinosaur food item, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |
| `icon_lock.png` | `Pixel art icon, closed padlock, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |
| `icon_evolve.png` | `Pixel art icon, upward evolution arrow with sparkle, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |
| `icon_ad_play.png` | `Pixel art icon, play button triangle inside a film clapperboard, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |
| `icon_settings.png` | `Pixel art icon, mechanical gear/cog, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |
| `icon_sound_on.png` | `Pixel art icon, speaker with sound waves, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |
| `icon_sound_off.png` | `Pixel art icon, speaker with a crossed-out/muted symbol, simple bold shape, 32x32, transparent background, black outline, clean flat shading` |

## Cenário (1 background)

| Arquivo | Prompt |
|---|---|
| `bg_island.png` | `Pixel art background illustration, lush prehistoric island nest area, ancient palm-like trees, scattered dinosaur eggs in a nest, distant volcanic mountain, warm sunny lighting, soft gradient sky, 720x1280 portrait, no characters, matching color palette of the creature sprites` |

## Nomenclatura e destino final

- Dinos: `assets/dino/dino_<species_id>_<estagio>.png` — `<species_id>` igual ao
  `id` em `data/species/*.tres` (ex. `compsognathus`), `<estagio>` = `filhote`/`jovem`/`adulto`.
- Ícones: `assets/ui/icon_<nome>.png`.
- Background: `assets/scenes/bg_island.png`.
- `assets/placeholder/` é removida depois que os placeholders forem trocados
  pelas peças reais (nenhuma foi trocada ainda).

## Ordem de geração

1. **Peça de referência**: Compsognathus Filhote. Gerado, aprovado por você,
   *só depois* seguimos.
2. Com a referência aprovada: os outros 2 estágios do Compsognathus (mesma
   espécie, usando a referência pra manter o estilo).
3. As outras 7 espécies × 3 estágios, sempre referenciando a primeira peça
   aprovada pra manter o estilo consistente.
4. Ícones: gera 1-2 primeiro (`icon_food`, `icon_lock`), aprova, depois o
   resto.
5. Por último, o background.

## Nota técnica (confirmado nas ferramentas reais)

- Ferramenta usada pra tudo (dinos, ícones, background): `create_image_pixflux`
  (1 crédito/geração — `create_ui_asset`, que parecia boa pros ícones, é na
  verdade pra *painéis* de UI e custa 20-40 créditos/chamada, então não serve
  aqui). `create_image_pro` existe e tem referência de estilo de verdade
  (`style_image_url`), mas custa 20-40 créditos/chamada — reservado só se a
  consistência via `create_image_pixflux` não for boa o suficiente.
- Parâmetros fixos em toda geração: `outline="single color black outline"`,
  `shading="flat shading"`, `detail="medium detail"`, `no_background=True`
  (exceto o background, que é opaco).
- Consistência entre os 3 estágios da **mesma** espécie: uso
  `color_image_url` apontando pra referência aprovada daquela espécie — força
  a mesma paleta de cor exata nos 3 estágios, de graça (0 crédito extra).
- Entre espécies **diferentes**: não força paleta (cada uma tem a cor guia
  própria do plano acima), só repete os mesmos parâmetros de outline/shading/
  detail pra manter a "família visual" consistente.
- Saldo no início desta sessão: 1798 gerações restantes.
- **Import**: PNGs baixados via `curl` direto pra `assets/` não ficam
  utilizáveis em `[ext_resource]`/`preload()` até o Godot gerar o `.import`
  de cada um. A Editor faz isso sozinha em segundo plano (dê um tempo depois
  de adicionar arquivos novos), ou force na hora com
  `godot.exe --headless --editor --quit-after 10 --path <projeto>`.
- **Ícones sem lar na UI ainda**: `icon_settings` e `icon_sound_on/off`
  foram gerados e salvos em `assets/ui/`, mas não há tela de configurações
  nem sistema de áudio no jogo ainda — não inventei essas features só pra
  "usar" os ícones. Ficam prontos pra quando essas telas existirem.
