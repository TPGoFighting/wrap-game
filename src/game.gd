extends RefCounted

const CARDS = preload("res://src/scifi_cards.gd").CARDS
const Effects = preload("res://src/scifi_effects.gd")
const STARTER = ["001", "003", "005", "008", "011", "017", "025", "027", "034", "040", "048", "061"]
const Data = preload("res://src/scifi_cards.gd")
const Balance = preload("res://src/balance_effects.gd")
const Reactions = preload("res://src/reaction_effects.gd")
const MONSTERS = Data.ALIENS
const Skills = preload("res://src/skill_rules.gd")
const Terrain = preload("res://src/terrain_rules.gd")
const REGIONS = Terrain.REGIONS
const Roster = preload("res://src/enemy_roster.gd")
var rng = RandomNumberGenerator.new()
var s: Dictionary = {}
var last_events: Array = []
var actor = -1
var reacting = false
var resolving = false
var pending: Array = [[], []]
var terrain_cue_cursor = 0
var skill_context = {}

func skill_ids(card: Dictionary, timing: String = "") -> Array:
	return Skills.ids(card, timing)

func has_skill(card: Dictionary, ability: String) -> bool:
	return Skills.has(card, ability)

func skill_id(card: Dictionary) -> String:
	return skill_context.get(str(card.uid), card.id)

func skill_uses(card: Dictionary) -> Dictionary:
	return Skills.uses(card, skill_id(card))

func push_skill(card: Dictionary, ability: String) -> String:
	var key = str(card.uid)
	var previous = skill_context.get(key, "")
	skill_context[key] = ability
	return previous

func pop_skill(card: Dictionary, previous: String):
	if previous == "": skill_context.erase(str(card.uid))
	else: skill_context[str(card.uid)] = previous

func collectible_ids() -> Array:
	var result = []
	for id in CARDS:
		if CARDS[id].collectible: result.append(id)
	return result

func validate_deck(deck: Array) -> String:
	if deck.size() != 12: return "请选择12张牌出战。"
	var seen = {}
	for id in deck:
		if not CARDS.has(id) or not CARDS[id].collectible: return "初始牌组只能选择卡池中的121张牌。"
		if seen.has(id): return "初始牌组不能包含重复卡牌。"
		seen[id] = true
	return ""

func new_run(seed_value: int = 0, deck: Array = []) -> bool:
	var chosen = STARTER.duplicate() if deck.is_empty() else deck.duplicate()
	if validate_deck(chosen) != "": return false
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	s = {"version": 7, "phase": "map", "stage": 0, "lives": 3, "deck": chosen, "rewards": [], "chosen": "", "battle": {}, "result": {}, "next_uid": 1, "opponents": []}
	var enemies = Roster.PROFILES.keys()
	for stage in range(3): s.opponents.append(enemies[rng.randi_range(0, enemies.size() - 1)])
	last_events.clear()
	return true

func enemy_for_stage(index: int = -1) -> Dictionary:
	if index < 0: index = int(s.get("stage", 0))
	var lineup = s.get("opponents", Roster.LEGACY)
	var id = lineup[index]
	var enemy = Roster.PROFILES[id].duplicate(true)
	enemy["id"] = id
	enemy["title"] = Roster.TITLES[index]
	return enemy

func instance(id: String) -> Dictionary:
	assert (CARDS.has(id))
	var uid = int(s.get("next_uid", 1))
	s["next_uid"] = uid + 1
	var uses = {}
	if not CARDS[id].device.is_empty(): uses["device_remaining"] = CARDS[id].device.initial_uses
	return {"id": id, "uid": uid, "bonus": 0, "damage": 0, "cost_delta": 0, "shield": false, "uses": uses, "played_round": -1, "origin_lane": -1, "entry_stamp": 0}

func shuffled(items: Array) -> Array:
	var out = items.duplicate(true)
	for i in range(out.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var item = out[i]
		out[i] = out[j]
		out[j] = item
	return out

func begin_battle():
	if s.phase != "map": return
	s.battle = {"round": 0, "hands": [[], []], "draws": [[], []], "boards": [[[], [], []], [[], [], []]], "energy": [0, 0], "next_energy": [0, 0], "queue": [], "enemy_plan": [], "regions": Terrain.select_regions(self), "logs": [], "grave": [[], []], "revivals": [], "peeked": [[], []], "played": [[], []]}
	terrain_cue_cursor = 0
	s.battle["terrain_art"] = shuffled([0, 1, 2])
	ensure_state()
	for id in s.deck: s.battle.draws[0].append(instance(id))
	for id in enemy_for_stage().deck: s.battle.draws[1].append(instance(id))
	for side in range(2):
		s.battle.draws[side] = shuffled(s.battle.draws[side])

		for i in range(s.battle.draws[side].size() - 1, -1, -1):
			if CARDS[s.battle.draws[side][i].id].get("innate", false): s.battle.hands[side].append(s.battle.draws[side].pop_at(i))
		while s.battle.hands[side].size() < 3 and draw_card(side): pass
	s.phase = "battle"
	s.battle.logs.append("遭遇" + enemy_for_stage().name + " · " + enemy_for_stage().archetype)
	begin_round()

func draw_card(side: int) -> bool:
	var b = s.battle
	if b.hands[side].size() >= 8 or b.draws[side].is_empty(): return false
	b.hands[side].append(b.draws[side].pop_back())
	return true

func begin_round():
	var b = s.battle
	remember_power()
	b.round += 1
	Terrain.begin_round(self)
	b.queue = []
	b.enemy_plan = []
	b.played = [[], []]
	b.weaken_boost = [0, 0]
	for side in range(2):
		b.energy[side] = b.round + mini(2, b.next_energy[side])
		b.next_energy[side] = 0
		draw_card(side)

	flush_reactions()
	ai_active_moves(1)
	b.enemy_plan = plan_ai(1, s.stage)
	b.logs.append("第 %d 回合 · %s先揭示" % [b.round, "你方" if b.round % 2 == 1 else "敌方"])

func card_cost(card: Dictionary) -> int:
	return maxi(0, CARDS[card.id].cost + int(card.get("cost_delta", 0)))

func raw_power(card: Dictionary) -> int:
	return maxi(0, int(card.get("base_power", CARDS[card.id].power)) + card.bonus - card.get("damage", 0))

func queued_cost() -> int:
	var value = 0
	for move in s.battle.queue: value += card_cost(move.card)
	return value

func available_energy() -> int:
	return s.battle.energy[0] - queued_cost()

func queued_at(lane: int, side: int = 0) -> int:
	var value = 0
	var plans = pending[side] if resolving else (s.battle.queue if side == 0 else s.battle.enemy_plan)
	for move in plans:
		if move.lane == lane: value += 1
	return value

func room(side: int, lane: int) -> bool:
	return lane >= 0 and lane < 3 and s.battle.boards[side][lane].size() + queued_at(lane, side) < 4

func queue_card(index: int, lane: int) -> String:
	if s.phase != "battle" or resolving: return "当前不能部署。"
	if lane < 0 or lane >= 3 or index < 0 or index >= s.battle.hands[0].size(): return "请选择有效卡牌和战区。"
	var card = s.battle.hands[0][index]
	if card_cost(card) > available_energy(): return "能量不足。"
	if not room(0, lane): return "这个战区已经满员。"
	s.battle.hands[0].remove_at(index)
	s.battle.queue.append({"card": card, "lane": lane, "index": index})
	return ""

func undo() -> bool:
	if s.phase != "battle" or resolving or s.battle.queue.is_empty(): return false
	var move = s.battle.queue.pop_back()
	s.battle.hands[0].insert(mini(move.index, s.battle.hands[0].size()), move.card)
	return true

func region_effect(lane: int) -> String:
	return REGIONS[s.battle.regions[lane]].effect if lane < s.battle.round else "none"

func card_power(side: int, lane: int, index: int) -> int:
	var b = s.battle
	var area = b.boards[side][lane]
	var card = area[index]
	var value = int(card.get("base_power", CARDS[card.id].power)) + card.bonus - card.damage
	for ability in skill_ids(card, "持续"):
		match ability:
			"012":
				if area.size() == 2: value += 2
			"025":
				value += area.size() - 1
			"028":
				if area.size() == 4: value += 4
			"036":
				var vanilla = 0
				for row in b.boards[side]:
					for ally in row:
						if CARDS[ally.id].effect == "none": vanilla += 1
				value += mini(3, vanilla) * 2
			"054":
				if occupied_lanes(side) == 3: value += 7
			"084":
				if b.boards[1 - side][lane].size() > area.size(): value += 3
			"091":
				var grown = 0
				for ally in area:
					if ally.uid != card.uid and ally.uses.get("evolved", 0) > 0: grown += 1
				value += mini(2, grown) * 2
	for k in range(3):
		for ally in b.boards[side][k]:
			if has_skill(ally, "010"): value += 2 if CARDS[card.id].group == "fleet" else 1
			if has_skill(ally, "111") and card.shield: value += 2 if k == lane else 1
			if ally.uid == card.uid: continue
			if has_skill(ally, "024") and CARDS[card.id].cost == 1: value += 1
			if has_skill(ally, "051") and k == lane: value += 1
	match region_effect(lane):
		"small":
			if card_cost(card) == 1: value += 2
		"large":
			if card_cost(card) >= 4: value += 3
		"all": value += 1
		"weak":
			if not immune_to_weaken(card): value -= 1
	value = maxi(0, value)
	if region_effect(lane) == "solo" and area.size() == 1: value *= 2
	return value

func score(side: int, lane: int) -> int:
	var value = 0
	var powers = []
	for index in range(s.battle.boards[side][lane].size()): powers.append(card_power(side, lane, index))
	if region_effect(lane) == "gravity_scales":
		powers.sort()
		powers.reverse()
		powers = powers.slice(0, 2)
	for power in powers: value += power
	if region_effect(lane) == "full" and s.battle.boards[side][lane].size() == 4: value += 5
	return value

func locate(uid: int) -> Dictionary:
	for side in range(2):
		for lane in range(3):
			for index in range(s.battle.boards[side][lane].size()):
				var card = s.battle.boards[side][lane][index]
				if card.uid == uid: return {"side": side, "lane": lane, "index": index, "card": card}
	return {}

func targets(side: int, lanes: Array, high: bool = true, exclude: int = -1, movable_by: int = -1) -> Array:
	var out = []
	for lane in lanes:
		for index in range(s.battle.boards[side][lane].size()):
			var card = s.battle.boards[side][lane][index]
			if card.uid == exclude or (movable_by >= 0 and not can_be_moved(card.uid, movable_by)): continue
			out.append({"side": side, "lane": lane, "index": index, "card": card, "uid": card.uid, "power": card_power(side, lane, index), "order": lane * 4 + index})
	out.sort_custom( func(a, b): return a.order < b.order if a.power == b.power else (a.power > b.power if high else a.power < b.power))
	return out

func other_lanes(lane: int, adjacent: bool = false) -> Array:
	var out = []
	for k in range(3):
		if k != lane and ( not adjacent or absi(k - lane) == 1): out.append(k)
	return out

func hand_targets(side: int, high: bool = false, original: bool = false) -> Array:
	var out = []
	for index in range(s.battle.hands[side].size()):
		var card = s.battle.hands[side][index]
		out.append({"card": card, "index": index, "cost": CARDS[card.id].cost if original else card_cost(card)})
	out.sort_custom( func(a, b): return a.index < b.index if a.cost == b.cost else (a.cost > b.cost if high else a.cost < b.cost))
	return out

func adjust(card: Dictionary, amount: int, actor_override: int = -2) -> bool:
	var responsible = actor if actor_override == -2 else actor_override
	remember_power()
	if amount < 0:
		if immune_to_weaken(card): return false
		var found = locate(card.uid)
		if not found.is_empty() and responsible == 1 - found.side: amount -= s.battle.get("weaken_boost", [0, 0])[responsible]
		if card.shield:
			remove_shield(card, "weaken", responsible)
			return false
		card.damage += - amount
		if not found.is_empty():
			s.battle.zero_causes[str(card.uid)] = responsible
			emit_event("weakened", card, found.side, found.lane, {"actor": responsible, "amount": - amount})
	else: card.bonus += amount
	return true

func immune_to_weaken(card: Dictionary) -> bool:
	return has_skill(card, "017")

func weaken(side: int, lanes: Array, amount: int, limit: int = 1):
	var chosen = targets(side, lanes).slice(0, limit)
	for target in chosen: adjust(target.card, - amount)

func buff_area(side: int, lanes: Array, amount: int, exclude: int = -1):
	for target in targets(side, lanes, true, exclude): adjust(target.card, amount)

func summon(side: int, lane: int, id: String) -> bool:
	if not room(side, lane): return false
	var card = instance(id)
	card.entry_stamp = next_entry_stamp()
	s.battle.boards[side][lane].append(card)
	emit_event("summoned", card, side, lane)
	return true

func destroy(uid: int, by_side: int, zero_power: bool = false) -> bool:
	var found = locate(uid)
	if found.is_empty(): return false
	var card = found.card
	if has_skill(card, "049") or has_skill(card, "050"): return false
	if card.shield and not zero_power:
		remove_shield(card, "destroy", by_side)
		return false
	remember_power()
	emit_event("destroyed", card, found.side, found.lane, {"actor": by_side})
	card["destroyed_lane"] = found.lane
	s.battle.boards[found.side][found.lane].remove_at(found.index)
	s.battle.grave[found.side].append(card)
	s.battle.power_watch.erase(str(uid))
	s.battle.zero_causes.erase(str(uid))
	cancel_tracking(uid)
	s.battle.logs.append("%s 被摧毁" % CARDS[card.id].name)
	return true

func grave_target(side: int, maximum: int = 99) -> int:
	var best = -1
	var cost = 999
	for i in range(s.battle.grave[side].size()):
		var value = CARDS[s.battle.grave[side][i].id].cost
		if value <= maximum and value < cost:
			best = i
			cost = value
	return best

func reset_modifiers(card: Dictionary):
	card.bonus = 0
	card.damage = 0
	card.cost_delta = 0
	card.shield = false
	card.played_round = -1
	card.origin_lane = -1
	card.erase("base_power")
	s.battle.revivals.erase(card.uid)

func revive(side: int, index: int, lane: int, power: int = -1, preserve: bool = false) -> bool:
	if index < 0 or index >= s.battle.grave[side].size() or not room(side, lane): return false
	var card = s.battle.grave[side].pop_at(index)
	if not preserve: reset_modifiers(card)
	if power >= 0: card["base_power"] = power
	card.entry_stamp = next_entry_stamp()
	s.battle.boards[side][lane].append(card)
	mark_history(side, "revived", card.uid)
	emit_event("revived", card, side, lane)
	s.battle.logs.append("%s 重返战场" % CARDS[card.id].name)
	return true

func move_card(uid: int, lane: int, by_side: int) -> bool:
	var found = locate(uid)
	if found.is_empty() or found.lane == lane or not room(found.side, lane) or not can_be_moved(uid, by_side): return false
	remember_power()
	s.battle.boards[found.side][found.lane].remove_at(found.index)
	s.battle.boards[found.side][lane].append(found.card)
	mark_moved(found.card, found.side, found.lane, lane)
	return true

func active_ids(card: Dictionary) -> Array:
	return skill_ids(card, "主动").filter( func(id): return id in Balance.ACTIVE or id == "077")

func move_skill(card: Dictionary) -> String:
	for id in active_ids(card):
		if id in Balance.SELF_MOVE: return id
	return ""

func can_activate(uid: int, ability: String = "") -> bool:
	var found = locate(uid)
	if found.is_empty() or resolving or not s.battle.get("choice", {}).is_empty(): return false
	var card = found.card
	if card.uses.get("active_round", -1) == s.battle.round: return false
	for id in active_ids(card):
		if ability != "" and id != ability: continue
		var counters = Skills.uses(card, id)
		if counters.get("active_round", -1) == s.battle.round: continue
		if CARDS[id].device.is_empty() or device_remaining(card, id) > 0: return true
	return false

func activate(uid: int, side: int = 0, ability: String = "") -> String:
	var found = locate(uid)
	if s.phase != "battle" or found.is_empty() or found.side != side or not can_activate(uid, ability): return "技能不可用或本回合已使用。"
	if ability == "":
		for id in active_ids(found.card):
			if can_activate(uid, id): ability = id;break
	actor = side
	var previous = push_skill(found.card, ability)
	var worked = Balance.active(self, side, found.lane, found.card)
	if worked: finish_active(found.card)
	pop_skill(found.card, previous)
	if not worked: return "没有符合条件的目标。"
	flush_reactions()
	return ""

func finish_active(card: Dictionary):
	card.uses["active_round"] = s.battle.round
	skill_uses(card)["active_round"] = s.battle.round
	if not CARDS[skill_id(card)].device.is_empty(): spend_device(card)

func manual_move(uid: int, lane: int, gate_uid: int = -1, side: int = 0) -> String:
	if s.phase != "battle" or resolving or not s.battle.get("choice", {}).is_empty(): return "当前不能移动。"
	var found = locate(uid)
	if found.is_empty(): return "请选择场上的单位。"
	var source = found
	if gate_uid >= 0:
		source = locate(gate_uid)
		if source.is_empty() or source.side != side: return "请选择场上的单位。"
		if source.card.id not in ["049", "055"]: return "这张牌不能调度单位。"
		if source.card.id == "049" and found.side != side: return "星门只能调度友军。"
	elif found.side != side or move_skill(found.card) == "": return "这张牌没有主动移动。"
	var ability = source.card.id if gate_uid >= 0 else move_skill(source.card)
	if not can_activate(source.card.uid, ability): return "次数已用完或本回合已使用。"
	actor = side
	var origin = found.lane
	if not move_card(uid, lane, side): return "目标区域已满，或卡牌无法移动。"
	var previous = push_skill(source.card, ability)
	finish_active(source.card)
	if gate_uid >= 0: source.card.uses["gate"] = source.card.uses.get("gate", 0) + 1
	elif ability == "016": adjust(source.card, 1)
	elif ability == "064": revive(side, grave_target(side), origin)
	pop_skill(source.card, previous)
	flush_reactions()
	return ""

func board_value(side: int) -> float:
	var value = 0.0
	for lane in range(3):
		var own = score(side, lane)
		var opponent = score(1 - side, lane)
		value += own - opponent
		if own > opponent: value += 5.0
		elif own < opponent: value -= 5.0
	return value

func strategic_value(side: int) -> float:
	return board_value(side) + Terrain.ai_value(self, side) - Terrain.ai_value(self, 1 - side)

func ai_active_moves(side: int):
	for target in targets(side, [0, 1, 2]):
		if can_reboot(target.uid) and device_remaining(target.card) == 0:
			var useful = not targets(1 - side, [0, 1, 2]).is_empty() if target.card.id == "114" else room(side, target.lane)
			if useful: reboot(target.uid, side)
	for attempt in range(8):
		var original = s
		var random_state = rng.state
		var best = strategic_value(side) + 0.25
		var choice = {}
		var options = []
		for target in targets(side, [0, 1, 2]):
			if not can_activate(target.uid): continue
			if target.card.id in ["049", "055"]:
				var units = targets(side, [0, 1, 2])
				if target.card.id == "055": units.append_array(targets(1 - side, [0, 1, 2]))
				for ally in units:
					for lane in other_lanes(ally.lane): options.append({"uid": ally.uid, "lane": lane, "gate": target.uid})
			elif target.card.id == "077":
				for ally in targets(side, other_lanes(target.lane)):
					if CARDS[ally.card.id].effect == "none": options.append({"uid": target.uid, "swap": ally.uid})
			elif move_skill(target.card) != "":
				for lane in other_lanes(target.lane): options.append({"uid": target.uid, "lane": lane, "gate": -1})
			for ability in active_ids(target.card):
				if ability not in Balance.SELF_MOVE and ability not in ["049", "055", "077"] and can_activate(target.uid, ability):
					options.append({"uid": target.uid, "active": true, "ability": ability})
		for option in options:
			s = original.duplicate(true)
			rng.state = random_state
			var error = apply_ai_action(option, side)
			if error == "":
				var value = strategic_value(side) + (s.battle.hands[side].size() - original.battle.hands[side].size()) * 1.5 + (s.battle.energy[side] - original.battle.energy[side]) * 2
				if value > best:
					best = value
					choice = option
		s = original
		rng.state = random_state
		if choice.is_empty(): break
		apply_ai_action(choice, side)

func apply_ai_action(option: Dictionary, side: int) -> String:
	if option.has("active"): return activate(option.uid, side, option.get("ability", ""))
	if option.has("swap"): return swap_units(option.uid, option.swap, side)
	return manual_move(option.uid, option.lane, option.gate, side)

func plan_ai(side: int, difficulty: int) -> Array:
	var original = s
	var work = s.duplicate(true)
	var moves = []
	var budget = s.battle.energy[side]
	while true:
		var best = - INF
		var chosen = {}
		for index in range(work.battle.hands[side].size()):
			var card = work.battle.hands[side][index]
			if card_cost(card) > budget: continue
			for lane in range(3):
				s = work.duplicate(true)
				if s.battle.boards[side][lane].size() >= 4: continue
				if card.id == "058" and s.battle.boards[side][lane].is_empty(): continue
				var before = strategic_value(side)
				var candidate = s.battle.hands[side].pop_at(index)
				s.battle["spent"] = s.battle.get("spent", [0, 0]).duplicate()
				s.battle.spent[side] = s.battle.energy[side] - budget + card_cost(candidate)
				candidate.entry_stamp = next_entry_stamp()
				s.battle.boards[side][lane].append(candidate)
				Effects.reveal(self, side, lane, candidate)
				var live = locate(candidate.uid)
				if not live.is_empty(): Effects.finish_card(self, side, live.lane, candidate)
				var value = strategic_value(side) - before + card_cost(card) * 0.18 + rng.randf_range(0.0, 1.6 - float(difficulty) * 0.35)
				if moves.any( func(move): return move.card.id == "061"): value -= 2 * card_cost(card)
				if card.id == "048" and s.battle.round < 6:
					value += 5
					for held in work.battle.hands[side]:
						if card_cost(held) >= 7: value += 9
				if not CARDS[card.id].evolution.is_empty() and s.battle.round <= 5: value += 2.5
				if card.id in ["005", "014", "035", "109"] and s.battle.round < 6: value += 1.5
				if card.id in ["009", "030"]: value += 2
				if card.id in ["033", "059"]: value += 1.5

				var area = s.battle.boards[side][lane]
				if card.id == "052": value += mini(2, 4 - area.size()) * 1.5
				if card.id == "053" and area.size() > 1: value += mini(3, 7 - s.battle.round) * 0.65
				if card.id == "057" and s.battle.round < 6: value += mini(3, 4 - area.size()) * 0.6
				if value > best:
					best = value
					chosen = {"index": index, "lane": lane, "card": card.duplicate(true)}
		if chosen.is_empty() or best <= 0: break
		budget -= card_cost(chosen.card)
		work.battle.hands[side].remove_at(chosen.index)
		work.battle.boards[side][chosen.lane].append(chosen.card.duplicate(true))
		moves.append({"card": chosen.card, "lane": chosen.lane})
	s = original
	return moves

func resolve_turn(record_events: bool = false, interactive: bool = false):
	if s.phase != "battle" or resolving: return
	ensure_state()
	last_events.clear()
	terrain_cue_cursor = s.battle.terrain_events.size()
	var b = s.battle
	var plans = [b.queue.duplicate(true), b.enemy_plan.duplicate(true)]
	b["spent"] = [0, 0]
	b.played = [[], []]
	b.weaken_boost = [0, 0]
	for side in range(2):
		for move in plans[side]:
			b.spent[side] += card_cost(move.card)
			b.played[side].append(move.lane)
	for move in plans[1]:
		for i in range(b.hands[1].size()):
			if b.hands[1][i].uid == move.card.uid:
				b.hands[1].remove_at(i)
				break
	b["resolution"] = {"plans": plans, "order": [0, 1] if b.round % 2 == 1 else [1, 0], "side_index": 0, "stage": "reveal", "record": record_events, "interactive": interactive, "end_ids": [], "growth_ids": []}
	resolving = true
	advance_resolution()

func presentation_board() -> Dictionary:
	var out = {}
	for side in range(2):
		for lane in range(3):
			for index in range(s.battle.boards[side][lane].size()):
				var card = s.battle.boards[side][lane][index]
				out[card.uid] = {"side": side, "lane": lane, "index": index, "card": card.duplicate(true), "power": card_power(side, lane, index), "shield": card.shield}
	return out

func record_presentation(kind: String, before: Dictionary, source: Dictionary, waiting: Array):
	var after = presentation_board()
	var changes = []
	var removed = []
	var recalled = []
	var added = []
	var moved = []
	var shields = []
	var transformed = []
	for uid in before:
		if not after.has(uid):
			if s.battle.hands[before[uid].side].any( func(c): return c.uid == uid): recalled.append(before[uid])
			else: removed.append(before[uid])
	if source.has("uid") and not before.has(source.uid) and not after.has(source.uid) and s.battle.grave[source.side].any( func(c): return c.uid == source.uid):
		removed.append(source.duplicate(true))
	for uid in after:
		var item = after[uid]
		if not before.has(uid):
			if source.get("uid", -1) != uid: added.append(item)
		else:
			if item.card.id != before[uid].card.id: transformed.append({"from": before[uid], "to": item})
			var delta = item.power - before[uid].power
			if delta != 0: changes.append({"side": item.side, "lane": item.lane, "index": item.index, "delta": delta})
			if item.lane != before[uid].lane: moved.append({"from": before[uid], "to": item})
			if item.shield != before[uid].shield: shields.append(item)
	var state = s.duplicate(true)
	state.battle.queue = waiting.duplicate(true)
	var landed = source.duplicate(true)
	if source.has("uid") and after.has(source.uid):
		landed.side = after[source.uid].side
		landed.lane = after[source.uid].lane
		landed.index = after[source.uid].index
	var terrain_cues = s.battle.terrain_events.slice(terrain_cue_cursor)
	terrain_cue_cursor = s.battle.terrain_events.size()
	last_events.append({"kind": kind, "source": source, "result_source": landed, "changes": changes, "removed": removed, "recalled": recalled, "added": added, "moved": moved, "shields": shields, "transformed": transformed, "terrains": terrain_cues, "state": state})

func finish_battle():
	var wins = [0, 0]
	var totals = [0, 0]
	var scores = [[], []]
	for lane in range(3):
		var own = score(0, lane)
		var enemy = score(1, lane)
		scores[0].append(own)
		scores[1].append(enemy)
		totals[0] += own
		totals[1] += enemy
		if own > enemy: wins[0] += 1
		elif enemy > own: wins[1] += 1
	var outcome = "tie"
	if wins[0] > wins[1] or (wins[0] == wins[1] and totals[0] > totals[1]): outcome = "win"
	elif wins[1] > wins[0] or (wins[0] == wins[1] and totals[1] > totals[0]): outcome = "loss"
	s.result = {"outcome": outcome, "wins": wins, "totals": totals, "scores": scores}
	if outcome == "loss": s.lives -= 1
	s.phase = "result"

func continue_result():
	if s.phase != "result": return
	if s.result.outcome == "win":
		if s.stage == 2: s.phase = "complete"
		else:
			var pool = collectible_ids().filter( func(id): return not s.deck.has(id))
			s.rewards = shuffled(pool).slice(0, 3)
			if not s.rewards.any( func(id): return MONSTERS.has(id)):
				var aliens = MONSTERS.filter( func(id): return not s.deck.has(id))
				if not aliens.is_empty(): s.rewards[2] = shuffled(aliens)[0]
			s.phase = "reward"
	elif s.lives <= 0: s.phase = "gameover"
	else: s.phase = "map"

func select_reward(id: String):
	if s.phase == "reward" and s.rewards.has(id):
		s.chosen = id
		s.phase = "replace"

func replace_card(index: int):
	if s.phase != "replace" or index < 0 or index >= 12: return
	s.deck[index] = s.chosen
	s.chosen = ""
	s.stage += 1
	s.phase = "map"

func skip_reward():
	if s.phase not in ["reward", "replace"]: return
	s.stage += 1
	s.chosen = ""
	s.phase = "map"

func snapshot() -> Dictionary:
	var data = s.duplicate(true)
	data["rng_state"] = str(rng.state)
	return data

func valid_card(card: Variant) -> bool:
	if not card is Dictionary or not Skills.valid(card): return false
	for key in ["id", "uid", "bonus", "damage", "cost_delta", "shield", "uses", "played_round", "origin_lane"]:
		if not card.has(key): return false
	return CARDS.has(card.id) and card.uid is int and card.uid > 0 and card.bonus is int and card.damage is int and card.damage >= 0 and card.cost_delta is int and card.shield is bool and card.uses is Dictionary and Skills.valid(card)

func restore(data: Variant) -> bool:
	data = normalize_numbers(data)
	if not data is Dictionary or data.get("version", 0) not in [2, 3, 4, 5, 6, 7]: return false
	for key in ["phase", "stage", "lives", "deck", "battle", "result", "rewards", "chosen", "rng_state", "next_uid"]:
		if not data.has(key): return false
	if not data.deck is Array or validate_deck(data.deck) != "" or data.phase not in ["map", "battle", "result", "reward", "replace", "complete", "gameover"]: return false
	if data.stage < 0 or data.stage > 2 or data.lives < 0 or data.lives > 3: return false
	if data.phase in ["battle", "result"]:
		var b = data.battle
		if not b is Dictionary: return false
		for key in ["round", "hands", "draws", "boards", "energy", "next_energy", "queue", "enemy_plan", "regions", "logs", "grave", "revivals", "peeked", "played"]:
			if not b.has(key) or (key != "round" and not b[key] is Array): return false
		if b.round < 1 or b.round > 6 or b.boards.size() != 2 or b.hands.size() != 2 or b.draws.size() != 2 or b.grave.size() != 2 or b.regions.size() != 3 or b.energy.size() != 2 or b.next_energy.size() != 2: return false
		if not valid_continuation(b): return false
		var seen = {}
		for region in b.regions:
			if not region is int or region < 0 or region >= REGIONS.size(): return false
		for side in range(2):
			if not b.boards[side] is Array or b.boards[side].size() != 3 or not b.hands[side] is Array or b.hands[side].size() > 8 or not b.draws[side] is Array or not b.grave[side] is Array: return false
			var all = b.hands[side] + b.draws[side] + b.grave[side]
			for area in b.boards[side]:
				if not area is Array or area.size() > 4: return false
				all += area
			if side == 0:
				for move in b.queue:
					if not move is Dictionary or not move.has("card") or not move.has("lane") or not move.has("index") or move.lane < 0 or move.lane > 2: return false
					all.append(move.card)
			if b.has("resolution") and side == 1:
				for move in b.enemy_plan: all.append(move.card)
			if side == 0: all += b.get("choice", {}).get("cards", [])
			for card in all:
				if not valid_card(card) or seen.has(card.uid): return false
				seen[card.uid] = true
		for move in b.enemy_plan:
			if not move is Dictionary or not move.has("card") or not valid_card(move.card) or not move.has("lane") or move.lane < 0 or move.lane > 2: return false

	if not data.has("opponents"): data["opponents"] = Roster.LEGACY.duplicate()
	if not data.opponents is Array or data.opponents.size() != 3: return false
	for stage in range(3):
		if not data.opponents[stage] is String or not Roster.PROFILES.has(data.opponents[stage]): return false
	s = data.duplicate(true)
	s.version = 7
	rng.state = int(data.rng_state)
	resolving = false
	pending = [[], []]
	if s.phase in ["battle", "result"]:
		ensure_state()
		terrain_cue_cursor = s.battle.terrain_events.size()
		if data.version < 5: migrate_devices()
		if s.battle.has("resolution"):
			resolving = true
			pending = s.battle.resolution.plans
			s.battle.queue = pending[0]
			s.battle.enemy_plan = pending[1]
	return true

func migrate_devices():
	var counters = {"016": "manual", "021": "resurrect", "037": "manual", "049": "gate", "053": "end", "073": "move_gain", "074": "arrival", "077": "manual", "080": "manual", "083": "end", "089": "end", "090": "evolution_reward", "092": "blood", "096": "blood", "097": "death", "100": "kill_reward", "101": "blood", "104": "shield_forge", "108": "reinforcement", "116": "recharge_given", "119": "escape"}
	var migrated = {}
	for side in range(2):
		var cards = s.battle.hands[side] + s.battle.draws[side] + s.battle.grave[side]
		for area in s.battle.boards[side]: cards.append_array(area)
		for move in (s.battle.queue if side == 0 else s.battle.enemy_plan): cards.append(move.card)
		for move in s.battle.get("resolution", {}).get("plans", [[], []])[side]: cards.append(move.card)
		if side == 0: cards.append_array(s.battle.choice.get("cards", []))
		for card in cards:
			if CARDS[card.id].device.is_empty(): continue
			if not migrated.has(card.uid):
				var remaining = card.uses.get("device_remaining", -1)
				if remaining < 0: remaining = maxi(0, CARDS[card.id].device.initial_uses - int(card.uses.get(counters.get(card.id, ""), 0)))
				elif card.id in ["049", "100"]: remaining += 1
				migrated[card.uid] = remaining
			card.uses["device_remaining"] = migrated[card.uid]

func normalize_numbers(value: Variant) -> Variant:
	if value is float: return int(value)
	if value is Array:
		var out = []
		for item in value: out.append(normalize_numbers(item))
		return out
	if value is Dictionary:
		var out = {}
		for key in value: out[key] = normalize_numbers(value[key])
		return out
	return value

func ensure_state():
	var b = s.battle
	if not b.has("history"): b["history"] = [{"revived": [], "moved": [], "paid": []}, {"revived": [], "moved": [], "paid": []}]
	if not b.has("reactions"): b["reactions"] = []
	if not b.has("choice"): b["choice"] = {}
	if not b.has("entry_serial"): b["entry_serial"] = 0
	if not b.has("weaken_boost"): b["weaken_boost"] = [0, 0]
	if not b.has("power_watch"): b["power_watch"] = {}
	if not b.has("zero_causes"): b["zero_causes"] = {}
	if not b.has("terrain_state"): b["terrain_state"] = Terrain.initial_state()
	if not b.has("terrain_events"): b["terrain_events"] = []
	if not b.has("terrain_art"): b["terrain_art"] = [0, 1, 2]

func remember_power():
	ensure_state()
	for side in range(2):
		for lane in range(3):
			for index in range(s.battle.boards[side][lane].size()):
				var key = str(s.battle.boards[side][lane][index].uid)
				s.battle.power_watch[key] = maxi(s.battle.power_watch.get(key, 0), card_power(side, lane, index))

func settle_zero_power():


	var attempted = {}
	while true:
		var doomed = []
		for side in range(2):
			for lane in range(3):
				for index in range(s.battle.boards[side][lane].size()):
					var card = s.battle.boards[side][lane][index]
					var key = str(card.uid)
					var terrain_loss = region_effect(lane) == "weak" and not immune_to_weaken(card)
					if card_power(side, lane, index) <= 0 and not attempted.has(card.uid) and (card.damage > 0 or s.battle.zero_causes.has(key) or s.battle.power_watch.get(key, 0) > 0 or terrain_loss):
						doomed.append({"uid": card.uid, "actor": s.battle.zero_causes.get(key, -1)})
		if doomed.is_empty(): break
		for target in doomed:
			attempted[target.uid] = true
			destroy(target.uid, target.actor, true)
	var current = {}
	for side in range(2):
		for lane in range(3):
			for index in range(s.battle.boards[side][lane].size()):
				var key = str(s.battle.boards[side][lane][index].uid)
				current[key] = card_power(side, lane, index)
	for key in s.battle.zero_causes.keys():
		if not current.has(key) or current[key] > 0: s.battle.zero_causes.erase(key)
	s.battle.power_watch = current

func next_entry_stamp() -> int:
	ensure_state()
	s.battle.entry_serial += 1
	return s.battle.entry_serial

func history_count(side: int, key: String) -> int:
	return s.battle.get("history", [{}, {}])[side].get(key, []).size()

func history_has(side: int, key: String, uid: int) -> bool:
	return s.battle.get("history", [{}, {}])[side].get(key, []).has(uid)

func mark_history(side: int, key: String, uid: int):
	ensure_state()
	if not s.battle.history[side].has(key): s.battle.history[side][key] = []
	if not s.battle.history[side][key].has(uid): s.battle.history[side][key].append(uid)

func occupied_lanes(side: int) -> int:
	var count = 0
	for area in s.battle.boards[side]:
		if not area.is_empty(): count += 1
	return count

func pick_lane(side: int, lanes: Array, by_count: bool = false) -> int:
	var chosen = -1
	var minimum = 999999
	for lane in lanes:
		if not room(side, lane): continue
		var amount = s.battle.boards[side][lane].size() if by_count else score(side, lane)
		if amount < minimum:
			minimum = amount
			chosen = lane
	return chosen

func all_card(uid: int) -> Dictionary:
	var found = locate(uid)
	if not found.is_empty(): return found.card
	for side in range(2):
		for zone in ["hands", "draws", "grave"]:
			for card in s.battle[zone][side]:
				if card.uid == uid: return card
		for move in s.battle.get("resolution", {}).get("plans", [[], []])[side]:
			if move.card.uid == uid: return move.card
	for card in s.battle.get("choice", {}).get("cards", []):
		if card.uid == uid: return card
	return {}

func emit_event(kind: String, subject: Dictionary, side: int, lane: int, extra: Dictionary = {}):
	ensure_state()
	var listeners = []
	var order = [0, 1] if s.battle.round % 2 == 1 else [1, 0]
	for team in order:
		for k in range(3):
			for card in s.battle.boards[team][k]:
				for id in skill_ids(card, "持续"):
					listeners.append({"uid": card.uid, "id": id, "body": card.id, "side": team, "lane": k, "entry": card.get("entry_stamp", 0)})
	var event = {"kind": kind, "uid": subject.uid, "id": subject.id, "side": side, "lane": lane, "listeners": listeners, "round": s.battle.round, "entry": subject.get("entry_stamp", 0), "terrain": region_effect(lane)}
	event.merge(extra, true)
	s.battle.reactions.append(event)

func flush_reactions():
	if reacting: return
	ensure_state()
	reacting = true
	settle_zero_power()
	var steps = 0
	while not s.battle.reactions.is_empty():
		var event = s.battle.reactions.pop_front()
		for listener in event.listeners:
			var live = locate(listener.uid)
			var death_self = event.kind == "destroyed" and listener.uid == event.uid
			if not death_self and (live.is_empty() or live.card.get("entry_stamp", 0) != listener.entry or live.card.id != listener.get("body", listener.id)): continue
			var card = all_card(listener.uid)
			if card.is_empty(): continue
			var saved_actor = actor
			actor = listener.side
			var previous_skill = push_skill(card, listener.id)
			Reactions.trigger(self, listener, card, event)
			pop_skill(card, previous_skill)
			actor = saved_actor
			settle_zero_power()
		Terrain.reaction(self, event)
		settle_zero_power()
		steps += 1
		assert (steps < 2048, "Reaction chain did not terminate")
	reacting = false

func grant_shield(card: Dictionary) -> bool:
	if card.shield: return false
	var found = locate(card.uid)
	if found.is_empty(): return false
	card.shield = true
	emit_event("shield_gained", card, found.side, found.lane)
	return true

func remove_shield(card: Dictionary, reason: String = "remove", by_side: int = -1) -> bool:
	if not card.shield: return false
	var found = locate(card.uid)
	if found.is_empty(): return false
	remember_power()
	card.shield = false
	emit_event("shield_lost", card, found.side, found.lane, {"reason": reason, "actor": by_side})
	return true

func heal(card: Dictionary, amount: int) -> int:
	var healed = mini(amount, int(card.damage))
	card.damage -= healed
	return healed

func repair_budget(side: int, lane: int, amount: int):
	for target in targets(side, [lane], false):
		amount -= heal(target.card, amount)
		if amount <= 0: break

func can_be_moved(uid: int, by_side: int) -> bool:
	var found = locate(uid)
	if found.is_empty() or has_skill(found.card, "050"): return false
	for team in range(2):
		for unit in s.battle.boards[team][found.lane]:
			if has_skill(unit, "055") and unit.uid != uid: return false
	if found.side != by_side:
		if has_skill(found.card, "029") and found.card.shield: return false
		for ally in s.battle.boards[found.side][found.lane]:
			if ally.uid != uid and has_skill(ally, "105") and ally.shield: return false
	return true

func mark_moved(card: Dictionary, side: int, origin: int, destination: int):
	Terrain.moved(self, card, origin, destination)
	var pre_shield = card.shield
	card.uses["moved_round"] = s.battle.round
	mark_history(side, "moved", card.uid)
	emit_event("moved", card, side, destination, {"from_lane": origin, "pre_shield": pre_shield})

func swap_units(uid: int, other_uid: int, side: int = 0) -> String:
	if s.phase != "battle" or resolving: return "当前不能换位。"
	var a = locate(uid)
	var b = locate(other_uid)
	if a.is_empty() or b.is_empty() or a.side != side or b.side != side or a.card.id != "077" or a.lane == b.lane or CARDS[b.card.id].effect != "none": return "选择另一战区的己方无技能单位。"
	if not can_activate(uid) or not can_be_moved(uid, side) or not can_be_moved(other_uid, side): return "换位不可用。"
	actor = side
	remember_power()
	s.battle.boards[side][a.lane][a.index] = b.card
	s.battle.boards[side][b.lane][b.index] = a.card
	a.card.uses["manual"] = a.card.uses.get("manual", 0) + 1
	finish_active(a.card)
	mark_moved(a.card, side, a.lane, b.lane)
	mark_moved(b.card, side, b.lane, a.lane)
	flush_reactions()
	return ""

func device_skill(card: Dictionary) -> String:
	var context = skill_context.get(str(card.uid), "")
	if context != "": return context
	var devices = Skills.device_ids(card)
	if devices.is_empty(): return card.id
	devices.sort_custom( func(a, c): return int(Skills.uses(card, a).get("device_remaining", CARDS[a].device.initial_uses)) < int(Skills.uses(card, c).get("device_remaining", CARDS[c].device.initial_uses)))
	return devices[0]

func device_remaining(card: Dictionary, ability: String = "") -> int:
	if ability == "": ability = device_skill(card)
	return int(Skills.uses(card, ability).get("device_remaining", CARDS[ability].device.get("initial_uses", 0)))

func device_ready(card: Dictionary) -> bool:
	return device_remaining(card) > 0

func spend_device(card: Dictionary):
	var id = device_skill(card)
	Skills.uses(card, id)["device_remaining"] = maxi(0, device_remaining(card, id) - 1)
	Skills.uses(card, id)["device_round"] = s.battle.round

func pay_power(card: Dictionary, amount: int) -> bool:
	var found = locate(card.uid)
	if found.is_empty() or raw_power(card) < amount: return false
	remember_power()
	card.damage += amount
	s.battle.zero_causes[str(card.uid)] = found.side
	mark_history(found.side, "paid", card.uid)
	emit_event("paid", card, found.side, found.lane, {"amount": amount})
	s.battle.logs.append("%s 支付 %d 战力" % [CARDS[card.id].name, amount])
	return true

func recharge_eligible(card: Dictionary) -> bool:
	return not Skills.device_ids(card).is_empty() and card.uses.get("reboot", 0) == 0

func recharge(card: Dictionary, amount: int) -> bool:
	if not recharge_eligible(card): return false
	var devices = Skills.device_ids(card)
	devices.sort_custom( func(a, c): return device_remaining(card, a) < device_remaining(card, c))
	var id = devices[0]
	Skills.uses(card, id)["device_remaining"] = device_remaining(card, id) + amount
	card.uses["reboot"] = 1
	return true

func can_reboot(uid: int) -> bool:
	var found = locate(uid)
	if found.is_empty() or resolving: return false
	var card = found.card
	if card.id not in ["114", "117"] or card.uses.get("reboot_action", 0) or card.uses.get("active_round", -1) == s.battle.round or raw_power(card) < 2: return false
	if card.id == "114": return recharge_eligible(card)
	return targets(found.side, [found.lane]).any( func(t): return recharge_eligible(t.card))

func reboot(uid: int, side: int = 0) -> String:
	var found = locate(uid)
	if s.phase != "battle" or found.is_empty() or found.side != side or not can_reboot(uid): return "重启已使用、没有可重启装置，或战力不足。"
	actor = side
	if not pay_power(found.card, 2): return "战力不足。"
	if found.card.id == "117":
		for t in targets(side, [found.lane]): recharge(t.card, 2)
	else: recharge(found.card, 2)
	found.card.uses["reboot_action"] = 1
	found.card.uses["active_round"] = s.battle.round
	s.battle.logs.append("%s 搏命2，重启2" % CARDS[found.card.id].name)
	flush_reactions()
	return ""

func cancel_tracking(uid: int):
	for side in range(2):
		for area in s.battle.boards[side]:
			for card in area:
				if card.id == "075" and card.uses.get("mark", -1) == uid: card.uses["mark"] = -1

func evolve(card: Dictionary, side: int, lane: int):
	var spec = CARDS[card.id].evolution
	if spec.is_empty() or card.uses.get("evolved", 0) > 0 or card.uses.get("growth", 0) < spec.growth_ends: return
	remember_power()
	var old_id = card.id
	card["origin_id"] = old_id
	card.id = spec.target_id
	card.cost_delta = 0
	card.erase("base_power")
	card.uses["evolved"] = 1
	card.damage += 1
	if not CARDS[card.id].device.is_empty() and not card.uses.has("device_remaining"):
		card.uses["device_remaining"] = CARDS[card.id].device.initial_uses
	emit_event("evolved", card, side, lane, {"old_id": old_id, "had_shield": card.shield})
	s.battle.logs.append("%s 进化为 %s" % [CARDS[old_id].name, CARDS[card.id].name])

func state_line(card: Dictionary) -> String:
	var data = CARDS[card.id]
	var parts: Array[String] = []
	if card.shield: parts.append("护盾：抵挡1次")
	if not data.device.is_empty():
		parts.append("装置剩余 %d · 重启%s" % [device_remaining(card, card.id), "已用" if card.uses.get("reboot", 0) else "未用"])
	if not card.get("inherited", {}).is_empty():
		parts.append("已获得 %d种技能 · 点击查看" % card.inherited.size())
	if not data.evolution.is_empty():
		parts.append("成长 %d/%d → %s" % [card.uses.get("growth", 0), data.evolution.growth_ends, CARDS[data.evolution.target_id].name])
	if card.uses.get("evolved", 0): parts.append("已进化")
	if not data.blood_price.is_empty(): parts.append("搏命" + ("可用" if device_ready(card) else "已用"))
	if card.damage > 0: parts.append("减力 %d" % card.damage)
	if card.uses.get("end", 0) > 0: parts.append("结束技能已发动 %d次" % card.uses.end)
	return "  ·  ".join(parts)
func resolution_cohort(order: Array) -> Array:
	var cohort = []
	for side in order:
		for lane in range(3):
			for card in s.battle.boards[side][lane]:
				cohort.append({"uid": card.uid, "entry": card.get("entry_stamp", 0)})
	return cohort

func advance_resolution():
	var b = s.battle
	var r = b.resolution
	pending = r.plans
	while b.choice.is_empty():
		b.queue = pending[0]
		b.enemy_plan = pending[1]
		var before = presentation_board() if r.record else {}
		match r.stage:
			"reveal":
				if r.side_index >= 2:
					r.end_ids = resolution_cohort(r.order)
					r.growth_ids = r.end_ids.duplicate(true)
					r.stage = "end"
					continue
				var side = r.order[r.side_index]
				if pending[side].is_empty():
					r.side_index += 1
					continue
				var move = pending[side].pop_front()
				var card = move.card
				var lane = int(move.lane)
				var source = {"side": side, "lane": lane, "index": b.boards[side][lane].size(), "card": card.duplicate(true), "effect": CARDS[card.id].effect, "uid": card.uid}
				card.played_round = b.round
				card.origin_lane = lane
				card.entry_stamp = next_entry_stamp()
				b.boards[side][lane].append(card)
				b.logs.append("%s · %s → 战区%d" % ["你方" if side == 0 else "敌方", CARDS[card.id].name, lane + 1])
				Effects.reveal(self, side, lane, card)
				if r.record: record_presentation("reveal", before, source, pending[0])
			"end", "growth":
				var cohort = r.end_ids if r.stage == "end" else r.growth_ids
				if cohort.is_empty():
					r.stage = "revive" if r.stage == "end" else "complete"
					continue
				var item = cohort.pop_front()
				var found = locate(item.uid)
				if found.is_empty() or found.card.get("entry_stamp", 0) != item.entry: continue
				if r.stage == "end": Effects.finish_card(self, found.side, found.lane, found.card)
				elif not CARDS[found.card.id].evolution.is_empty() and not found.card.uses.get("evolved", 0):
					found.card.uses["growth"] = found.card.uses.get("growth", 0) + 1
					evolve(found.card, found.side, found.lane)
					flush_reactions()
				if r.record and presentation_board() != before: record_presentation("settle", before, {}, [])
			"revive":
				if b.revivals.is_empty():
					r.stage = "terrain"
					r["terrain_lane"] = 0
					continue
				var uid = b.revivals.pop_front()
				for side in range(2):
					for index in range(b.grave[side].size()):
						var card = b.grave[side][index]
						if card.uid == uid and card.uses.get("resurrect", 0) < 1:
							if revive(side, index, card.destroyed_lane, 2): card.uses["resurrect"] = 1
							break
				flush_reactions()
				if r.record and presentation_board() != before: record_presentation("settle", before, {}, [])
			"terrain":
				if r.terrain_lane >= 3:
					r.stage = "growth"
					continue
				Terrain.finish_round(self, r.terrain_lane)
				flush_reactions()
				r.terrain_lane += 1
				if r.record and (presentation_board() != before or terrain_cue_cursor < b.terrain_events.size()): record_presentation("terrain", before, {}, [])
			"complete":
				var record = r.record
				b.erase("resolution")
				b.queue = []
				b.enemy_plan = []
				pending = [[], []]
				resolving = false
				if b.round == 6: finish_battle()
				else:
					begin_round()
					if record: record_presentation("round_start", before, {}, [])
				return

func survey(side: int, source_uid: int):
	var b = s.battle
	if b.hands[side].size() >= 8 or b.draws[side].is_empty(): return
	var options = []
	for i in range(mini(3, b.draws[side].size())): options.append(b.draws[side].pop_back())
	if side == 0 and options.size() >= 2 and b.get("resolution", {}).get("interactive", false) and not b.get("echoing", false):
		b.choice = {"kind": "survey", "cards": options, "source_uid": source_uid}
	else:
		options.sort_custom( func(a, c): return CARDS[a.id].power > CARDS[c.id].power)
		b.hands[side].append(options.pop_front())
		for card in options: b.draws[side].push_front(card)

func recall_choice(side: int, source_uid: int):
	var b = s.battle
	if b.hands[side].size() >= 8: return
	var options = targets(side, [0, 1, 2], false)
	if options.is_empty(): return
	if side == 0 and b.get("resolution", {}).get("interactive", false) and not b.get("echoing", false):
		b.choice = {"kind": "recall", "uids": options.map( func(t): return t.uid), "source_uid": source_uid}
	else:
		options.sort_custom( func(a, c): return a.order < c.order if card_cost(a.card) == card_cost(c.card) else card_cost(a.card) > card_cost(c.card))
		recall(options[0].uid, side, true)

func inheritance_targets(side: int, source_uid: int) -> Array:
	return targets(side, [0, 1, 2], false, source_uid).filter( func(t): return CARDS[t.card.id].group == "iron_tombs")

func inheritance_choice(side: int, source_uid: int):
	var options = inheritance_targets(side, source_uid)
	if options.is_empty(): return
	if side == 0 and s.battle.get("resolution", {}).get("interactive", false) and not s.battle.get("echoing", false):
		s.battle.choice = {"kind": "inherit", "uids": options.map( func(t): return t.uid), "source_uid": source_uid}
	else:
		options.sort_custom( func(a, c): return a.order < c.order if a.card.bonus - a.card.damage == c.card.bonus - c.card.damage else a.card.bonus - a.card.damage > c.card.bonus - c.card.damage)
		inherit(source_uid, options[0].uid, side)

func inherit(source_uid: int, target_uid: int, side: int) -> bool:
	var source = locate(source_uid)
	var target = locate(target_uid)
	if source.is_empty() or target.is_empty() or source.side != side or target.side != side or source_uid == target_uid or CARDS[target.card.id].group != "iron_tombs": return false
	var donor = target.card.duplicate(true)
	if not destroy(target_uid, side): return false
	remember_power()
	source.card.bonus += donor.bonus
	source.card.damage += donor.damage
	for id in skill_ids(donor):
		var mode = donor.get("inherited", {}).get(id, {}).get("mode", "all")
		Skills.grant(source.card, id, mode, Skills.uses(donor, id))
	s.battle.logs.append("%s 继承 %s 的增减战力与技能" % [CARDS[source.card.id].name, CARDS[donor.id].name])
	return true

func recall(uid: int, side: int, free: bool = false):
	var found = locate(uid)
	if found.is_empty() or s.battle.hands[side].size() >= 8: return
	remember_power()
	if free: found.card.cost_delta = - CARDS[found.card.id].cost
	s.battle.boards[side][found.lane].remove_at(found.index)
	found.card.played_round = -1
	s.battle.hands[side].append(found.card)
	s.battle.power_watch.erase(str(uid))
	s.battle.zero_causes.erase(str(uid))

func choose_card(index: int) -> bool:
	var b = s.battle
	if not resolving: return false
	if b.choice.get("kind", "") == "survey":
		if index < 0 or index >= b.choice.cards.size(): return false
		var options = b.choice.cards
		b.hands[0].append(options.pop_at(index))
		for card in options: b.draws[0].push_front(card)
	elif b.choice.get("kind", "") == "recall":
		if index < 0 or index >= b.choice.uids.size(): return false
		recall(b.choice.uids[index], 0, true)
	elif b.choice.get("kind", "") == "inherit":
		if index < 0 or index >= b.choice.uids.size(): return false
		inherit(b.choice.source_uid, b.choice.uids[index], 0)
	else: return false
	b.choice = {}
	last_events.clear()
	flush_reactions()
	advance_resolution()
	return true

func valid_continuation(b: Dictionary) -> bool:
	if not Terrain.valid_state(b): return false
	var choice = b.get("choice", {})
	if not choice is Dictionary: return false
	if b.has("history"):
		if not b.history is Array or b.history.size() != 2: return false
		for history in b.history:
			if not history is Dictionary: return false
			for key in ["revived", "moved", "paid"]:
				if not history.get(key, []) is Array: return false
	if b.has("resolution"):
		var r = b.resolution
		if not r is Dictionary: return false
		for key in ["plans", "order", "side_index", "stage", "record", "interactive", "end_ids", "growth_ids"]:
			if not r.has(key): return false
		if not r.plans is Array or r.plans.size() != 2 or r.plans[0] != b.queue or r.plans[1] != b.enemy_plan: return false
		if r.order not in [[0, 1], [1, 0]] or not r.side_index is int or r.side_index < 0 or r.side_index > 2: return false
		if r.stage != "reveal" or not r.record is bool or not r.interactive is bool or not r.interactive: return false
		if not r.end_ids is Array or not r.growth_ids is Array: return false

		if not choice.get("source_uid") is int: return false
		if choice.get("kind", "") == "survey":
			if not choice.get("cards") is Array or choice.cards.size() not in [2, 3]: return false
		elif choice.get("kind", "") in ["recall", "inherit"]:
			if not choice.get("uids") is Array or choice.uids.is_empty(): return false
			for uid in choice.uids:
				var valid = false
				for area in b.boards[0]:
					for card in area:
						if card.uid == uid and (choice.kind == "recall" or (card.uid != choice.source_uid and CARDS[card.id].group == "iron_tombs")): valid = true
				if not valid: return false
		else: return false
		if choice.kind != "inherit" and b.hands[0].size() >= 8: return false
	elif not choice.is_empty(): return false
	return true
