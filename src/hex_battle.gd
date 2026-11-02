extends RefCounted

const CYAN = Color("b0d6d9")
const GOLD = Color("e6bd79")
const CORAL = Color("e5aa96")
const INK = Color("f3eddb")
const MUTED = Color("b9cbbc")
const NAVY = Color("25433f")
const SLOT_RADIUS = 44.0

func lane_center(lane: int) -> Vector2:
	return Vector2(270 + lane * 450, 409)

func lane_polygon(lane: int, inset: float = 0.0) -> PackedVector2Array:
	var c = lane_center(lane)
	var w = 202.0 - inset
	var h = 247.0 - inset
	return PackedVector2Array([c + Vector2(0, - h), c + Vector2(w, - h * 0.5), c + Vector2(w, h * 0.5), c + Vector2(0, h), c + Vector2( - w, h * 0.5), c + Vector2( - w, - h * 0.5)])

func hex_points(center: Vector2, radius: float, x_scale: float = 1.0) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var a = TAU * i / 6.0
		points.append(center + Vector2(cos(a) * x_scale, sin(a)) * radius)
	return points

func slot_center(side: int, lane: int, index: int) -> Vector2:
	var c = lane_center(lane)
	var y = -158.0 + (index / 2 as int) * 80 if side == 1 else 78.0 + (index / 2 as int) * 80
	return c + Vector2(-53 if index % 2 == 0 else 53, y)

func hand_rect(v, index: int) -> Rect2:
	var count = v.game.s.battle.hands[0].size()
	var width = minf(125.0, (1030.0 - maxi(count - 1, 0) * 9.0) / maxi(count, 1))
	var x = 33.0 + index * (width + 9)
	return Rect2(x, 725 - (9 if v.selected == index else 0), width, 134)

func poly(v, points: PackedVector2Array, fill: Color, border: Color, width: float = 1.5):
	v.draw_colored_polygon(points, fill)
	var edge = points.duplicate()
	edge.append(edge[0])
	v.draw_polyline(edge, border, width, true)

func draw(v):
	var b = v.game.s.battle
	var result = v.game.s.phase == "result"

	v.panel(Rect2(24, 77, 1392, 64), Color("2a4744"), Color("637d70"), 10)
	var enemy = v.game.enemy_for_stage()
	v.portrait(enemy.portrait, Rect2(36, 86, 44, 44))
	v.text_at("敌方  /  " + enemy.name, Vector2(94, 103), 18, CORAL, true)
	v.text_at("%s  ·  手牌 %d  ·  牌库 %d  ·  点击查看敌情" % [enemy.archetype, b.hands[1].size(), b.draws[1].size()], Vector2(95, 126), 12, MUTED)
	if not v.busy: v.hit(Rect2(30, 80, 438, 57), "enemy" + str(v.game.s.stage), v.change.bind("enemy", v.game.s.stage), enemy.desc)
	v.centered("ROUND  %02d / 06" % b.round, Rect2(498, 86, 200, 22), 19, INK, true)
	v.centered(v.resolution_label if v.busy else ("你方先揭示" if b.round % 2 == 1 else "敌方先揭示"), Rect2(476, 111, 244, 21), 12, GOLD)
	for i in range(6):
		v.draw_rect(Rect2(744 + i * 22, 101, 15, 7), CYAN if i < b.round else Color("49645d"))
	v.button("牌组", Rect2(916, 89, 90, 39), "deck", null, false, v.busy)
	v.button("记录", Rect2(1016, 89, 90, 39), "log", null, false, v.busy)
	v.button("规则", Rect2(1116, 89, 90, 39), "help", null, false, v.busy)
	v.button("主菜单", Rect2(1216, 89, 182, 39), "menu", null, false, v.busy)

	for lane in range(3): draw_sector(v, lane)

	v.panel(Rect2(20, 686, 1400, 192), Color("2a4744"), Color("637d70"), 12)
	v.text_at("部署手牌", Vector2(36, 710), 18, CYAN, true)
	v.text_at("牌库 %d  /  待揭示 %d" % [b.draws[0].size(), b.queue.size()], Vector2(143, 709), 12, MUTED)
	v.text_at("点击手牌 → 六边战区   ·   Z 撤回   ·   空格结束", Vector2(544, 709), 12, MUTED)
	for i in range(b.hands[0].size()): v.draw_hand_card(b.hands[0][i], hand_rect(v, i), i)
	if b.hands[0].is_empty(): v.centered("手牌已部署，结束回合后继续抽牌。", Rect2(33, 748, 1000, 70), 20, MUTED)
	v.draw_line(Vector2(1083, 705), Vector2(1083, 860), Color("617a70"), 1)
	v.text_at("可用能量", Vector2(1106, 714), 13, MUTED)
	v.badge(str(v.displayed_energy()) if not result else "—", Vector2(1140, 749), CYAN, 24)
	v.text_at("/ %d" % b.energy[0], Vector2(1177, 756), 22, MUTED)
	for i in range(mini(b.energy[0], 10)):
		v.draw_rect(Rect2(1107 + i * 28, 784, 20, 5), CYAN if i < v.displayed_energy() else Color("49645d"))
	var speed_text = "简化动画" if v.animation_speed == 0 else "动画 ×%d" % v.animation_speed
	v.button(speed_text, Rect2(1271, 703, 128, 37), "speed", null, false, v.busy)
	v.button("撤回", Rect2(1271, 748, 128, 37), "undo", null, false, b.queue.is_empty() or v.busy or result)
	v.button("正在揭示…" if v.busy else "结束回合  →", Rect2(1106, 811, 293, 48), "end", null, true, v.busy or result)
	var hint = "选择手牌，点亮你的下一个据点。"
	if v.selected >= 0 and v.selected < b.hands[0].size():
		hint = "部署「%s」 · 金色边框为可用战区" % v.Rules.CARDS[b.hands[0][v.selected].id].name
	if v.gate_uid >= 0: hint = "调度已启动 · 点击目标单位，再选择另一个战区"
	if v.moving_uid >= 0: hint = "选择移动目的地 · 右键或 Esc 取消"
	if v.swap_uid >= 0: hint = "换位 · 点击另一战区的己方无技能单位（满区也可交换）"
	if v.busy: hint = v.resolution_label
	v.centered(hint, Rect2(200, 659, 1040, 23), 13, GOLD if v.selected >= 0 or v.busy else MUTED)
	draw_effects(v)
	if result:
		v.draw_result()

func draw_sector(v, lane: int):
	var b = v.game.s.battle
	var c = lane_center(lane)
	var known = lane < b.round or b.peeked[0].has(lane)
	var loc = v.Rules.REGIONS[int(b.regions[lane])]
	var own_score = v.game.score(0, lane)
	var enemy_score = v.game.score(1, lane)
	var leading = CYAN if own_score > enemy_score else (CORAL if enemy_score > own_score else Color("4c6a80"))
	var selected = (v.selected >= 0 or v.moving_uid >= 0) and not v.busy
	var capacity = b.boards[0][lane].size() + v.game.queued_at(lane)
	var affordable = selected and (v.moving_uid >= 0 or v.game.card_cost(b.hands[0][v.selected]) <= v.game.available_energy())
	var valid = selected and capacity < 4 and affordable
	if v.moving_uid >= 0:
		var moving = v.game.locate(v.moving_uid)
		if not moving.is_empty(): capacity = b.boards[moving.side][lane].size() + v.game.queued_at(lane, moving.side)
		valid = not moving.is_empty() and capacity < 4 and moving.lane != lane and v.game.can_be_moved(v.moving_uid, 0)
		if v.gate_uid >= 0:
			var gate = v.game.locate(v.gate_uid)
			valid = valid and not gate.is_empty() and v.game.can_activate(v.gate_uid)
	var outline = GOLD if valid else (CORAL if selected else leading)
	var outer = lane_polygon(lane)

	var shadow = outer.duplicate()
	for i in range(shadow.size()): shadow[i] += Vector2(0, 6)
	poly(v, shadow, Color("040b12"), Color("040b12"), 2)
	poly(v, outer, Color("536f61"), outline, 2.5 if valid else 1.7)
	poly(v, lane_polygon(lane, 7), Color("435f56"), Color(outline, 0.25), 1)
	var terrain_points = lane_polygon(lane, 10)
	var uv = PackedVector2Array()
	for p in terrain_points: uv.append((p - (c - Vector2(245, 245))) / 490.0)
	var terrain_index = b.get("terrain_art", [0, 1, 2])[lane]
	v.draw_polygon(terrain_points, PackedColorArray([Color(0.9, 0.95, 0.85, 0.78)]), uv, v.terrain_art[terrain_index])
	var enemy_half = PackedVector2Array([outer[0], outer[1], c + Vector2(198, 0), c - Vector2(198, 0), outer[5]])
	var own_half = PackedVector2Array([c - Vector2(198, 0), c + Vector2(198, 0), outer[2], outer[3], outer[4]])
	v.draw_colored_polygon(enemy_half, Color(0.25, 0.24, 0.19, 0.16))
	v.draw_colored_polygon(own_half, Color(0.19, 0.32, 0.27, 0.12))
	v.centered("敌方  %02d" % enemy_score, Rect2(c + Vector2(-70, -222), Vector2(140, 30)), 19, CORAL, true)
	v.centered("你方  %02d" % own_score, Rect2(c + Vector2(-70, 204), Vector2(140, 30)), 21, CYAN, true)
	v.text_at("0%d" % (lane + 1), c + Vector2(-185, -5), 13, MUTED, true)
	for side in [1, 0]:
		var board = b.boards[side][lane]
		var pending = []
		if side == 0:
			for move in b.queue:
				if move.lane == lane: pending.append(move.card)
		for index in range(4):
			var center = slot_center(side, lane, index)
			var active = not v.reveal_fx.is_empty() and v.reveal_fx.source.side == side and v.reveal_fx.source.lane == lane and v.reveal_fx.source.index == index
			if active and not v.reveal_fx.flipped:
				var t = clampf(v.reveal_fx.age / maxf(v.reveal_fx.duration * 0.37, 0.001), 0, 1)
				var x_scale = maxf(0.05, 1.0 - t)
				poly(v, hex_points(center, SLOT_RADIUS, x_scale), Color("6e8877"), GOLD, 2)
				if x_scale > 0.45: v.symbol(center, 20, "共鸣", GOLD)
			elif index < board.size():
				var x_scale = 1.0
				if active:
					x_scale = clampf((v.reveal_fx.age / maxf(v.reveal_fx.duration, 0.001) - 0.37) / 0.25, 0.06, 1.0)
				draw_unit(v, board[index], center, v.game.card_power(side, lane, index), side, false, true, x_scale)
			elif side == 0 and index - board.size() < pending.size():
				var card = pending[index - board.size()]
				draw_unit(v, card, center, v.game.raw_power(card), side, true)
			else:
				var points = hex_points(center, SLOT_RADIUS)
				poly(v, points, Color("557367"), Color(outline, 0.65) if valid and side == 0 else Color("809984"))
				var plus_colour = GOLD if valid and side == 0 else Color("b7c4ac")
				v.draw_line(center - Vector2(7, 0), center + Vector2(7, 0), plus_colour, 1.3, true)
				v.draw_line(center - Vector2(0, 7), center + Vector2(0, 7), plus_colour, 1.3, true)
				if valid and side == 0:
					v.centered("可部署", Rect2(center + Vector2(-30, 15), Vector2(60, 18)), 10, GOLD)
	v.panel(Rect2(c + Vector2(-158, -38), Vector2(316, 78)), Color("38564f"), Color("77917e"), 8)
	v.start_ui.icon(v, loc.icon if known else "help", Rect2(c + Vector2(-145, -29), Vector2(21, 21)))
	v.centered(loc.name if known else "未知地形", Rect2(c + Vector2(-119, -32), Vector2(256, 28)), 19, INK if known else MUTED, true)
	v.SkillText.draw(v, loc.short if known else "第 %d 回合扫描揭晓，可提前部署。" % (lane + 1), c + Vector2(-138, 7), 282, 12, MUTED, 18)
	v.centered(v.Rules.Terrain.status(v.game, lane) if known else "尚未生效", Rect2(c + Vector2(-148, 17), Vector2(296, 15)), 10, Color("c4d4bc"))

	var fraction = float(own_score) / (own_score + enemy_score) if own_score + enemy_score > 0 else 0.5
	v.draw_rect(Rect2(c + Vector2(-105, 34), Vector2(210, 3)), Color(CORAL, 0.65))
	v.draw_rect(Rect2(c + Vector2(-105, 34), Vector2(210 * fraction, 3)), CYAN)
	if selected:
		var action = "move" if v.moving_uid >= 0 else "lane"
		v.hit_polygon(outer, action + str(lane), v.change.bind(action, lane), "战区已满" if capacity >= 4 else ("能量不足" if not affordable else "选择这个战区"))
	elif not v.busy:
		v.hit(Rect2(c + Vector2(-158, -38), Vector2(316, 78)), "terrain%d" % lane, func(): pass, v.Rules.Terrain.tooltip(v.game, lane) if known else "区域尚未揭示。双方都可提前部署。")

func draw_unit(v, card: Dictionary, center: Vector2, power: int, side: int, pending: bool = false, interactive: bool = true, x_scale: float = 1.0):
	var radius = SLOT_RADIUS
	var points = hex_points(center, radius, x_scale)
	var tint = GOLD if pending else (CYAN if side == 0 else CORAL)
	poly(v, points, Color("304c5c"), tint, 2)
	var texture = v.get_card_texture(card.id)
	if texture != null:
		var image_points = hex_points(center, radius - 4, x_scale)
		var uv = PackedVector2Array()
		for i in range(6):
			var angle = TAU * i / 6.0
			uv.append(Vector2(cos(angle), sin(angle)) * 0.46 + Vector2(0.5, 0.5))
		v.draw_polygon(image_points, PackedColorArray([Color(1, 1, 1, 0.55) if pending else Color.WHITE]), uv, texture)
	if x_scale < 0.8: return
	var data = v.Rules.CARDS[card.id]
	v.draw_rect(Rect2(center + Vector2(-30, 12), Vector2(60, 18)), Color(0.025, 0.06, 0.1, 0.85))
	v.centered("待揭示" if pending else data.name, Rect2(center + Vector2(-31, 11), Vector2(62, 18)), 10, GOLD if pending else INK)
	v.badge(str(power), center + Vector2(37, 25), GOLD, 13)
	v.badge(str(v.game.card_cost(card)), center + Vector2(-36, -24), Color("6f9e9a"), 10)
	if card.get("shield", false):
		var shield_edge = hex_points(center, radius + 4)
		shield_edge.append(shield_edge[0])
		v.draw_polyline(shield_edge, Color(CYAN, 0.7), 2, true)
	if not pending and ( not data.evolution.is_empty() or not data.device.is_empty()):
		var label = "成长 %d/%d" % [card.uses.get("growth", 0), data.evolution.growth_ends] if not data.evolution.is_empty() else "装置 %d" % v.game.device_remaining(card)
		v.panel(Rect2(center + Vector2(-25, -34), Vector2(58, 17)), Color("365363"), Color("829aa7"), 8)
		v.centered(label, Rect2(center + Vector2(-25, -34), Vector2(58, 17)), 10, INK)
	if data.trigger.contains("持续") and not pending:
		v.draw_arc(center, radius + 3, -0.4, 1.1, 16, Color(tint, 0.55), 1.5, true)
	if interactive:
		var usable = not pending and (side == 0 or (v.gate_uid >= 0 and not v.game.locate(v.gate_uid).is_empty() and v.game.locate(v.gate_uid).card.id == "055")) and not v.busy and (v.game.can_activate(card.uid) or v.game.can_reboot(card.uid) or v.gate_uid >= 0 or v.swap_uid >= 0)
		var inspectable = not pending and not card.get("inherited", {}).is_empty() and not v.busy
		var callback = func(): pass
		if usable: callback = v.change.bind("activate", card.uid)
		elif inspectable: callback = v.change.bind("skills", card.uid)
		var hit_id = "activate" + str(card.uid) if usable else ("skills" + str(card.uid) if inspectable else "unit_%d_%s" % [side, str(center)])
		var hint = "（点击查看技能）" if inspectable else ("（点击使用技能）" if usable else "")
		v.hit_polygon(points, hit_id, callback, "%s · %d费 / %d战力 · %s%s" % [data.name, v.game.card_cost(card), power, data.text, hint])
		v.card_hint(card)
		if usable: v.draw_circle(center + Vector2(36, -26), 4, CYAN)

func draw_effects(v):
	for effect in v.fx:
		var t = clampf(effect.age / maxf(effect.duration, 0.001), 0, 1)
		var alpha = 1.0 - t
		var color = Color(effect.color, alpha)
		match effect.type:
			"evolve":
				var points = hex_points(effect.to, SLOT_RADIUS + 12 * sin(t * PI))
				var uv = PackedVector2Array()
				for i in range(6): uv.append(Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 0.46 + Vector2(0.5, 0.5))
				v.draw_polygon(points, PackedColorArray([Color(1, 1, 1, alpha)]), uv, v.get_card_texture(effect.card.id))
				points.append(points[0])
				v.draw_polyline(points, color, 4, true)
			"destroy":
				var center = effect.to + Vector2(0, -20 * t)
				var points = hex_points(center, SLOT_RADIUS * (1 - t * 0.3))
				var uv = PackedVector2Array()
				for i in range(6): uv.append(Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 0.46 + Vector2(0.5, 0.5))
				v.draw_polygon(points, PackedColorArray([Color(1, 0.45, 0.35, alpha)]), uv, v.get_card_texture(effect.card.id))
			"flight":
				var eased = 1.0 - pow(1.0 - t, 3)
				var pos = effect.from.lerp(effect.to, eased) + Vector2(0, - sin(t * PI) * 85)
				v.draw_line(pos.lerp(effect.from, 0.08), pos, Color(GOLD, alpha), 4, true)
				draw_unit(v, effect.card, pos, v.game.raw_power(effect.card), effect.get("side", 0), true, false)
				v.draw_arc(effect.to, 12 + t * 48, 0, TAU, 32, Color(GOLD, alpha * 0.5), 1.5, true)
			"beam":
				var end = effect.from.lerp(effect.to, minf(t * 2.5, 1))
				v.draw_line(effect.from, end, Color(effect.color, alpha * 0.2), 12, true)
				v.draw_line(effect.from, end, color, 3, true)
				v.draw_circle(end, 4, color)
			"pulse":
				var radius = 15 + t * 60
				var ring = hex_points(effect.to, radius)
				ring.append(ring[0])
				v.draw_polyline(ring, color, 2.5 * alpha + 0.5, true)
				for i in range(6):
					var angle = i * TAU / 6
					var pos = effect.to + Vector2(cos(angle), sin(angle)) * (radius + 8)
					v.draw_circle(pos, 2.5 * alpha, color)
			"float":
				v.centered(effect.text, Rect2(effect.to + Vector2(-95, -30 - t * 45), Vector2(190, 32)), 25 if effect.text.length() < 5 else 15, color, true)
			"region":
				var points = lane_polygon(effect.lane, 5)
				points.append(points[0])
				v.draw_polyline(points, color, 4 * alpha + 1, true)
			"banner":
				var opacity = sin(t * PI)
				v.draw_rect(Rect2(540, 378, 360, 64), Color(0.04, 0.1, 0.16, opacity * 0.95))
				v.centered(effect.text, Rect2(540, 378, 360, 64), 26, Color(GOLD, opacity), true)
