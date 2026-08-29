# Resumo da sessão — Setup inicial do Dino Mobile

Data: 2026-08-20

## 1. Setup do projeto (Godot 4.6, idle/casual de dinossauros)

**Mecânica implementada:**
- Moeda única `food` (Comida): toque manual + produção passiva/segundo.
- 8 espécies (`Compsognathus` grátis inicial, `Velociraptor`, `Estegossauro`,
  `Triceratops`, `Parassaurolofo`, `Anquilossauro`, `Braquiossauro`,
  `Tiranossauro Rex`), cada uma com **1 único dino**: desbloqueado uma vez
  (`unlock_cost`) e depois evoluído em 3 estágios (Filhote → Jovem → Adulto,
  multiplicadores de produção x1/x3/x8), cada evolução com custo próprio.
  *(Nota: seu pedido mencionou "9 no total" mas listou 8 espécies — implementei
  as 8 listadas; me avise se faltou uma.)*
- Produção offline ao reabrir o app (teto de 8h), popup de "bem-vindo de volta".
- `AdsManager` com interface stub pra futura integração AdMob (sem SDK plugado ainda).
- Visuais 100% placeholder (formas coloridas via `ColorRect`, sem assets de imagem).

**Estrutura de pastas criada:**
```
autoload/        GameManager, SaveManager, SpeciesDatabase, AdsManager
resources/       DinoSpeciesData (Resource data-driven), FoodFormat (util)
data/species/    8x .tres, uma por espécie
scenes/main/     Main.tscn — cena raiz
scenes/dino/     Dino.tscn — visual placeholder reutilizável
scenes/ui/       HUD, ShopPanel, DinoCard, OfflineEarningsPopup
assets/placeholder/  nota de como trocar por arte final depois
```

**Save/Load:** JSON em `user://savegame.json` (não binário), autosave a
cada 30s + em perda de foco/fechar app, cálculo de produção offline no load.

**project.godot:** cena principal (`Main.tscn`), orientação retrato,
viewport 720x1280, autoloads registrados.

**Documentação:** `README.md` completo (mecânica, estrutura, save/load,
como adicionar espécie, passo a passo de export Android).

## 2. Recomendações do plugin `claude-code-setup`

Rodei a skill `claude-automation-recommender` sobre o projeto e recomendei
(depois implementados, exceto o subagente a pedido seu):
MCP servers (Godot MCP, GitHub MCP), skills (`new-species`,
`balance-check`), hooks (format/lint automático, bloqueio de arquivos
sensíveis) e um subagente de balanceamento econômico (não implementado —
você disse que não era necessário por enquanto).

## 3. Ferramentas de qualidade GDScript

- Instalado `gdtoolkit` (`gdformat` + `gdlint`) via `pip install --user`.
- Todos os `.gd` do projeto formatados e sem problemas de lint (corrigi
  ordem de declarações em `DinoCard.gd` e uma linha longa em `SaveManager.gd`).

## 4. Hooks (`.claude/settings.json`)

- **PostToolUse** (Edit/Write): roda `gdformat` + `gdlint` automaticamente
  no arquivo `.gd` editado (`.claude/hooks/format_gd.py`).
- **PreToolUse** (Edit/Write): bloqueia edição de `.godot/`,
  `export_presets.cfg` e `*.keystore`/`*.jks` (`.claude/hooks/guard_paths.py`).
- Ambos testados (pipe-test isolado + chamada real da ferramenta Edit).
- **Pendente da sua parte:** abrir `/hooks` uma vez (ou reiniciar a sessão)
  pra ativar o watcher, já que `.claude/` não existia quando a sessão começou.

## 5. Skills do projeto (`.claude/skills/`)

- **`new-species`**: guia pra adicionar uma nova espécie mantendo a curva
  de custo coerente com as vizinhas.
- **`balance-check`**: script Python (`balance_check.py`) que calcula
  payback e ROI de cada espécie a partir dos `.tres`. Já rodei uma vez nos
  dados atuais — resultado: ROI cai de forma monotônica (Compsognathus/
  Velociraptor ~2-4x mais lucrativos que a mediana; Braquiossauro/T-Rex bem
  abaixo). Não ajustei os números — é uma decisão de balanceamento sua.

## 6. MCP servers

- **GitHub MCP** (oficial, `https://api.githubcopilot.com/mcp/`, HTTP,
  autenticado com um Personal Access Token que você mesmo gerou e rodou o
  comando): ✅ conectado (`claude mcp list` confirma).
  ⚠️ o token completo apareceu no histórico desta sessão porque você rodou
  o comando via `!`; se isso te incomoda, considere revogar e gerar um novo
  em github.com/settings/tokens.
- **Godot MCP**: pesquisei a opção paga (GDAI MCP, US$19, sem trial) e, a
  seu pedido, troquei por uma alternativa **gratuita e open source (MIT)**:
  [`Dokujaa/Godot-MCP`](https://github.com/Dokujaa/Godot-MCP).
  - Plugin da Editor copiado para `addons/godot_mcp/`.
  - Servidor Python copiado para `.claude/mcp-servers/godot-mcp/` (venv
    próprio criado e dependências instaladas).
  - Corrigi um problema real do repositório: o `requirements.txt` original
    pedia `mcp>=0.1.0` sem teto, o que instalava `mcp` 2.0.0 (API
    incompatível, faltava `mcp.server.fastmcp`). Fixei em
    `mcp>=1.2.0,<2.0.0` — com isso o servidor sobe sem erro.
  - Plugin habilitado direto no `project.godot` (seção `[editor_plugins]`),
    sem precisar clicar em Project Settings → Plugins.
  - Registrado no Claude Code: `claude mcp add godot -- <venv_python>
    <server.py>`.
  - **Pendente da sua parte:** reiniciar a Editor do Godot (a que já estava
    aberta) uma vez, pra ela carregar o plugin recém-habilitado e começar a
    escutar na porta 6400. Depois disso o MCP `godot` deve conectar (hoje
    `claude mcp list` ainda mostra "Failed to connect" porque a Editor
    antiga não tem o plugin carregado).
  - Notei também um MCP `godot-ai` (`http://127.0.0.1:8000/mcp`) já
    configurado no seu ambiente, que eu não criei nem toquei — parece ser
    de uma configuração/sessão anterior sua.
- `.gitignore` atualizado para não versionar o `venv/` e `__pycache__/` do
  servidor MCP (são ferramenta de dev, não fazem parte do jogo).

## Pendências / próximos passos seus

1. Abrir `/hooks` (ou reiniciar a sessão) pra ativar os hooks de formatação/proteção.
2. Reiniciar a Editor do Godot pra ativar o plugin `godot_mcp` e o MCP conectar.
3. (Opcional) Revogar/trocar o PAT do GitHub se não quiser ele no histórico da sessão.
4. Confirmar se a lista de espécies deveria ter 9 itens em vez de 8.
5. Decidir se quer rebalancear a curva econômica (ver achado da `balance-check`).
