extends RefCounted

static func gate(g, card: Dictionary, key: String, event: Dictionary, limit: int) -> bool:
	if g.skill_uses(card).get(key, 0) >= limit or g.skill_uses(card).get(key + "_round", -1) == event.round: return false
	g.skill_uses(card)[key + "_round"] = event.round
	return true

static func count(g, card: Dictionary, key: String):
	g.skill_uses(card)[key] = g.skill_uses(card).get(key, 0) + 1

static func once(g, card: Dictionary, key: String) -> bool:
	if g.skill_uses(card).get(key, 0) > 0: return false
	g.skill_uses(card)[key] = 1
	return true

static func trigger(g, listener: Dictionary, card: Dictionary, e: Dictionary):
	if preload("res://src/balance_effects.gd").reaction(g, listener, card, e): return
	var side = listener.side
	var lane = listener.lane
	var self_event = e.uid == card.uid
	var own = e.side == side
	var other_own = own and not self_event
	var live = g.locate(e.uid)
	var enemy_block = e.kind == "shield_lost" and e.get("reason", "") == "weaken" and e.get("actor", -1) == 1 - side
	match listener.id:
		"030":
			if own and enemy_block and gate(g, card, "forge", e, 2):
				var hand = g.hand_targets(side, true, true)
				if not hand.is_empty():
					g.adjust(hand[0].card, 2)
					count(g, card, "forge")
		"062":
			if self_event and e.kind == "revived" and once(g, card, "reborn"): g.adjust(card, 3)
		"064":
			if self_event and e.kind == "moved" and once(g, card, "first_move"):
				g.revive(side, g.grave_target(side, 1), e.from_lane)
		"067":
			if self_event and e.kind == "destroyed" and g.skill_uses(card).get("death", 0) < 1 and g.draw_card(side): count(g, card, "death")
		"070":
			if self_event and e.kind == "destroyed" and g.skill_uses(card).get("death", 0) < 1:
				var total = 0
				for target in g.targets(side, [e.lane], false, card.uid): total += g.heal(target.card, 1)
				if total > 0: count(g, card, "death")
		"072":
			if self_event and e.kind == "moved" and once(g, card, "first_move"): g.weaken(1 - side, [e.lane], 1)
		"073":
			if self_event and e.kind == "moved" and gate(g, card, "move_gain", e, 3):
				g.adjust(card, 1)
				count(g, card, "move_gain")
		"074":
			if other_own and e.kind == "moved" and e.lane == lane and gate(g, card, "arrival", e, 2) and not live.is_empty():
				g.adjust(live.card, 2)
				count(g, card, "arrival")
		"075":
			if self_event and e.kind == "moved" and once(g, card, "first_move"):
				var choices = g.targets(1 - side, [e.from_lane])
				g.skill_uses(card)["mark"] = -1 if choices.is_empty() else choices[0].uid
		"080":
			if self_event and e.kind == "moved" and once(g, card, "first_move"): g.weaken(1 - side, [e.from_lane], 2)
		"090":
			if other_own and e.kind == "evolved" and e.lane == lane and g.device_ready(card):
				g.spend_device(card)
				g.adjust(card, 2)
				g.draw_card(side)
				g.draw_card(side)
		"095":
			if other_own and e.kind == "paid" and gate(g, card, "supply", e, 2) and g.draw_card(side): count(g, card, "supply")
		"097":
			if self_event and e.kind == "destroyed" and g.device_ready(card):
				var worked = false
				for target in g.targets(1 - side, [e.lane]):
					var was_shield = target.card.shield
					g.adjust(target.card, -1)
					var now = g.locate(target.uid)
					if was_shield and not target.card.shield: worked = true
					if not now.is_empty() and g.card_power(now.side, now.lane, now.index) < target.power: worked = true
				if worked:
					g.spend_device(card)
					count(g, card, "death")
		"100":
			if not own and e.kind == "destroyed" and e.lane == lane and once(g, card, "kill_reward"): g.adjust(card, 2)
		"104":
			if other_own and e.kind == "shield_gained" and gate(g, card, "shield_forge", e, 3) and not live.is_empty():
				g.adjust(live.card, 1)
				count(g, card, "shield_forge")
		"108":
			if other_own and enemy_block and g.CARDS[e.id].effect == "none" and g.device_ready(card):
				g.spend_device(card)
				g.summon(side, lane, "colonist")
		"115":
			if other_own and e.kind == "paid" and once(g, card, "energy"):
				g.s.battle.next_energy[side] = mini(2, g.s.battle.next_energy[side] + 1)
		"118":
			if other_own and e.kind == "paid" and gate(g, card, "paid_growth", e, 3):
				g.adjust(card, 1)
				count(g, card, "paid_growth")
		"119":
			if self_event and e.kind == "shield_lost" and g.skill_uses(card).get("escape", 0) < 1 and not live.is_empty():
				var destination = g.pick_lane(side, g.other_lanes(live.lane))
				if destination >= 0 and g.move_card(card.uid, destination, side): count(g, card, "escape")
		"016":
			if self_event and e.kind == "moved" and once(g, card, "first_move"): g.adjust(card, 2)
