extends RefCounted

const CARDS = preload("res://src/scifi_cards.gd").CARDS
const CONTINUOUS_DEVICES = ["021", "062", "063", "074", "090", "095", "097", "100", "104", "116", "119"]

static func ids(card: Dictionary, timing: String = "") -> Array:
	var result = []
	for id in [card.id] + card.get("inherited", {}).keys():
		var mode = card.get("inherited", {}).get(id, {}).get("mode", "all") if id != card.id else "all"
		if mode == "continuous" and timing not in ["", "持续"]: continue
		if timing != "" and not CARDS[id].trigger.contains(timing): continue
		result.append(id)
	return result

static func uses(card: Dictionary, id: String) -> Dictionary:
	return card.uses if id == card.id else card.get("inherited", {}).get(id, {}).get("uses", {})

static func has(card: Dictionary, id: String) -> bool:
	return id == card.id or card.get("inherited", {}).has(id)

static func device_ids(card: Dictionary) -> Array:
	var result = []
	for id in ids(card):
		if CARDS[id].device.is_empty(): continue
		if id != card.id and card.inherited[id].mode == "continuous" and id not in CONTINUOUS_DEVICES: continue
		result.append(id)
	return result

static func grant(card: Dictionary, id: String, mode: String, transferred: Dictionary = {}) -> bool:
	if has(card, id): return false
	if not card.has("inherited"): card["inherited"] = {}
	var counters = transferred.duplicate(true)
	if not CARDS[id].device.is_empty() and not counters.has("device_remaining"):
		counters["device_remaining"] = CARDS[id].device.initial_uses
	card.inherited[id] = {"mode": mode, "uses": counters}
	return true

static func copy_continuous(g, card: Dictionary):
	var captured = []
	for side in range(2):
		for lane in range(3):
			for source in g.s.battle.boards[side][lane]:
				if source.uid == card.uid: continue
				for id in ids(source, "持续"):
					if not captured.has(id): captured.append(id)
	g.remember_power()
	for id in captured: grant(card, id, "continuous")
	g.s.battle.logs.append("%s 获得%d种持续技能" % [CARDS[card.id].name, card.get("inherited", {}).size()])

static func text(card: Dictionary, id: String) -> String:
	var value = CARDS[id].text
	if id == card.id or card.inherited[id].mode == "all": return value
	var start = value.find("持续：")
	if start < 0: return ""
	value = value.substr(start)
	for timing in ["揭示：", "主动：", "被动："]:
		var end = value.find(timing)
		if end >= 0: value = value.substr(0, end)
	return value

static func valid(card: Dictionary) -> bool:
	if not card.has("inherited"): return true
	if not card.inherited is Dictionary: return false
	for id in card.inherited:
		var data = card.inherited[id]
		if id == card.id or not CARDS.has(id) or not data is Dictionary or data.get("mode", "") not in ["all", "continuous"] or not data.get("uses") is Dictionary: return false
		if data.mode == "continuous" and not CARDS[id].trigger.contains("持续"): return false
	return true
