extends RefCounted

const Balance = preload("res://src/balance_effects.gd")
static func reveal(g, side: int, lane: int, card: Dictionary):
	var skills = g.skill_ids(card, "揭示")
	if card.id == "071":
		skills.erase("071")
		skills.append("071")
	var started_live = not g.locate(card.uid).is_empty()
	for id in skills:
		if started_live and g.locate(card.uid).is_empty(): break
		var previous = g.push_skill(card, id)
		reveal_one(g, side, lane, card)
		g.pop_skill(card, previous)
	g.flush_reactions()

static func reveal_one(g, side: int, lane: int, card: Dictionary):
	g.actor = side
	if Balance.reveal(g, side, lane, card):
		g.flush_reactions()
		return
	var b = g.s.battle
	var enemy = 1 - side
	var targets = []
	match g.skill_id(card):
		"001":
			if not b.peeked[side].has(lane): b.peeked[side].append(lane)
		"003":
			if b.hands[side].size() < 8: b.hands[side].append(g.instance("clone_recruit"))
		"004":
			targets = g.targets(enemy, [lane])
			if not targets.is_empty() and targets[0].power >= 10: g.destroy(targets[0].uid, side)
		"005": g.draw_card(side)
		"006": g.buff_area(side, [lane], 2, card.uid)
		"007":
			targets = g.targets(side, [lane], false, card.uid)
			if not targets.is_empty():
				g.heal(targets[0].card, 2)
				g.adjust(targets[0].card, 1)
		"009":
			targets = g.hand_targets(side)
			if not targets.is_empty(): g.adjust(targets[0].card, 2)
		"011":
			g.weaken(enemy, [lane], 2)
			g.grant_shield(card)
		"013":
			targets = g.targets(side, g.other_lanes(lane, true), false, -1, side)
			if not targets.is_empty() and g.move_card(targets[0].uid, lane, side): g.adjust(targets[0].card, 2)
		"014":
			if g.draw_card(side):
				targets = g.hand_targets(side, true)
				b.draws[side].push_front(b.hands[side].pop_at(targets[0].index))
		"015":
			targets = g.targets(enemy, g.other_lanes(lane, true), false, -1, side)
			if not targets.is_empty() and g.move_card(targets[0].uid, lane, side): g.adjust(targets[0].card, -1)
		"018":
			var chosen = g.pick_lane(side, g.other_lanes(lane))
			if chosen >= 0: g.summon(side, chosen, "hologram")
		"020":
			targets = g.targets(side, [lane], false, card.uid)
			if not targets.is_empty() and g.destroy(targets[0].uid, side): g.adjust(card, 6)
		"022": g.revive(side, g.grave_target(side, 2), lane)
		"023": g.weaken(enemy, g.other_lanes(lane), 2)
		"026":
			for k in g.other_lanes(lane): g.summon(side, k, "hatchling")
		"029", "106": g.grant_shield(card)
		"031":
			targets = g.targets(side, [lane], false, card.uid)
			if not targets.is_empty(): g.adjust(targets[0].card, 2)
		"033":
			for target in g.targets(side, [lane], true, card.uid): g.grant_shield(target.card)
		"035":
			if b.boards[side][lane].size() > 1 and not b.boards[enemy][lane].is_empty(): g.draw_card(side)
		"038":
			if b.played[enemy].has(lane): g.adjust(card, 2)
		"039": g.weaken(enemy, [lane], 2, 2)
		"040":
			for k in g.other_lanes(lane): g.summon(side, k, "fighter")
		"041":
			if b.boards[enemy][lane].size() > b.boards[side][lane].size(): g.summon(side, lane, "boarding_marine")
		"042":
			var index = g.grave_target(side)
			if index >= 0 and b.hands[side].size() < 8:
				var rescued = b.grave[side].pop_at(index)
				g.reset_modifiers(rescued)
				rescued.cost_delta = -1
				b.hands[side].append(rescued)
		"045": g.weaken(enemy, [lane], 3)
		"046":
			targets = g.targets(side, g.other_lanes(lane), true, -1, side)
			if not targets.is_empty() and g.move_card(targets[0].uid, lane, side): g.adjust(card, 4)
		"047":
			for team in range(2):
				for target in g.targets(team, [lane], false, card.uid):
					if target.power <= 2: targets.append(target)
			for target in targets: g.destroy(target.uid, side)
		"048": b.next_energy[side] = mini(2, b.next_energy[side] + 2)
		"059":
			for target in g.targets(side, [0, 1, 2], true, card.uid): g.grant_shield(target.card)
		"060":
			var here = g.targets(side, [lane], false, card.uid)
			var highest = 0
			for target in g.targets(side, g.other_lanes(lane)):
				highest = maxi(highest, g.CARDS[target.card.id].power)
			if not here.is_empty(): g.adjust(here[0].card, mini(3, highest / 2))
		"061":
			for k in range(3):
				var chosen = g.targets(enemy, [k], false)
				if not chosen.is_empty() and chosen[0].power <= 3: targets.append(chosen[0])
			for target in targets: g.destroy(target.uid, side)
		"065":
			if g.history_count(side, "revived") > 0:
				targets = g.targets(enemy, [lane], true, -1, side)
				var destination = g.pick_lane(enemy, g.other_lanes(lane, true))
				if not targets.is_empty() and destination >= 0: g.move_card(targets[0].uid, destination, side)
		"066":
			var destination = g.pick_lane(side, g.other_lanes(lane))
			targets = g.targets(side, [lane], false, card.uid).filter( func(t): return not t.card.shield and g.CARDS[t.card.id].cost <= 2)
			if destination >= 0 and not targets.is_empty():
				var uid = targets[0].uid
				if g.destroy(uid, side):
					destination = g.pick_lane(side, g.other_lanes(lane))
					for i in range(b.grave[side].size()):
						if b.grave[side][i].uid == uid:
							g.revive(side, i, destination)
							break
		"068":
			var chosen = -1
			var minimum = 999
			for i in range(b.grave[side].size()):
				var data = g.CARDS[b.grave[side][i].id]
				if data.cost in [3, 4] and data.power < minimum:
					minimum = data.power
					chosen = i
			g.revive(side, chosen, lane, 1)
		"069":
			var amount = mini(4, g.history_count(side, "revived"))
			if amount > 0: g.weaken(enemy, [lane], amount)
		"071":
			var lanes = [0, 1, 2].filter( func(k): return g.room(side, k))
			lanes.sort_custom( func(a, c): return a < c if g.score(side, a) == g.score(side, c) else g.score(side, a) < g.score(side, c))
			for k in lanes.slice(0, 2): g.revive(side, g.grave_target(side, 2), k)
		"078":
			targets = g.targets(side, [lane], false, card.uid, side).filter( func(t): return g.CARDS[t.card.id].effect == "none")
			var destination = g.pick_lane(side, g.other_lanes(lane, true))
			if destination >= 0 and not targets.is_empty() and g.move_card(targets[0].uid, destination, side): g.draw_card(side)
		"079":
			for k in g.other_lanes(lane):
				targets = g.targets(side, [k], false, -1, side).filter( func(t): return g.CARDS[t.card.id].cost == 1)
				if not targets.is_empty(): g.move_card(targets[0].uid, lane, side)
		"081":
			targets = g.targets(side, [0, 1, 2], true, card.uid).filter( func(t): return g.history_has(side, "moved", t.uid)).slice(0, 3)
			for target in targets: g.adjust(target.card, 2)
		"086":
			targets = g.targets(side, [lane], false, card.uid).filter( func(t): return not g.CARDS[t.card.id].evolution.is_empty() and not t.card.uses.get("evolved", 0))
			targets.sort_custom( func(a, c): return a.order < c.order if (g.CARDS[a.card.id].evolution.growth_ends - a.card.uses.get("growth", 0)) == (g.CARDS[c.card.id].evolution.growth_ends - c.card.uses.get("growth", 0)) else (g.CARDS[a.card.id].evolution.growth_ends - a.card.uses.get("growth", 0)) > (g.CARDS[c.card.id].evolution.growth_ends - c.card.uses.get("growth", 0)))
			if not targets.is_empty(): targets[0].card.uses["growth"] = targets[0].card.uses.get("growth", 0) + 1
		"092": blood(g, side, lane, card, [lane], 2, false)
		"094":
			if not b.played[enemy].has(lane): g.draw_card(side)
			else:
				targets = g.targets(enemy, [lane], false)
				if not targets.is_empty(): g.adjust(targets[0].card, -1)
		"096": blood(g, side, lane, card, g.other_lanes(lane), 3, false)
		"098":
			targets = g.targets(side, [lane], true, card.uid, side)
			var destination = g.pick_lane(side, g.other_lanes(lane))
			if destination >= 0 and not targets.is_empty() and g.move_card(targets[0].uid, destination, side): g.adjust(targets[0].card, -1)
		"099":
			targets = g.targets(side, [lane], false, card.uid).filter( func(t): return t.card.shield)
			if not targets.is_empty():
				g.remove_shield(targets[0].card, "remove", side)
				g.adjust(targets[0].card, 3)
		"101": blood(g, side, lane, card, [lane], 999999, true)
		"102":
			if b.boards[side][lane].size() == 1: g.grant_shield(card)
		"103", "107":
			targets = g.targets(enemy, [lane], g.skill_id(card) == "103")
			if not targets.is_empty():
				g.remove_shield(targets[0].card, "remove", side)
				if g.skill_id(card) == "103": g.adjust(targets[0].card, -2)
				elif targets[0].power <= 2: g.destroy(targets[0].uid, side)
		"109":
			if b.boards[side][lane].any( func(c): return c.shield): g.survey(side, card.uid)
		"110":
			for team in range(2):
				for target in g.targets(team, [lane], false, card.uid): g.adjust(target.card, -2)
			for team in range(2):
				for target in g.targets(team, [lane], false, card.uid):
					if target.power == 0: targets.append(target)
			for target in targets: g.destroy(target.uid, side)
		"112":
			if g.skill_uses(card).get("discount", 0) < 1:
				targets = g.targets(side, [lane], false, card.uid).filter( func(t): return not t.card.shield)
				if not targets.is_empty() and g.destroy(targets[0].uid, side):
					var hand = g.hand_targets(side, true, true)
					if not hand.is_empty() and g.card_cost(hand[0].card) > 1:
						hand[0].card.cost_delta -= 1
						g.skill_uses(card)["discount"] = 1
		"113": g.repair_budget(side, lane, 3)
		"120":
			if g.skill_uses(card).get("salvage", 0) < 1 and b.hands[side].size() < 8:
				var chosen = -1
				var maximum = -1
				for i in range(b.grave[side].size()):
					var cost = g.CARDS[b.grave[side][i].id].cost
					if cost <= 4 and cost > maximum:
						maximum = cost
						chosen = i
				if chosen >= 0:
					var rescued = b.grave[side].pop_at(chosen)
					g.reset_modifiers(rescued)
					rescued.cost_delta = 1 - g.CARDS[rescued.id].cost
					b.hands[side].append(rescued)
					g.skill_uses(card)["salvage"] = 1
		"121":
			targets = g.targets(side, [0, 1, 2], false, card.uid).filter( func(t): return g.history_has(side, "paid", t.uid)).slice(0, 3)
			for target in targets: g.heal(target.card, 2)
	g.flush_reactions()

static func blood(g, side: int, _lane: int, card: Dictionary, lanes: Array, ceiling: int, high: bool):
	if not g.device_ready(card): return
	var targets = g.targets(1 - side, lanes, high).filter( func(t): return t.power <= ceiling)
	if targets.is_empty(): return
	if not g.pay_power(card, g.CARDS[g.skill_id(card)].blood_price.self_power_cost): return
	g.spend_device(card)
	g.skill_uses(card)["blood"] = g.skill_uses(card).get("blood", 0) + 1
	g.destroy(targets[0].uid, side)

static func finish_card(g, side: int, lane: int, card: Dictionary):
	for id in g.skill_ids(card, "被动"):
		var live = g.locate(card.uid)
		if live.is_empty(): break
		var previous = g.push_skill(card, id)
		finish_one(g, side, live.lane, card)
		g.pop_skill(card, previous)
	g.flush_reactions()

static func finish_one(g, side: int, lane: int, card: Dictionary):
	g.actor = side
	if Balance.finish_card(g, side, lane, card):
		g.flush_reactions()
		return
	var b = g.s.battle
	var enemy = 1 - side
	var used = g.skill_uses(card).get("end", 0)
	var targets = []
	var worked = false
	match g.skill_id(card):
		"008":
			if used < 3 and b.played[enemy].has(lane) and not g.targets(enemy, [lane]).is_empty():
				g.weaken(enemy, [lane], 1)
				worked = true
		"019":
			if b.energy[side] - spent_energy(g, side) > 0 and used < 3:
				g.adjust(card, 1)
				worked = true
		"032":
			if b.played[enemy].has(lane) and used < 2:
				g.adjust(card, 1)
				worked = true
		"043":
			if used < 2:
				for k in range(3):
					if b.boards[side][k].is_empty() and g.queued_at(k, side) == 0:
						worked = g.summon(side, k, "colonist")
						break
		"044":
			if used < 2:
				for k in g.other_lanes(lane):
					if not g.targets(enemy, [k]).is_empty():
						g.weaken(enemy, [k], 1)
						worked = true
		"052":
			if used < 2: worked = g.summon(side, lane, "clone_recruit")
		"053":
			targets = g.targets(side, [lane], false, card.uid)
			if used < 3 and not targets.is_empty():
				g.adjust(targets[0].card, 1)
				worked = true
		"055":
			targets = g.targets(enemy, g.other_lanes(lane), true, -1, side)
			if used < 2 and not targets.is_empty(): worked = g.move_card(targets[0].uid, lane, side)
		"056":
			targets = g.targets(enemy, [lane])
			if used < 2 and not targets.is_empty():
				for target in targets: g.adjust(target.card, -1)
				worked = true
		"057":
			for ally in b.boards[side][lane].duplicate():
				if used >= 4: break
				if ally.uid != card.uid and ally.played_round == b.round:
					g.adjust(ally, 1)
					used += 1
			g.skill_uses(card)["end"] = used
		"058":
			if b.boards[side][lane].size() == 1: g.destroy(card.uid, side)
		"075":
			var found = g.locate(g.skill_uses(card).get("mark", -1))
			if used < 2 and not found.is_empty() and found.side == enemy:
				g.adjust(found.card, -2)
				worked = true
		"083":
			targets = g.targets(enemy, [lane], false)
			if used < 3 and not targets.is_empty():
				g.adjust(targets[0].card, -1)
				worked = true
		"088":
			var own = g.locate(card.uid)
			targets = g.targets(enemy, [lane]).filter( func(t): return t.power > g.card_power(side, lane, own.index))
			if used < 2 and not targets.is_empty():
				g.adjust(targets[0].card, -2)
				worked = true
		"089":
			if g.device_ready(card) and b.boards[side][lane].size() > b.boards[enemy][lane].size():
				targets = g.targets(enemy, [lane], true, -1, side)
				var destination = g.pick_lane(enemy, g.other_lanes(lane, true))
				if destination >= 0 and not targets.is_empty(): worked = g.move_card(targets[0].uid, destination, side)
				if worked: g.spend_device(card)
		"093":
			if used < 2:
				for team in range(2):
					for target in g.targets(team, [lane], false, card.uid):
						g.adjust(target.card, -1)
						worked = true
		"106":
			targets = g.targets(side, [lane], false, card.uid).filter( func(t): return not t.card.shield)
			if used < 2 and not targets.is_empty(): worked = g.grant_shield(targets[0].card)
		"114":
			if g.device_ready(card) and not g.targets(enemy, [lane]).is_empty():
				g.weaken(enemy, [lane], 3)
				g.spend_device(card)
		"117":
			if g.device_ready(card):
				var spawned = g.summon(side, lane, "fighter")
				spawned = g.summon(side, lane, "fighter") or spawned
				if spawned: g.spend_device(card)
	if worked: g.skill_uses(card)["end"] = used + 1
	g.flush_reactions()

static func spent_energy(g, side: int) -> int:
	return int(g.s.battle.get("spent", [0, 0])[side])
