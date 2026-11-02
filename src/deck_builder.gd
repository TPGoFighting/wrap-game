extends RefCounted
const PAGE_SIZE = 15
const CYAN = Color("b0d6d9")
const GOLD = Color("e6bd79")
const MUTED = Color("b9cbbc")
const INK = Color("f3eddb")

func filtered(v) -> Array:
	var ids = v.game.collectible_ids()
	var query = v.builder_query.strip_edges().to_lower()
	ids = ids.filter( func(id):
		var data = v.Rules.CARDS[id]
		return (v.builder_cost == -1 or data.cost == v.builder_cost) and (query == "" or (data.name + " " + data.text + " " + data.kind).to_lower().contains(query))
	)
	ids.sort_custom( func(a, b): return a < b if v.Rules.CARDS[a].cost == v.Rules.CARDS[b].cost else v.Rules.CARDS[a].cost < v.Rules.CARDS[b].cost)
	return ids

func draw(v):
	v.text_at("选择你的出战牌组", Vector2(32, 102), 29, INK, true)
	v.text_at("121 张全部开放 · 选满12张 · 每张限1张 · 自由混编", Vector2(34, 136), 14, MUTED)
	var costs = [-1, 0, 1, 2, 3, 4, 5]
	for i in range(costs.size()):
		var cost = costs[i]
		v.button("全部" if cost == -1 else "%d费" % cost, Rect2(32 + i * 92, 158, 84, 34), "builder_cost", cost, cost == v.builder_cost)
	v.button("预设卡组", Rect2(706, 158, 124, 34), "builder_preset")
	v.button("我的卡组", Rect2(838, 158, 124, 34), "builder_library")
	v.button("随机组牌", Rect2(970, 158, 124, 34), "builder_random")
	var ids = filtered(v)
	var pages = maxi(1, ceili(ids.size() / float(PAGE_SIZE)))
	v.builder_page = clampi(v.builder_page, 0, pages - 1)
	for i in range(PAGE_SIZE):
		var index = v.builder_page * PAGE_SIZE + i
		if index >= ids.size(): break
		var id = ids[index]
		var data = v.Rules.CARDS[id]
		var chosen = v.draft_deck.has(id)
		var rect = Rect2(32 + (i % 5) * 214, 208 + (i / 5 as int) * 194, 203, 183)
		v.panel(rect, Color("496a7b") if chosen else Color("304c5c"), GOLD if chosen else Color("78929f"), 10)
		v.portrait(id, Rect2(rect.position + Vector2(59, 7), Vector2(85, 85)))
		v.badge(str(data.cost), rect.position + Vector2(23, 23), Color("6f9e9a"), 15)
		v.badge(str(data.power), rect.position + Vector2(180, 23), GOLD, 15)
		if chosen: v.text_at("已选", rect.position + Vector2(11, 80), 11, GOLD, true)
		v.centered(data.name, Rect2(rect.position + Vector2(5, 94), Vector2(193, 24)), 16, INK, true)
		v.paragraph(data.text, rect.position + Vector2(11, 134), 181, 11, MUTED, 15)
		v.hit(rect, "builder_card" + id, v.change.bind("builder_card", id), "%s · %d费 / %d战力 · %s" % [data.name, data.cost, data.power, data.text])
		v.card_hint(v.preview_card(id))
	if ids.is_empty(): v.centered("没有符合条件的卡牌", Rect2(32, 330, 1059, 150), 24, MUTED)
	v.button("上一页", Rect2(32, 811, 140, 43), "builder_page", -1, false, v.builder_page == 0)
	v.centered("第 %d / %d 页 · %d 张" % [v.builder_page + 1, pages, ids.size()], Rect2(200, 812, 250, 43), 15, MUTED)
	v.button("下一页", Rect2(468, 811, 140, 43), "builder_page", 1, false, v.builder_page >= pages - 1)
	v.text_at("点击加入/移除 · 悬停查看技能", Vector2(805, 839), 13, MUTED)

	v.panel(Rect2(1121, 84, 295, 783), Color("294654"), Color("688594"), 12)
	v.text_at("已选  %d / 12" % v.draft_deck.size(), Vector2(1141, 119), 23, GOLD if v.draft_deck.size() == 12 else INK, true)
	var histogram = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var average = 0.0
	for id in v.draft_deck:
		histogram[v.Rules.CARDS[id].cost] += 1
		average += v.Rules.CARDS[id].cost
	var peak = maxi(1, histogram.values().max())
	for i in range(6):
		var cost = [0, 1, 2, 3, 4, 5][i]
		var x = 1142 + i * 42
		var height = 40.0 * histogram[cost] / peak
		v.draw_rect(Rect2(x, 168 - height, 25, maxf(2, height)), CYAN)
		v.text_at(str(cost), Vector2(x + 8, 185), 11, MUTED)
	v.text_at("平均费用 %.2f" % (average / maxi(1, v.draft_deck.size())), Vector2(1141, 207), 12, MUTED)
	if v.draft_deck.has("061"):
		v.text_at("能源配合：采能环 → 剩余能量转战力" if v.draft_deck.has("048") else "0费外神：保留能量可提高揭示战力", Vector2(1141, 222), 10, CYAN if v.draft_deck.has("048") else GOLD)
	var chosen_ids = v.draft_deck.duplicate()
	chosen_ids.sort_custom( func(a, b): return a < b if v.Rules.CARDS[a].cost == v.Rules.CARDS[b].cost else v.Rules.CARDS[a].cost < v.Rules.CARDS[b].cost)
	for i in range(chosen_ids.size()):
		var id = chosen_ids[i]
		var data = v.Rules.CARDS[id]
		var rect = Rect2(1139, 233 + i * 39, 258, 35)
		v.panel(rect, Color("3b596b"), Color("698593"), 6)
		v.portrait(id, Rect2(rect.position + Vector2(3, 3), Vector2(29, 29)))
		v.text_at(data.name, rect.position + Vector2(41, 23), 14, INK)
		v.text_at("%d费  ×" % data.cost, rect.position + Vector2(199, 23), 12, GOLD)
		v.hit(rect, "builder_card" + id, v.change.bind("builder_card", id), data.text)
		v.card_hint(v.preview_card(id))
	v.button("保存 / 载入", Rect2(1140, 706, 156, 35), "builder_library")
	v.button("清空", Rect2(1307, 706, 89, 35), "builder_clear")
	v.button("确认牌组 · 出发", Rect2(1140, 756, 256, 48), "builder_confirm", null, true, v.draft_deck.size() != 12)
	v.button("返回主菜单", Rect2(1140, 818, 256, 32), "builder_cancel")
