extends RefCounted
const PAPER = Color("f1ebd9")
const INK = Color("304b49")
const MUTED = Color("687d72")
var last_rect = Rect2()

func lines(v, value: String, width: float, size: int) -> Array[String]:
	var result: Array[String] = []
	var line = ""
	for ch in value:
		if ch == "\n" or (v.font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and ch not in "，。！？：；、）】》”"):
			result.append(line)
			line = "" if ch == "\n" else ch
		else: line += ch
	if line != "": result.append(line)
	return result

func draw(v):
	var item = {}
	for hit in v.hits:
		if hit.id == v.hovered: item = hit
	if item.is_empty() and v.selected >= 0 and v.screen not in ["builder", "archive"]:
		for hit in v.hits:
			if hit.id == "select" + str(v.selected):
				item = hit
				break
	if item.is_empty(): return
	var card = item.get("card", {})
	if card.is_empty():
		if item.tip == "": return
		var rows = lines(v, item.tip, 324, 15)
		var size = Vector2(356, rows.size() * 23 + 28)
		var pos = v.pointer_position + Vector2(18, 18)
		pos.x = clampf(pos.x, 14, 1426 - size.x)
		pos.y = clampf(pos.y, 74, 886 - size.y)
		last_rect = Rect2(pos, size)
		v.panel(last_rect, PAPER, Color("9baf9a"), 18)
		for i in range(rows.size()): v.SkillText.draw(v, rows[i], pos + Vector2(16, 26 + i * 23), 324, 15, INK, 23, true)
		return
	var data = v.Rules.CARDS[card.id]
	var ability = lines(v, data.text, 354, 17)
	var notes = lines(v, data.note, 354, 13)
	var state = v.game.state_line(card)
	var states = lines(v, state, 354, 14) if state != "" else []
	var evolve = not data.evolution.is_empty()
	var height = 144 + ability.size() * 27 + notes.size() * 20 + states.size() * 22 + (64 if evolve else 0)
	var size = Vector2(394, height)
	var pos = v.pointer_position + Vector2(22, - height * 0.42)
	if pos.x + size.x > 1426: pos.x = v.pointer_position.x - size.x - 22
	pos.x = clampf(pos.x, 14, 1426 - size.x)
	pos.y = clampf(pos.y, 74, 886 - size.y)
	last_rect = Rect2(pos, size)
	v.panel(last_rect, PAPER, Color("9daf98"), 22)
	v.panel(Rect2(pos + Vector2(10, 10), Vector2(374, 102)), Color("dbe3ce"), Color("dbe3ce"), 16)
	v.portrait(card.id, Rect2(pos + Vector2(18, 18), Vector2(86, 86)))
	v.text_at(data.name, pos + Vector2(119, 43), 23, INK, true)
	v.text_at(data.kind + "  /  " + ("衍生" if not data.collectible else "#" + card.id), pos + Vector2(120, 66), 12, MUTED)
	var power = v.game.raw_power(card)
	if v.game.s.get("battle", {}).has("boards"):
		var live = v.game.locate(card.get("uid", -1))
		if not live.is_empty(): power = v.game.card_power(live.side, live.lane, live.index)
	v.text_at("%d 费   /   %d 战力" % [v.game.card_cost(card), power], pos + Vector2(120, 92), 17, INK, true)
	var y = 137.0
	for row in ability:
		v.SkillText.draw(v, row, pos + Vector2(20, y), 354, 17, INK, 27, true)
		y += 27
	y += 3
	for row in notes:
		v.SkillText.draw(v, row, pos + Vector2(20, y), 354, 13, MUTED, 20, true)
		y += 20
	for row in states:
		v.text_at(row, pos + Vector2(20, y + 3), 14, Color("476d65"), true)
		y += 22
	if evolve:
		var target = v.Rules.CARDS[data.evolution.target_id]
		v.portrait(data.evolution.target_id, Rect2(pos + Vector2(20, y + 6), Vector2(46, 46)))
		v.text_at("进化 → " + target.name, pos + Vector2(80, y + 25), 15, INK, true)
		v.text_at("%d 费 / %d 战力 · 保留增减益，额外战力-1" % [target.cost, target.power], pos + Vector2(80, y + 46), 12, MUTED)
