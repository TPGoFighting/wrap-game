extends RefCounted

const ACTIVE = ["016", "023", "037", "039", "045", "047", "048", "049", "055", "061", "064", "067", "068", "070", "080", "093", "107", "108", "112"]
const SELF_MOVE = ["016", "037", "064", "080"]

static func extreme(g, side: int, lanes: Array, high: bool, exclude: int = -1) -> Array:
	var all = g.targets(side, lanes, high, exclude)
	if all.is_empty(): return []
	var value = all[0].power
	return all.filter( func(t): return t.power == value)

static func draw_many(g, side: int, count: int):
	for i in range(count): g.draw_card(side)

static func revive_highest(g, side: int, lane: int) -> bool:
	var grave = g.s.battle.grave[side]
	var chosen = -1
	for i in range(grave.size()):
		if chosen < 0 or g.CARDS[grave[i].id].cost > g.CARDS[grave[chosen].id].cost: chosen = i
	return g.revive(side, chosen, lane, 1)

static func reveal(g, side: int, lane: int, card: Dictionary) -> bool:
	var b = g.s.battle
	var targets = []
	match g.skill_id(card):
		"023", "039", "043", "045", "047", "048", "059", "068", "108", "112": pass
		"071": g.inheritance_choice(side, card.uid)
		"121": g.Skills.copy_continuous(g, card)
		"004":
			targets = g.targets(1 - side, [lane])
			if not targets.is_empty() and targets[0].power >= 10: g.adjust(targets[0].card, -5)
		"005": draw_many(g, side, 2)
		"007":
			for t in g.targets(side, [lane]):
				if t.card.damage <= 2: g.heal(t.card, 2)
		"009":
			var minimum = 999999
			for held in b.hands[side]: minimum = mini(minimum, g.raw_power(held))
			for held in b.hands[side]:
				if g.raw_power(held) == minimum: g.adjust(held, 2)
		"014": g.draw_card(side)
		"022":
			if b.get("echoing", false): return true
			b["echoing"] = true
			for dead in b.grave[side].duplicate():
				if dead.id != "022": g.Effects.reveal(g, side, lane, dead)
			b.erase("echoing")
		"035":
			if b.boards[side][lane].size() > 1 and not b.boards[1 - side][lane].is_empty(): draw_many(g, side, 2)
		"042":
			if b.hands[side].size() < 8 and not b.draws[side].is_empty():
				var index = 0
				for i in range(b.draws[side].size()):
					if g.CARDS[b.draws[side][i].id].cost < g.CARDS[b.draws[side][index].id].cost: index = i
				b.hands[side].append(b.draws[side].pop_at(index))
		"061": g.adjust(card, maxi(0, b.energy[side] - b.get("spent", [0, 0])[side]) * 2)
		"075": b.weaken_boost[side] += 1
		"076":
			targets = g.targets(side, g.other_lanes(lane), false, card.uid, side)
			if not targets.is_empty(): g.move_card(targets[0].uid, lane, side)
		"081":
			var count = mini(g.device_remaining(card), g.history_count(side, "moved"))
			g.adjust(card, count * 2)
			g.skill_uses(card)["device_remaining"] = g.device_remaining(card) - count
		"086":
			for t in g.targets(side, [0, 1, 2], false, card.uid):
				var spec = g.CARDS[t.card.id].evolution
				if not spec.is_empty() and not t.card.uses.get("evolved", 0):
					t.card.uses["growth"] = spec.growth_ends
					g.evolve(t.card, side, t.lane)
		"107":
			targets = g.targets(1 - side, [lane])
			if not targets.is_empty(): g.remove_shield(targets[g.rng.randi_range(0, targets.size() - 1)].card, "remove", side)
		"111": g.grant_shield(card)
		"115": b.next_energy[side] = mini(2, b.next_energy[side] + 1)
		"120": g.recall_choice(side, card.uid)
		"colonist": g.adjust(card, 8 - b.boards[0][lane].size() - b.boards[1][lane].size())
		_: return false
	return true

static func finish_card(g, side: int, lane: int, card: Dictionary) -> bool:
	if g.skill_id(card) not in ["004", "019", "032", "043", "053", "055", "059", "073", "075", "083", "088", "093", "114", "117"]: return false
	if g.skill_uses(card).get("passive_round", -1) == g.s.battle.round: return true
	g.skill_uses(card)["passive_round"] = g.s.battle.round
	var b = g.s.battle
	var targets = []
	match g.skill_id(card):
		"019":
			if b.energy[side] - b.get("spent", [0, 0])[side] > 0: g.adjust(card, 1)
		"032":
			if b.played[1 - side].has(lane) and g.skill_uses(card).get("end", 0) < 3:
				g.adjust(card, 1)
				g.skill_uses(card)["end"] = g.skill_uses(card).get("end", 0) + 1
		"043":
			if g.device_ready(card) and b.hands[side].size() < 8:
				b.hands[side].append(g.instance("colonist"))
				g.spend_device(card)
		"053":
			targets = g.targets(side, [0, 1, 2], false)
			if g.device_ready(card) and not targets.is_empty():
				g.adjust(targets[0].card, 1)
				g.spend_device(card)
		"059":
			for t in g.targets(side, [0, 1, 2]): g.grant_shield(t.card)
		"073":
			if g.device_ready(card) and g.skill_uses(card).get("moved_round", -1) == b.round:
				g.adjust(card, 1)
				g.spend_device(card)
		"083":
			targets = extreme(g, 1 - side, [lane], false)
			if g.device_ready(card) and not targets.is_empty():
				for t in targets: g.adjust(t.card, -1)
				g.spend_device(card)
		"114":
			targets = g.targets(1 - side, [0, 1, 2])
			if g.device_ready(card) and not targets.is_empty():
				g.adjust(targets[0].card, -3)
				g.spend_device(card)
		"117":
			if g.device_ready(card):
				var worked = g.summon(side, lane, "fighter")
				worked = g.summon(side, lane, "fighter") or worked
				if worked: g.spend_device(card)
	return true

static func active(g, side: int, lane: int, card: Dictionary) -> bool:
	var enemy = 1 - side
	var targets = []
	match g.skill_id(card):
		"023", "039", "045":
			targets = extreme(g, enemy, g.other_lanes(lane) if g.skill_id(card) == "023" else [lane], true)
			if targets.is_empty(): return false
			if g.skill_id(card) != "045": targets = targets.slice(0, 1)
			for t in targets: g.adjust(t.card, -3 if g.skill_id(card) == "045" else -2)
		"047", "061":
			var amount = 3
			var exclude = card.uid
			if g.skill_id(card) == "061":
				var live = g.locate(card.uid)
				var power = g.card_power(side, lane, live.index)
				if power <= 10: return false
				amount = 6 if power > 12 else 4
			for team in range(2):
				targets.append_array(g.targets(team, [0, 1, 2], false, exclude))
			if targets.is_empty(): return false
			for t in targets: g.adjust(t.card, - amount)
		"048": g.s.battle.energy[side] += 2
		"067":
			g.destroy(card.uid, side)
			g.draw_card(side)
		"068": return revive_highest(g, side, lane)
		"070":
			for t in g.targets(enemy, [0, 1, 2]): g.adjust(t.card, -1)
			g.destroy(card.uid, side)
		"108": return g.summon(side, lane, "colonist")
		"093":
			for team in range(2): targets.append_array(g.targets(team, [lane], false, card.uid))
			if targets.is_empty(): return false
			for t in targets: g.adjust(t.card, -2)
		"107":
			targets = g.targets(enemy, [lane], false).filter( func(t): return t.power <= 3)
			if targets.is_empty(): return false
			g.destroy(targets[0].uid, side)
		"112":
			targets = g.targets(side, [lane], false, card.uid)
			if targets.is_empty(): return false
			if g.destroy(targets[0].uid, side): g.adjust(card, targets[0].power)
		_: return false
	return true

static func reaction(g, listener: Dictionary, card: Dictionary, e: Dictionary) -> bool:
	var side = listener.side
	var lane = listener.lane
	var own = e.side == side
	var self_event = e.uid == card.uid
	var live = g.locate(e.uid)
	var match_event = false
	match listener.id:
		"016", "064", "067", "070", "073", "075", "076", "080", "108", "115": pass
		"021", "062":
			if self_event and e.kind == "destroyed" and g.locate(card.uid).is_empty() and card.get("entry_stamp", 0) == e.get("entry", 0) and g.device_ready(card):
				g.spend_device(card)
				var grave = g.s.battle.grave[side]
				for i in range(grave.size()):
					if grave[i].uid == card.uid:
						g.revive(side, i, e.lane, 5 if listener.id == "062" else 2, listener.id == "062")
						break
		"030":
			if own and e.kind == "shield_lost" and e.get("reason", "") in ["weaken", "destroy"] and g.draw_card(side): g.adjust(g.s.battle.hands[side].back(), 3)
		"059":
			if self_event and e.kind == "destroyed":
				for team in range(2):
					for t in g.targets(team, [0, 1, 2]): g.remove_shield(t.card, "remove", side)
		"063":
			match_event = own and e.kind == "revived"
			if match_event and g.device_ready(card): g.adjust(card, 1)
		"072":
			if self_event and e.kind == "moved":
				for t in g.targets(1 - side, [e.from_lane]): g.adjust(t.card, -1)
		"074":
			match_event = own and not self_event and e.kind == "moved" and e.lane == lane and not live.is_empty()
			if match_event and g.device_ready(card): g.adjust(live.card, 2)
		"088":
			if self_event and e.kind == "weakened": g.draw_card(side)
		"095":
			match_event = own and not self_event and e.kind == "paid"
			if match_event and g.device_ready(card): draw_many(g, side, 3)
		"100":
			match_event = not own and e.kind == "destroyed"
			if match_event and g.device_ready(card): g.adjust(card, 2)
		"104":
			match_event = own and e.kind == "shield_gained" and not live.is_empty()
			if match_event and g.device_ready(card): g.adjust(live.card, 1)
		"116":
			if self_event and e.kind == "moved" and g.device_ready(card):
				var targets = g.targets(side, [0, 1, 2]).filter( func(t): return g.recharge_eligible(t.card))
				if not targets.is_empty():
					g.recharge(targets[g.rng.randi_range(0, targets.size() - 1)].card, 1)
					g.spend_device(card)
					g.skill_uses(card)["recharge_given"] = g.skill_uses(card).get("recharge_given", 0) + 1
		"118":
			if e.kind == "destroyed": g.adjust(card, 2)
		"119":
			match_event = self_event and e.kind == "shield_lost" and not live.is_empty()
			if match_event and g.device_ready(card):
				g.adjust(card, 1)
				var destinations = g.other_lanes(live.lane).filter( func(k): return g.room(side, k))
				if not destinations.is_empty(): g.move_card(card.uid, destinations[g.rng.randi_range(0, destinations.size() - 1)], side)
		_: return false
	if match_event and g.device_ready(card): g.spend_device(card)
	return true
