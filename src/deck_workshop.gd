extends RefCounted

func setup(v):
	v.deck_name = LineEdit.new()
	v.deck_name.position = Vector2(301, 185)
	v.deck_name.size = Vector2(480, 44)
	v.deck_name.max_length = 18
	v.deck_name.placeholder_text = "例如：我的虫群进化队（最多18字）"
	v.deck_name.visible = false
	style_input(v, v.deck_name)
	v.add_child(v.deck_name)
	v.random_cost = SpinBox.new()
	v.random_cost.position = Vector2(302, 188)
	v.random_cost.size = Vector2(220, 48)
	v.random_cost.min_value = 0.92
	v.random_cost.max_value = 5.0
	v.random_cost.step = 0.01
	v.random_cost.value = 3.0
	v.random_cost.suffix = " 费"
	v.random_cost.visible = false
	style_input(v, v.random_cost.get_line_edit())
	v.random_cost.value_changed.connect( func(_value): v.queue_redraw())
	v.add_child(v.random_cost)

func style_input(v, edit: LineEdit):
	edit.add_theme_font_override("font", v.font)
	edit.add_theme_font_size_override("font_size", 19)
	edit.add_theme_color_override("font_color", v.DARK)
	edit.add_theme_color_override("font_placeholder_color", Color("71877a"))
	edit.add_theme_color_override("caret_color", v.DARK)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("eee9d6")
	style.border_color = Color("8ca48f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 12
	edit.add_theme_stylebox_override("normal", style)
	var focus = style.duplicate()
	focus.border_color = v.GOLD
	focus.set_border_width_all(2)
	edit.add_theme_stylebox_override("focus", focus)

func sync(v):
	v.deck_name.visible = v.modal == "library"
	v.random_cost.visible = v.modal == "random"

func draw_presets(v):
	v.text_at("选择预设卡组", Vector2(92, 125), 34, v.INK, true)
	v.text_at("10套起点 · 六族与混编构筑 · 载入后仍可自由调整", Vector2(94, 163), 17, v.MUTED)
	for i in range(v.Rules.Data.PRESETS.size()):
		var preset = v.Rules.Data.PRESETS[i]
		var rect = Rect2(92 + (i % 2) * 643, 195 + (i / 2 as int) * 119, 613, 105)
		v.panel(rect, v.PANEL, v.LINE, 18)
		v.portrait(preset.portrait, Rect2(rect.position + Vector2(13, 14), Vector2(62, 62)))
		v.text_at(preset.name, rect.position + Vector2(90, 31), 21, v.INK, true)
		v.text_at("均费 %.2f" % v.deck_library.average(preset.ids), rect.position + Vector2(282, 31), 14, v.MINT)
		v.paragraph(preset.description, rect.position + Vector2(90, 58), 360, 13, v.MUTED, 19)
		v.button("载入", Rect2(rect.position + Vector2(487, 24), Vector2(106, 48)), "preset_choose", i, true)
	v.button("返回组牌", Rect2(1095, 813, 240, 48), "workshop_close")

func draw_library(v):
	v.text_at("我的卡组 · 五个存档位", Vector2(92, 125), 34, v.INK, true)
	v.text_at("独立保存，开启新远征后仍可使用。" + ("当前仅保存远征牌组，载入请到组牌页。" if v.screen == "game" else "载入后可继续修改，也可保存预设或随机结果。"), Vector2(94, 163), 17, v.MUTED)
	v.text_at("本次保存名称", Vector2(95, 215), 20, v.INK, true)
	v.text_at("留空沿用名称；保存需要12张完整卡组", Vector2(808, 214), 15, v.MUTED)
	var valid = v.deck_library.valid_deck(v.library_source)
	for i in range(5):
		var slot = v.deck_library.slots[i]
		var rect = Rect2(92, 252 + i * 106, 1256, 96)
		v.panel(rect, v.PANEL, v.LINE, 18)
		v.text_at("%02d" % (i + 1), rect.position + Vector2(17, 35), 23, v.GOLD, true)
		v.text_at(slot.get("name", "空存档位"), rect.position + Vector2(66, 31), 20, v.INK, true)
		if not slot.is_empty():
			v.text_at("12张 · 平均 %.2f费" % v.deck_library.average(slot.ids), rect.position + Vector2(490, 31), 14, v.MINT)
			for k in range(slot.ids.size()):
				var card_rect = Rect2(rect.position + Vector2(66 + k * 40, 44), Vector2(34, 34))
				v.portrait(slot.ids[k], card_rect)
				v.hit(card_rect, "saved_card_%d_%d" % [i, k], func(): pass)
				v.card_hint(v.preview_card(slot.ids[k]))
		else:
			v.text_at("将当前牌组保存到这里", rect.position + Vector2(66, 67), 15, v.MUTED)
		v.button("载入", Rect2(rect.position + Vector2(852, 24), Vector2(135, 48)), "library_load", i, false, slot.is_empty() or v.screen != "builder")
		v.button("保存到此" if slot.is_empty() else "覆盖此槽", Rect2(rect.position + Vector2(1004, 24), Vector2(228, 48)), "library_save", i, true, not valid)
	v.button("返回", Rect2(1108, 813, 240, 48), "workshop_close")

func draw_random(v):
	v.text_at("按平均费用随机组牌", Vector2(92, 125), 34, v.INK, true)
	v.text_at("从121张牌中选出12张不重复卡牌。总费用必须为整数，取最接近的实际平均值。", Vector2(94, 163), 17, v.MUTED)
	v.text_at("目标平均费用", Vector2(95, 220), 20, v.INK, true)
	v.text_at("范围 0.92—5.00", Vector2(550, 217), 15, v.MUTED)
	v.button("生成一套" if v.random_result.is_empty() else "再随机一套", Rect2(805, 185, 240, 50), "random_generate", null, true)
	v.button("采用这套牌组", Rect2(1063, 185, 285, 50), "random_use", null, true, v.random_result.is_empty() or not is_equal_approx(v.random_cost.value, v.random_result.get("requested", 0.0)))
	if v.random_result.is_empty():
		v.centered("输入目标平均费用，开始一次新的构筑尝试。", Rect2(180, 360, 1080, 100), 26, v.MUTED)
	else:
		v.text_at("本次目标 %.2f费   →   实际 %.2f费   /   总费用 %d" % [v.random_result.requested, v.random_result.average, v.random_result.total], Vector2(95, 286), 23, v.GOLD, true)
		for i in range(v.random_result.ids.size()):
			var id = v.random_result.ids[i]
			var data = v.Rules.CARDS[id]
			var rect = Rect2(92 + (i % 4) * 320, 318 + (i / 4 as int) * 136, 297, 120)
			v.panel(rect, v.PANEL, v.LINE, 16)
			v.portrait(id, Rect2(rect.position + Vector2(12, 12), Vector2(72, 72)))
			v.text_at(data.name, rect.position + Vector2(96, 35), 18, v.INK, true)
			v.text_at("%d费 / %d战力" % [data.cost, data.power], rect.position + Vector2(96, 61), 16, v.GOLD)
			v.text_at(data.kind, rect.position + Vector2(96, 85), 13, v.MUTED)
			v.text_at("悬停查看完整技能", rect.position + Vector2(13, 107), 11, v.MUTED)
			v.hit(rect, "random_card" + str(i), func(): pass)
			v.card_hint(v.preview_card(id))
		v.text_at("生成只约束费用，配合可在载入后调整；0费外神按剩余能量获得战力。", Vector2(94, 755), 15, v.MUTED)
	v.button("返回组牌", Rect2(1108, 813, 240, 48), "workshop_close")
