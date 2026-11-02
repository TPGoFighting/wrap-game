extends RefCounted

const REGIONS = preload("res://src/terrain_catalog.gd").REGIONS

static func initial_state() -> Array:
	var result = []
	for lane in range(3): result.append({"uses": [0, 0], "round_uses": [-1, -1], "end_round": -1, "origins": {}})
	return result

static func select_regions(g) -> Array:
	var result = []
	var has_displacement = false
	for index in g.shuffled(range(REGIONS.size())):
		var displacement = REGIONS[index].effect in ["phase_return", "quarantine"]
		if displacement and has_displacement: continue
		result.append(index)
		has_displacement = has_displacement or displacement
		if result.size() == 3: break
	return result

static func begin_round(g):
	for state in g.s.battle.terrain_state: state.origins.clear()

static func moved(g, card: Dictionary, origin: int, destination: int):
	for lane in range(3):
		if g.region_effect(lane) != "phase_return": continue
		var origins = g.s.battle.terrain_state[lane].origins
		var key = str(card.uid)
		if not origins.has(key) or origins[key].entry != card.get("entry_stamp", 0):
			origins[key] = {"origin": origin, "entry": card.get("entry_stamp", 0), "arrived": false}
		if destination == lane: origins[key].arrived = true

static func cue(g, lane: int, side: int, text: String):
	var name = REGIONS[g.s.battle.regions[lane]].name
	g.s.battle.terrain_events.append({"lane": lane, "side": side, "text": text, "round": g.s.battle.round})
	g.s.battle.logs.append("%s · %s · %s" % [name, "双方" if side < 0 else ("你方" if side == 0 else "敌方"), text])

static func reaction(g, event: Dictionary):
	var lane = event.lane
	var side = event.side
	var state = g.s.battle.terrain_state[lane]

	match event.get("terrain", "none"):
		"salvage":
			if event.kind != "destroyed" or state.uses[side] >= 2: return
			var targets = g.targets(side, [lane], false, event.uid).filter( func(t): return t.card.damage > 0)
			if targets.is_empty(): return
			state.uses[side] += 1
			var healed = g.heal(targets[0].card, 2)
			cue(g, lane, side, "回收 · 修复%d" % healed)
		"shield_retort":
			if event.kind != "shield_lost" or state.round_uses[side] == event.round: return
			var targets = g.targets(1 - side, [lane])
			if targets.is_empty(): return
			state.round_uses[side] = event.round
			g.adjust(targets[0].card, -1, -1)
			cue(g, lane, side, "裂盾 · 减力1")
		"molt_shield":
			if event.kind != "evolved" or event.get("had_shield", false) or state.uses[side] >= 1: return
			var found = g.locate(event.uid)
			if found.is_empty() or found.lane != lane or found.card.get("entry_stamp", 0) != event.entry or found.card.shield: return
			state.uses[side] += 1
			g.grant_shield(found.card)
			cue(g, lane, side, "蜕变 · 护盾")
		"revival_beacon":
			if event.kind != "revived" or state.uses[side] >= 2: return
			var targets = g.targets(side, g.other_lanes(lane), false)
			if targets.is_empty(): return
			state.uses[side] += 1
			g.adjust(targets[0].card, 2, -1)
			cue(g, lane, side, "薪火 · 跨区+2")
		"blood_energy":
			if event.kind != "paid" or event.round >= 6 or state.uses[side] >= 2 or state.round_uses[side] == event.round or g.s.battle.next_energy[side] >= 2: return
			state.uses[side] += 1
			state.round_uses[side] = event.round
			g.s.battle.next_energy[side] += 1
			cue(g, lane, side, "蓄能 · 下回合+1")

static func finish_round(g, lane: int):
	var b = g.s.battle
	if lane >= b.round: return
	var state = b.terrain_state[lane]
	if state.end_round == b.round: return
	state.end_round = b.round
	var targets = []
	match g.region_effect(lane):
		"phase_return":
			for side in range(2):
				for card in b.boards[side][lane]:
					var trip = state.origins.get(str(card.uid), {})
					if not trip.is_empty() and trip.arrived and trip.entry == card.get("entry_stamp", 0) and trip.origin != lane:
						targets.append({"uid": card.uid, "side": side, "entry": card.get("entry_stamp", 0), "destination": trip.origin})
			for target in targets:
				var live = g.locate(target.uid)
				if live.is_empty() or live.lane != lane or live.card.get("entry_stamp", 0) != target.entry: continue
				if g.move_card(target.uid, target.destination, target.side): cue(g, lane, target.side, "相位返程")
		"cold_parts":
			if b.round != 4: return
			for side in range(2):
				var eligible = g.targets(side, [lane]).filter( func(t): return g.recharge_eligible(t.card))
				eligible.sort_custom( func(a, c): return a.order < c.order if g.device_remaining(a.card) == g.device_remaining(c.card) else g.device_remaining(a.card) < g.device_remaining(c.card))
				if not eligible.is_empty(): targets.append(eligible[0])
			for target in targets:
				g.recharge(target.card, 1)
				cue(g, lane, target.side, "备件 · 重启1")
		"pulse_storm":
			if b.round < 4: return
			for side in range(2): targets.append_array(g.targets(side, [lane]))
			for target in targets: g.adjust(target.card, -1, -1)
			if not targets.is_empty(): cue(g, lane, -1, "脉冲 · 全体减力1")
		"quarantine":
			if b.round != 5: return
			for side in range(2):
				if b.hands[side].size() >= 8: continue
				var eligible = g.targets(side, [lane]).filter( func(t): return g.CARDS[t.card.id].cost <= 2)
				eligible.sort_custom( func(a, c): return a.order < c.order if g.CARDS[a.card.id].cost == g.CARDS[c.card.id].cost else g.CARDS[a.card.id].cost < g.CARDS[c.card.id].cost)
				if not eligible.is_empty(): targets.append(eligible[0])
			for target in targets:
				g.recall(target.uid, target.side)
				cue(g, lane, target.side, "检疫 · 返回手牌")

static func status(g, lane: int) -> String:
	var b = g.s.battle
	if lane >= b.round: return "第%d回合生效" % (lane + 1)
	var state = b.terrain_state[lane]
	match g.region_effect(lane):
		"salvage", "revival_beacon", "blood_energy", "molt_shield":
			var limit = 1 if g.region_effect(lane) == "molt_shield" else 2
			return "剩余 · 你方%d次 / 敌方%d次" % [limit - state.uses[0], limit - state.uses[1]]
		"shield_retort": return "本回合 · 你方%s / 敌方%s" % ["已用" if state.round_uses[0] == b.round else "可用", "已用" if state.round_uses[1] == b.round else "可用"]
		"cold_parts", "quarantine":
			var turn = 4 if g.region_effect(lane) == "cold_parts" else 5
			return "本局已结算" if state.end_round >= turn else "第%d回合结束触发" % turn
		"pulse_storm": return "本轮脉冲已结算" if state.end_round == b.round and b.round >= 4 else ("本回合结束触发" if b.round >= 4 else "第4回合起，每回合触发")
		"phase_return": return "回合结束返程 · 空位不足则留场"
		"gravity_scales": return "所有单位技能仍生效"
	return "持续生效 · 双方共用规则"

static func tooltip(g, lane: int) -> String:
	var data = REGIONS[g.s.battle.regions[lane]]
	return data.name + "  /  " + data.id + "\n" + data.desc + "\n" + status(g, lane) + ("\n\n" + "\n".join(data.notes) if not data.notes.is_empty() else "")

static func ai_value(g, side: int) -> float:

	var value = 0.0
	var b = g.s.battle
	for lane in range(3):
		var effect = g.region_effect(lane)
		var state = b.terrain_state[lane]
		var area = g.targets(side, [lane])
		match effect:
			"pulse_storm":
				if b.round < 4: continue
				for target in area:
					if g.immune_to_weaken(target.card): continue
					value -= 0.25 if target.card.shield else (2.5 if target.power <= 1 and not g.has_skill(target.card, "049") and not g.has_skill(target.card, "050") else 0.7)
			"cold_parts":
				if b.round <= 4 and area.any( func(t): return g.recharge_eligible(t.card) and g.device_remaining(t.card) == 0): value += 1.0
			"molt_shield":
				if state.uses[side] == 0 and area.any( func(t): return not g.CARDS[t.card.id].evolution.is_empty() and not t.card.shield): value += 0.7
			"shield_retort":
				if state.round_uses[side] != b.round and not b.boards[1 - side][lane].is_empty() and area.any( func(t): return t.card.shield): value += 0.65
			"salvage":
				if state.uses[side] < 2 and area.size() > 1 and area.any( func(t): return t.card.damage > 0): value += 0.5
			"revival_beacon":
				if state.uses[side] < 2 and g.occupied_lanes(side) > 1 and area.any( func(t): return t.card.id in ["021", "062", "068", "071"]): value += 0.65
			"blood_energy":
				if b.round < 6 and state.uses[side] < 2 and area.any( func(t): return t.card.id in ["092", "096", "101", "114", "117"]): value += 0.6
			"quarantine":
				if b.round != 5 or b.hands[side].size() >= 8: continue
				var eligible = area.filter( func(t): return g.CARDS[t.card.id].cost <= 2)
				eligible.sort_custom( func(a, c): return a.order < c.order if g.CARDS[a.card.id].cost == g.CARDS[c.card.id].cost else g.CARDS[a.card.id].cost < g.CARDS[c.card.id].cost)
				if not eligible.is_empty(): value += 1.5 - eligible[0].power * 0.8
			"phase_return":
				for target in area:
					var trip = state.origins.get(str(target.uid), {})
					if not trip.is_empty() and trip.arrived and trip.entry == target.card.get("entry_stamp", 0) and trip.origin != lane and g.room(side, trip.origin) and g.can_be_moved(target.uid, side):
						var needs_help = g.score(side, trip.origin) <= g.score(1 - side, trip.origin)
						value += 0.5 if needs_help else -0.8
	return value

static func valid_state(b: Dictionary) -> bool:
	if b.has("terrain_art"):
		if not b.terrain_art is Array or b.terrain_art.size() != 3: return false
		var art_ids = b.terrain_art.duplicate()
		art_ids.sort()
		if art_ids != [0, 1, 2]: return false
	if not b.has("terrain_state"): return true
	if not b.terrain_state is Array or b.terrain_state.size() != 3: return false
	for state in b.terrain_state:
		if not state is Dictionary or not state.get("origins") is Dictionary or not state.get("end_round") is int: return false
		for key in ["uses", "round_uses"]:
			if not state.get(key) is Array or state[key].size() != 2 or not state[key].all( func(n): return n is int): return false
		if state.uses.any( func(n): return n < 0 or n > 2): return false
		for key in state.origins:
			var trip = state.origins[key]
			if not trip is Dictionary or trip.get("origin", -1) not in [0, 1, 2] or not trip.get("entry") is int or not trip.get("arrived") is bool: return false
	if b.has("terrain_events"):
		if not b.terrain_events is Array: return false
		for event in b.terrain_events:
			if not event is Dictionary or event.get("lane", -1) not in [0, 1, 2] or not event.get("text") is String or event.get("side", -2) not in [-1, 0, 1] or not event.get("round") is int: return false
	return true
