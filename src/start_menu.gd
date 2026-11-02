extends RefCounted
const BRIDGE = preload("res://assets/ui/wrap-v1/command-bridge.png")
const LOGO = preload("res://assets/ui/wrap-v1/wrap-logo.svg")
const ICONS = {
	"compass": preload("res://assets/ui/wrap-v1/icons/compass.svg"), 
	"cards": preload("res://assets/ui/wrap-v1/icons/cards.svg"), 
	"book": preload("res://assets/ui/wrap-v1/icons/book.svg"), 
	"settings": preload("res://assets/ui/wrap-v1/icons/settings.svg"), 
	"help": preload("res://assets/ui/wrap-v1/icons/help.svg"), 
	"resume": preload("res://assets/ui/wrap-v1/icons/resume.svg"), 
	"exit": preload("res://assets/ui/wrap-v1/icons/exit.svg"), 
	"dice": preload("res://assets/ui/wrap-v1/icons/dice.svg"), 
	"star": preload("res://assets/ui/wrap-v1/icons/star.svg"), 
	"check": preload("res://assets/ui/wrap-v1/icons/check.svg"), 
	"close": preload("res://assets/ui/wrap-v1/icons/close.svg"), 
	"arrow": preload("res://assets/ui/wrap-v1/icons/arrow.svg"), 
	"emblem": preload("res://assets/ui/wrap-v1/icons/emblem.svg")
}
const INK = Color("e9e6d5")
const SOFT = Color("b8ccd1")
const CYAN = Color("b6d8d5")

func icon(v, key: String, rect: Rect2):
	v.draw_texture_rect(ICONS[key], rect, false)

func action(v, label: String, detail: String, key: String, rect: Rect2, command: String, primary: bool = false):
	var hover = v.hovered == command + str(null)
	var fill = Color("bddcd8") if primary else Color("2a465a", 0.91)
	if hover: fill = fill.lightened(0.09)
	v.panel(rect, fill, Color("8eafb7") if primary else Color("607f90"), 10)
	v.draw_line(rect.position + Vector2(14, 3), rect.position + Vector2(rect.size.x - 14, 3), Color("d3e5df", 0.45), 2)
	icon(v, key, Rect2(rect.position + Vector2(18, (rect.size.y - 50) / 2), Vector2(50, 50)))
	var color = Color("2d5362") if primary else INK
	v.text_at(label, rect.position + Vector2(86, 40 if primary else 44), 23 if primary else 20, color, true)
	if detail != "": v.text_at(detail, rect.position + Vector2(87, 66), 13, Color("4e737d"))
	icon(v, "arrow", Rect2(rect.end - Vector2(43, rect.size.y / 2 + 12), Vector2(25, 25)))
	v.hit(rect, command + str(null), v.change.bind(command))

func draw(v):
	var w = v.size.x
	var h = v.size.y
	var scale = maxf(w / 1440.0, h / 900.0)
	var bg_w = 1440.0 * scale
	var bg_h = 900.0 * scale
	var bg_x = (w - bg_w) / 2.0
	var bg_y = (h - bg_h) / 2.0
	v.draw_texture_rect(BRIDGE, Rect2(bg_x, bg_y, bg_w, bg_h), false)

	v.draw_rect(Rect2(0, 0, 360, h), Color(0.06, 0.15, 0.21, 0.87))
	v.draw_polygon(PackedVector2Array([Vector2(360, 0), Vector2(1060, 0), Vector2(1060, h), Vector2(360, h)]), PackedColorArray([Color(0.06, 0.15, 0.21, 0.87), Color(0.06, 0.15, 0.21, 0), Color(0.06, 0.15, 0.21, 0), Color(0.06, 0.15, 0.21, 0.87)]))
	v.draw_rect(Rect2(0, h - 77, w, 77), Color(0.07, 0.15, 0.21, 0.72))
	icon(v, "emblem", Rect2(83, 38, 50, 50))
	v.text_at("远征指挥终端", Vector2(147, 70), 17, SOFT, true)
	v.draw_circle(Vector2(w - 240, 64), 4, CYAN)
	v.text_at("离线模式", Vector2(w - 226, 69), 14, SOFT)
	v.panel(Rect2(w - 95, 37, 52, 52), Color("2b465c", 0.8), Color("607e8e"), 9)
	icon(v, "settings", Rect2(w - 89, 43, 40, 40))
	v.hit(Rect2(w - 95, 37, 52, 52), "settings" + str(null), v.change.bind("settings"))
	var returning = v.has_save and v.game.s.get("phase", "") not in ["complete", "gameover"]
	var y = 117.0 if returning else 177.0
	v.draw_rect(Rect2(90, y + 3, 24, 4), Color("a3c9cd"))
	v.text_at("I N T E R S T E L L A R   T A C T I C S", Vector2(129, y + 10), 11, SOFT)
	v.draw_texture_rect(LOGO, Rect2(86, y + 35, 475, 122), false)
	v.text_at("构筑牌组，跃迁交锋。", Vector2(91, y + 197), 23, INK)
	if returning:
		v.panel(Rect2(90, 348, 475, 51), Color("2c4656", 0.92), Color("5c7888"), 8)
		v.text_at("远征进行中", Vector2(108, 370), 14, CYAN, true)
		var phase = {"map": "等待部署", "battle": "第%d回合" % v.game.s.battle.get("round", 1), "result": "战斗结算", "reward": "选择奖励", "replace": "调整牌组"}.get(v.game.s.phase, "等待部署")
		v.text_at("第 %d / 3 站 · %s" % [v.game.s.get("stage", 0) + 1, phase], Vector2(273, 380), 14, SOFT)
	v.text_at("远征控制", Vector2(91, 429 if not returning else 425), 13, SOFT, true)
	v.text_at("等待接入", Vector2(496, 429 if not returning else 425), 11, SOFT)
	v.draw_line(Vector2(90, 442), Vector2(565, 442), Color("6a8795", 0.6), 1)
	if returning:
		action(v, "继续远征", "回到当前进度，继续争夺战区", "resume", Rect2(90, 457, 475, 91), "resume", true)
		action(v, "开始新远征", "", "compass", Rect2(90, 560, 475, 65), "new")
		action(v, "卡组工坊", "", "cards", Rect2(90, 637, 475, 65), "workshop")
		action(v, "卡牌图鉴", "", "book", Rect2(90, 714, 475, 65), "archive")
	else:
		action(v, "开始远征", "编成12张卡牌，准备接入战区", "compass", Rect2(90, 460, 475, 94), "new", true)
		action(v, "卡组工坊", "", "cards", Rect2(90, 568, 475, 69), "workshop")
		action(v, "卡牌图鉴", "", "book", Rect2(90, 651, 475, 69), "archive")
	var help_y = 790.0 if returning else 749.0
	icon(v, "help", Rect2(92, help_y - 5, 24, 24))
	v.text_at("远征指南", Vector2(127, help_y + 13), 14, SOFT)
	v.hit(Rect2(88, help_y - 9, 160, 34), "help" + str(null), v.change.bind("help"))
	if v.save_warning: v.text_at("存档无法读取，可开始新远征。", Vector2(625, 790), 16, v.RED)
	v.panel(Rect2(w - 430, 734, 354, 65), Color("233f50", 0.77), Color("5a7685", 0.55), 9)
	v.text_at("T A C T I C A L   B R I D G E", Vector2(w - 408, 759), 11, SOFT)
	v.text_at("战术投影就绪 · 三大战区待命", Vector2(w - 409, 783), 14, INK)
	v.draw_line(Vector2(90, 823), Vector2(w - 80, 823), Color("68838f", 0.65), 1)
	v.text_at("03 战区    /    06 回合    /    自动保存", Vector2(91, 862), 13, SOFT)
	v.text_at("WRAP  v" + str(ProjectSettings.get_setting("application/config/version")), Vector2(w - 430, 862), 13, SOFT)
	icon(v, "exit", Rect2(w - 172, 842, 25, 25))
	v.text_at("退出", Vector2(w - 137, 861), 14, SOFT)
	v.hit(Rect2(w - 183, 832, 110, 48), "exit" + str(null), v.change.bind("exit"))

func settings(v):
	var w = v.size.x
	var left = (w - 720) / 2.0
	v.panel(Rect2(left, 200, 720, 490), Color("294454"), Color("79949c"), 22)
	icon(v, "settings", Rect2(left + 49, 239, 47, 47))
	v.text_at("终端设置", Vector2(left + 116, 274), 30, INK, true)
	v.text_at("战斗动画", Vector2(left + 55, 352), 20, INK)
	v.button("简化" if v.animation_speed == 0 else "%d 倍速" % v.animation_speed, Rect2(left + 406, 315, 240, 52), "speed", null, true)
	v.text_at("显示模式", Vector2(left + 55, 431), 20, INK)
	v.button("窗口" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED else "全屏", Rect2(left + 406, 394, 240, 52), "fullscreen")
	v.text_at("技能时机", Vector2(left + 55, 506), 18, v.SkillText.RED, true)
	v.text_at("关键词条", Vector2(left + 330, 506), 18, v.SkillText.BLUE, true)
	v.text_at("设置自动保存。快捷键：Esc 返回 · 空格结束回合。", Vector2(left + 55, 552), 15, SOFT)
	v.button("完成", Rect2(left + 406, 590, 240, 52), "close", null, true)

func archive(v):
	var w = v.size.x
	v.text_at("卡牌图鉴", Vector2(34, 106), 30, INK, true)
	v.text_at("121 张卡牌 · 悬停查看完整技能", Vector2(35, 138), 15, SOFT)
	var costs = [-1, 0, 1, 2, 3, 4, 5]
	for i in range(costs.size()): v.button("全部" if costs[i] < 0 else "%d费" % costs[i], Rect2(34 + i * 91, 160, 82, 34), "builder_cost", costs[i], costs[i] == v.builder_cost)
	v.button("返回主菜单", Rect2(w - 260, 100, 220, 43), "menu")
	var ids = v.deck_builder.filtered(v)
	var pages = maxi(1, ceili(ids.size() / 18.0))
	v.builder_page = clampi(v.builder_page, 0, pages - 1)
	var start_x = maxf(34.0, (w - 6 * 232 + 12) / 2.0)
	for i in range(18):
		var index = v.builder_page * 18 + i
		if index >= ids.size(): break
		var id = ids[index]
		var data = v.Rules.CARDS[id]
		var rect = Rect2(start_x + (i % 6) * 232, 215 + (i / 6 as int) * 191, 220, 178)
		v.panel(rect, Color("2d4858"), Color("718b95"), 13)
		v.portrait(id, Rect2(rect.position + Vector2(68, 8), Vector2(83, 83)))
		v.badge(str(data.cost), rect.position + Vector2(25, 25), Color("759fae"), 15)
		v.badge(str(data.power), rect.position + Vector2(195, 25), v.GOLD, 15)
		v.centered(data.name, Rect2(rect.position + Vector2(5, 96), Vector2(210, 23)), 16, INK, true)
		v.paragraph(data.text, rect.position + Vector2(12, 135), 197, 11, SOFT, 15)
		v.hit(rect, "archive_" + id, func(): pass)
		v.card_hint(v.preview_card(id))
	v.button("上一页", Rect2(start_x, 813, 150, 43), "builder_page", -1, false, v.builder_page == 0)
	v.text_at("第 %d / %d 页 · %d 张" % [v.builder_page + 1, pages, ids.size()], Vector2(start_x + 196, 842), 16, SOFT)
	v.button("下一页", Rect2(start_x + 448, 813, 150, 43), "builder_page", 1, false, v.builder_page >= pages - 1)
		var data = v.Rules.CARDS[id]
		var rect = Rect2(34 + (i % 6) * 232, 215 + (i / 6 as int) * 191, 220, 178)
		v.panel(rect, Color("2d4858"), Color("718b95"), 13)
		v.portrait(id, Rect2(rect.position + Vector2(68, 8), Vector2(83, 83)))
		v.badge(str(data.cost), rect.position + Vector2(25, 25), Color("759fae"), 15)
		v.badge(str(data.power), rect.position + Vector2(195, 25), v.GOLD, 15)
		v.centered(data.name, Rect2(rect.position + Vector2(5, 96), Vector2(210, 23)), 16, INK, true)
		v.paragraph(data.text, rect.position + Vector2(12, 135), 197, 11, SOFT, 15)
		v.hit(rect, "archive_" + id, func(): pass)
		v.card_hint(v.preview_card(id))
	v.button("上一页", Rect2(34, 813, 150, 43), "builder_page", -1, false, v.builder_page == 0)
	v.text_at("第 %d / %d 页 · %d 张" % [v.builder_page + 1, pages, ids.size()], Vector2(230, 842), 16, SOFT)
	v.button("下一页", Rect2(482, 813, 150, 43), "builder_page", 1, false, v.builder_page >= pages - 1)
