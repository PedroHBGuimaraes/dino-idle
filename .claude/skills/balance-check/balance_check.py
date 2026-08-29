#!/usr/bin/env python3
"""Le todos os .tres em data/species/ e reporta a curva economica do
sistema de niveis (1-100) por especie: producao/ROI em marcos de nivel
(1/25/50/75/100), investimento total pra maximar, E o efeito das passivas
(PassiveEffect) de cada especie — pra ajudar a balancear
unlock_cost/base_production/level_cost_base/passivas.

Uso: python balance_check.py [caminho/para/data/species]
(default: data/species relativo ao diretorio atual)
"""

import re
import statistics
import sys
from pathlib import Path

# Mantenha isso em sincronia com resources/dino_species_data.gd
LEVEL_COST_GROWTH = 1.08
PRODUCTION_GROWTH = 1.045
MAX_LEVEL = 100
CHECKPOINT_LEVELS = (1, 25, 50, 75, 100)
MILESTONES = (25, 50, 75, 100)

# Mantenha isso em sincronia com resources/passive_effect.gd (PassiveEffect.Type)
PASSIVE_TYPE_NAMES = {0: "species", 1: "global", 2: "tap", 3: "synergy", 4: "combo"}

FIELD_RE = re.compile(r"^(\w+)\s*=\s*(.+)$", re.MULTILINE)
SUB_RESOURCE_RE = re.compile(r'\[sub_resource type="Resource" id="(\w+)"\](.*?)(?=\n\[|\Z)', re.DOTALL)
PASSIVE_REF_RE = re.compile(r'passive_(25|50|75|100)\s*=\s*SubResource\("(\w+)"\)')


def parse_tres(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    data = {"_file": path.name}
    for match in FIELD_RE.finditer(text):
        key, raw = match.group(1), match.group(2).strip()
        if key in ("id",):
            data[key] = raw.strip('&"')
        elif key == "display_name":
            data[key] = raw.strip('"')
        elif key == "starts_unlocked":
            data[key] = raw == "true"
        elif key in ("unlock_cost", "base_production", "level_cost_base"):
            data[key] = float(raw)
    data["passives"] = parse_passives(text)
    return data


def parse_passives(text: str) -> dict:
    subresources = {}
    for m in SUB_RESOURCE_RE.finditer(text):
        sub_id, body = m.group(1), m.group(2)
        fields = {fm.group(1): fm.group(2).strip() for fm in FIELD_RE.finditer(body)}
        subresources[sub_id] = {
            "type": PASSIVE_TYPE_NAMES.get(int(fields.get("type", "0")), "species"),
            "value": float(fields["value"]) if "value" in fields else 0.0,
            "threshold_level": int(float(fields.get("threshold_level", "25"))),
            "combo_clicks_per_step": int(float(fields.get("combo_clicks_per_step", "10"))),
            "combo_max_clicks": int(float(fields.get("combo_max_clicks", "200"))),
        }
    passives = {}
    for milestone, sub_id in PASSIVE_REF_RE.findall(text):
        passives[int(milestone)] = subresources.get(sub_id)
    return passives


def own_production_multiplier(passives: dict, at_level: int) -> float:
    return 1.0 + sum(
        p["value"]
        for m, p in passives.items()
        if p and p["type"] == "species" and at_level >= m
    )


def combo_max_bonus(passives: dict) -> float:
    total = 0.0
    for p in passives.values():
        if p and p["type"] == "combo":
            steps = p["combo_max_clicks"] // p["combo_clicks_per_step"]
            total += steps * p["value"]
    return total


def production_at_level(base_production: float, level: int) -> float:
    return base_production * (PRODUCTION_GROWTH ** (level - 1))


def cost_for_level(level_cost_base: float, level: int) -> float:
    if level >= MAX_LEVEL:
        return -1.0
    return level_cost_base * (LEVEL_COST_GROWTH ** (level - 1))


def total_cost_to_level(level_cost_base: float, target_level: int) -> float:
    return sum(cost_for_level(level_cost_base, l) for l in range(1, target_level))


def format_number(n: float) -> str:
    for suffix, threshold in (("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if abs(n) >= threshold:
            return f"{n / threshold:.2f}{suffix}"
    return f"{n:.2f}"


def format_seconds(s: float) -> str:
    if s < 60:
        return f"{s:.0f}s"
    minutes = s / 60
    if minutes < 60:
        return f"{minutes:.1f}min"
    hours = minutes / 60
    if hours < 48:
        return f"{hours:.1f}h"
    return f"{hours / 24:.1f}d"


def main() -> None:
    species_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data/species")
    files = sorted(species_dir.glob("*.tres"))
    if not files:
        print(f"Nenhum .tres encontrado em {species_dir}")
        sys.exit(1)

    rows = []
    for f in files:
        d = parse_tres(f)
        unlock_cost = d.get("unlock_cost", 0.0)
        base_production = d.get("base_production", 0.0)
        level_cost_base = d.get("level_cost_base", 0.0)
        passives = d.get("passives", {})

        own_mult = own_production_multiplier(passives, MAX_LEVEL)
        production_max = production_at_level(base_production, MAX_LEVEL) * own_mult
        total_to_max = total_cost_to_level(level_cost_base, MAX_LEVEL)
        total_invested = unlock_cost + total_to_max
        payback_lvl1 = unlock_cost / base_production if base_production > 0 else float("inf")
        roi_max = production_max / total_invested if total_invested > 0 else float("inf")

        rows.append(
            {
                "id": d.get("id", d["_file"]),
                "display_name": d.get("display_name", "?"),
                "unlock_cost": unlock_cost,
                "base_production": base_production,
                "level_cost_base": level_cost_base,
                "own_mult": own_mult,
                "production_max": production_max,
                "total_to_max": total_to_max,
                "total_invested": total_invested,
                "payback_lvl1": payback_lvl1,
                "roi_max": roi_max,
                "passives": passives,
                "starts_unlocked": d.get("starts_unlocked", False),
            }
        )

    rows.sort(key=lambda r: r["unlock_cost"])

    finite_rois = [r["roi_max"] for r in rows if r["roi_max"] != float("inf")]
    median_roi = statistics.median(finite_rois) if finite_rois else 0.0

    header = (
        f"{'Espécie':<18}{'Unlock':>10}{'Prod@1':>10}"
        f"{'Payback':>10}{'Total@100':>14}{'OwnMult':>9}{'ROI@100':>12}"
    )
    print(header)
    print("-" * len(header))

    outliers = []
    for r in rows:
        roi_str = f"{r['roi_max']:.6f}" if r["roi_max"] != float("inf") else "grátis"
        payback_str = (
            format_seconds(r["payback_lvl1"]) if r["payback_lvl1"] != float("inf") else "grátis"
        )
        print(
            f"{r['display_name']:<18}{format_number(r['unlock_cost']):>10}"
            f"{format_number(r['base_production']):>10}{payback_str:>10}"
            f"{format_number(r['total_invested']):>14}{r['own_mult']:>8.2f}x{roi_str:>12}"
        )

        if median_roi > 0 and r["roi_max"] != float("inf"):
            ratio = r["roi_max"] / median_roi
            if ratio > 2.0 or ratio < 0.5:
                outliers.append((r["display_name"], ratio))

    print()
    print("Passivas por espécie (marco: tipo valor[/parâmetro]):")
    for r in rows:
        parts = []
        for m in MILESTONES:
            p = r["passives"].get(m)
            if not p:
                parts.append(f"{m}:—")
                continue
            if p["type"] == "synergy":
                parts.append(f"{m}:synergy+{p['value']*100:.0f}%@{p['threshold_level']}+")
            elif p["type"] == "combo":
                parts.append(
                    f"{m}:combo+{p['value']*100:.1f}%/{p['combo_clicks_per_step']}clk"
                    f"(max{p['combo_max_clicks']})"
                )
            else:
                parts.append(f"{m}:{p['type']}+{p['value']*100:.0f}%")
        print(f"  {r['display_name']:<18}{'  '.join(parts)}")

    print()
    if outliers:
        print("Possíveis desequilíbrios (ROI@100, já com passiva própria, fora da mediana):")
        for name, ratio in outliers:
            tag = "MUITO LUCRATIVA" if ratio > 1 else "MUITO CARA/FRACA"
            print(f"  - {name}: {ratio:.2f}x a mediana ({tag})")
    else:
        print("Nenhum outlier de ROI encontrado (todas dentro de 0.5x-2x da mediana).")

    # Decadência do ROI marginal (produção ganha por comida gasta) do nível 1
    # pro nível 99 — sinaliza se a curva de custo está crescendo rápido
    # demais em relação à de produção (o problema de "ROI degradante").
    marg1 = (production_at_level(1.0, 2) - production_at_level(1.0, 1)) / cost_for_level(1.0, 1)
    marg99 = (production_at_level(1.0, 100) - production_at_level(1.0, 99)) / cost_for_level(
        1.0, 99
    )
    decay_ratio = marg99 / marg1
    print()
    print(f"Decadência do ROI marginal (nível 1 -> 99): {decay_ratio:.4f}x")
    if decay_ratio < 0.005:
        print(
            "  AVISO: decadência muito severa — níveis tardios praticamente não "
            "compensam. Considere aproximar PRODUCTION_GROWTH de LEVEL_COST_GROWTH."
        )

    # Cenário hipotético "roster inteiro no nível 100" — soma os bônus
    # GLOBAIS (global_production_boost + threshold_synergy, que nesse
    # cenário sempre bate qualquer limiar) de TODAS as espécies, pra
    # verificar que empilhar passivas globais entre as 32 espécies não
    # gera um multiplicador absurdo no fim do jogo.
    total_global_bonus = 0.0
    total_tap_bonus = 0.0
    for r in rows:
        for m, p in r["passives"].items():
            if not p:
                continue
            if p["type"] == "global":
                total_global_bonus += p["value"]
            elif p["type"] == "synergy":
                total_global_bonus += p["value"]  # nível 100 sempre bate o limiar
            elif p["type"] == "tap":
                total_tap_bonus += p["value"]

    print()
    print("Cenário 'roster inteiro (32 espécies) no nível 100':")
    print(
        f"  Multiplicador de produção global acumulado (global+sinergia): "
        f"{1.0 + total_global_bonus:.2f}x"
    )
    print(f"  Multiplicador de toque acumulado (passivo, sem combo): {1.0 + total_tap_bonus:.2f}x")

    # Combo de cliques: só existe se o jogador estiver ativo — reporta o
    # bônus MÁXIMO por espécie (teto de cliques) separado do resto, já que
    # é estritamente um bônus de JOGO ATIVO (idle não ganha nada dele).
    combo_species = [(r["display_name"], combo_max_bonus(r["passives"])) for r in rows]
    combo_species = [(name, bonus) for name, bonus in combo_species if bonus > 0]
    if combo_species:
        total_combo_max = sum(bonus for _, bonus in combo_species)
        print()
        print(
            f"Combo de cliques (só ativo se o jogador estiver tocando sem parar — "
            f"idle não ganha nada disso):"
        )
        for name, bonus in combo_species:
            print(f"  {name}: até +{bonus*100:.0f}% no valor do toque (no teto de cliques)")
        print(
            f"  Total combinado (se todas as {len(combo_species)} espécies-combo "
            f"estiverem maxadas e o jogador manter o combo no teto): "
            f"até +{total_combo_max*100:.0f}% no toque"
        )
        print(
            "  Isso só afeta o toque MANUAL (comida por clique) — a produção passiva "
            "(idle) do jogo não muda nada, então jogo ativo vs. passivo continua "
            "compensando por caminhos diferentes (clique rápido vs. investir em produção)."
        )


if __name__ == "__main__":
    main()
