extends RefCounted

const Cards = preload("res://src/scifi_cards.gd")
const SLOT_COUNT = 5
const DECK_SIZE = 12
var slots: Array = [{}, {}, {}, {}, {}]
var pool: Array = []
var ways: Array = []

static func valid_deck(ids: Variant) -> bool:
	if not ids is Array or ids.size() != DECK_SIZE: return false
	var seen = {}
	for id in ids:
		if not id is String or not Cards.CARDS.has(id) or not Cards.CARDS[id].collectible or seen.has(id): return false
		seen[id] = true
	return true

static func average(ids: Array) -> float:
	var total = 0
	for id in ids: total += Cards.CARDS[id].cost
	return float(total) / maxi(1, ids.size())

func load_file(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var json = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return "卡组库格式无法读取；原文件会保留。"
	var data = json.data
	if not data is Dictionary or data.get("version") != 1 or not data.get("slots") is Array or data.slots.size() != SLOT_COUNT:
		return "卡组库格式无法读取；原文件会保留。"
	var loaded = []
	for slot in data.slots:
		if not slot is Dictionary: return "卡组库包含无效存档位。"
		if not slot.is_empty() and ( not slot.get("name") is String or not valid_deck(slot.get("ids"))):
			return "卡组库包含无效卡组；原文件会保留。"
		loaded.append(slot.duplicate(true))
	slots = loaded
	return ""

func save_slot(path: String, index: int, title: String, ids: Array) -> String:
	if index < 0 or index >= SLOT_COUNT: return "无效的存档位。"
	if not valid_deck(ids): return "请先选满12张不重复的卡牌。"
	var name = title.strip_edges().substr(0, 18)
	if name == "": name = slots[index].get("name", "我的卡组 %d" % (index + 1))
	var next = slots.duplicate(true)
	next[index] = {"name": name, "ids": ids.duplicate()}
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "无法保存卡组，请检查存档目录。"
	file.store_string(JSON.stringify({"version": 1, "slots": next}))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return "卡组写入失败，原卡组未变更。"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")) != OK:
			return "无法备份原卡组，未覆盖存档。"
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error != OK: return "无法完成卡组保存，原卡组未变更。"
	slots = next
	return ""

func load_slot(index: int) -> Array:
	if index < 0 or index >= SLOT_COUNT or slots[index].is_empty(): return []
	return slots[index].ids.duplicate()

func build_counts():
	if not ways.is_empty(): return
	for id in Cards.CARDS:
		if Cards.CARDS[id].collectible: pool.append(id)
	pool.sort()
	var first = []
	for k in range(DECK_SIZE + 1): first.append({})
	first[0][0] = 1.0
	ways.append(first)

	for id in pool:
		var previous = ways.back()
		var row = []
		for k in range(DECK_SIZE + 1):
			var sums = previous[k].duplicate()
			if k > 0:
				for total in previous[k - 1]:
					var next_total = total + Cards.CARDS[id].cost
					sums[next_total] = sums.get(next_total, 0.0) + previous[k - 1][total]
			row.append(sums)
		ways.append(row)

func random_deck(target: float, seed_value: int = 0) -> Dictionary:
	if not is_finite(target): return {}
	build_counts()
	var totals = ways.back()[DECK_SIZE].keys()
	totals.sort()
	var wanted = clampf(target, float(totals.front()) / DECK_SIZE, float(totals.back()) / DECK_SIZE) * DECK_SIZE
	var nearest = int(totals.front())
	for total in totals:
		if absf(total - wanted) < absf(nearest - wanted) - 1e-06: nearest = total
	var random = RandomNumberGenerator.new()
	if seed_value == 0: random.randomize()
	else: random.seed = seed_value
	var remaining = DECK_SIZE
	var total = nearest
	var ids = []

	for n in range(pool.size(), 0, -1):
		if remaining == 0: break
		var id = pool[n - 1]
		var cost = Cards.CARDS[id].cost
		var take = ways[n - 1][remaining - 1].get(total - cost, 0.0)
		var all = ways[n][remaining].get(total, 0.0)
		if take > 0 and (take >= all or random.randf() * all < take):
			ids.append(id)
			remaining -= 1
			total -= cost
	assert (remaining == 0 and total == 0 and valid_deck(ids))
	ids.sort_custom( func(a, b): return a < b if Cards.CARDS[a].cost == Cards.CARDS[b].cost else Cards.CARDS[a].cost < Cards.CARDS[b].cost)
	return {"ids": ids, "requested": target, "average": float(nearest) / DECK_SIZE, "total": nearest}
