class_name FoodFormat
extends RefCounted


## Formata quantidades de comida/custos para exibição compacta (1.2K, 3.40M, ...).
static func format(amount: float) -> String:
	var suffixes := ["", "K", "M", "B", "T"]
	var value := amount
	var idx := 0
	while absf(value) >= 1000.0 and idx < suffixes.size() - 1:
		value /= 1000.0
		idx += 1
	if idx == 0:
		return str(int(round(value)))
	return "%.2f%s" % [value, suffixes[idx]]


## Formata taxas de produção (comida/seg) — sempre com 1 casa decimal, em
## qualquer escala, pra não sumir com produções pequenas (ex.: "0.4" em vez
## de arredondar pra "0" e parecer que o dino não está produzindo nada).
static func format_rate(amount: float) -> String:
	var suffixes := ["", "K", "M", "B", "T"]
	var value := amount
	var idx := 0
	while absf(value) >= 1000.0 and idx < suffixes.size() - 1:
		value /= 1000.0
		idx += 1
	return "%.1f%s" % [value, suffixes[idx]]
