extends Control

const SkillText = preload("res://src/skill_text.gd")
var start_ui = preload("res://src/start_menu.gd").new()
var settings_path = "user://settings.json"
const Rules = preload("res://src/game.gd")
const HexBattle = preload("res://src/hex_battle.gd")
const DeckBuilder = preload("res://src/deck_builder.gd")
const BG = Color("203747")
const PANEL = Color("2d4858")
const LINE = Color("718b95")
const INK = Color("f3eddb")
const MUTED = Color("beced0")
const MINT = Color("b0d6d9")
const GOLD = Color("e6bd79")
const RED = Color("e5aa96")
const DARK = Color("2c4b5b")
const SAVE = "user://savegame-scifi.json"
var save_path = "res://savegame-scifi.json" if OS.has_feature("editor") else SAVE
var menu_art: Texture2D

var game = Rules.new()
const UI_FONT = preload("res://assets/fonts/NotoSansSC.ttf")
var font = FontVariation.new()
var bold = FontVariation.new()
var hits: Array = []
var screen = "menu"
var modal = ""
var skill_page = 0
var selected = -1
var hovered = ""
var pointer_position = Vector2.ZERO
var tip = ""
var toast = ""
var toast_time = 0.0
var busy = false
var has_save = false
var save_warning = false
var test_mode = false
var battle_ui = HexBattle.new()
var fx: Array = []
var reveal_fx: Dictionary = {}
var animation_speed = 1.0
var animation_time_scale = 1.0
var ambient_time = 0.0
var redraw_clock = 0.0
var result_age = 0.0
var resolution_label = ""
var locked_energy = 0
var deck_builder = DeckBuilder.new()
var draft_deck: Array = []
var builder_cost = -1
var builder_page = 0
var builder_query = ""
var builder_search: LineEdit
var deck_library = preload("res://src/deck_library.gd").new()
var workshop = preload("res://src/deck_workshop.gd").new()
var library_path = "res://decks.json" if OS.has_feature("editor") else "user://decks.json"
var deck_name: LineEdit
var random_cost: SpinBox
var library_source: Array = []
var library_return = ""
var draft_name = ""
var random_result: Dictionary = {}
var card_textures: Dictionary = {}
var moving_uid = -1
var gate_uid = -1
var intel_stage = 0
var swap_uid = -1
var action_uid = -1
var tooltip_ui = preload("res://src/card_tooltip.gd").new()
var backdrop = preload("res://assets/art/soft-ui-v1/star-map-backdrop.png")
var terrain_art = [
	preload("res://assets/art/soft-ui-v1/terrain-desert.png"), 
	preload("res://assets/art/soft-ui-v1/terrain-ice.png"), 
	preload("res://assets/art/soft-ui-v1/terrain-city.png")
]

func _ready():
	var weight_axis = TextServerManager.get_primary_interface().name_to_tag("wght")
	font.base_font = UI_FONT
	font.variation_opentype = {weight_axis: 450.0}
	bold.base_font = UI_FONT
	bold.variation_opentype = {weight_axis: 750.0}
	menu_art = start_ui.BRIDGE
	builder_search = LineEdit.new()
	builder_search.position = Vector2(738, 101)
	builder_search.size = Vector2(354, 40)
	builder_search.placeholder_text = "搜索卡名 / 技能 / 族群"
	builder_search.add_theme_font_override("font", font)
	builder_search.add_theme_font_size_override("font_size", 16)
	builder_search.visible = false
	builder_search.text_changed.connect( func(value): builder_query = value;builder_page = 0;queue_redraw())
	add_child(builder_search)
	workshop.setup(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	test_mode = "--playtest" in OS.get_cmdline_user_args()
	DisplayServer.window_set_title("WRAP · 试玩测试" if test_mode else "WRAP · 星际远征")
	if not test_mode:
		load_settings()
		load_run()
		var library_error = deck_library.load_file(library_path)
		if library_error != "": notify(library_error)
	else:
		library_path = "user://playtest-decks.json"
	queue_redraw()


	if test_mode and "--release-ui" in OS.get_cmdline_user_args():
		call_deferred("run_release_check", "res://tools/test_ui.gd")
	elif test_mode and "--release-resume" in OS.get_cmdline_user_args():
		call_deferred("run_release_check", "res://tools/test_release_resume.gd")

func run_release_check(script_path: String):
	get_tree().root.add_child(load(script_path).new())

func _process(delta):
	ambient_time += delta
	redraw_clock += delta
	result_age += delta
	for item in fx: item.age += delta
	fx = fx.filter( func(item): return item.age < item.duration)
	if not reveal_fx.is_empty(): reveal_fx.age += delta
	if redraw_clock > 1.0 / 30.0 and ( not fx.is_empty() or busy or (screen == "game" and game.s.get("phase", "") in ["battle", "result"])):
		redraw_clock = 0.0
		queue_redraw()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast = ""
			queue_redraw()

func save_run():
	if test_mode: return

	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(game.snapshot()))
		file.flush()
		file.close()
		var err = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path))
		has_save = err == OK
		if err != OK: notify("进度保存失败：请检查存档目录权限与磁盘空间。")
	else:
		notify("进度保存失败：请检查存档目录权限与磁盘空间。")

func load_run():
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	has_save = game.restore(data)
	if not has_save: save_warning = true

func notify(message: String):
	toast = message
	toast_time = 3.5
	queue_redraw()

func new_run():
	fx.clear()
	reveal_fx.clear()
	draft_deck = game.s.get("deck", Rules.STARTER).duplicate()
	draft_name = ""
	builder_cost = -1
	builder_page = 0
	builder_query = ""
	builder_search.text = ""
	screen = "builder"
	modal = ""
	selected = -1
	queue_redraw()

func adopt_deck(ids: Array, title: String):
	draft_deck = ids.duplicate()
	draft_name = title
	builder_query = ""
	builder_search.text = ""
	builder_cost = -1
	builder_page = 0
	modal = ""

func confirm_deck():
	var error = game.validate_deck(draft_deck)
	if error != "":
		notify(error)
		return
	game.new_run(0, draft_deck)
	screen = "game"
	modal = ""
	selected = -1
	moving_uid = -1
	gate_uid = -1
	swap_uid = -1
	save_run()
	queue_redraw()

func resume_run():
	screen = "game"
	modal = "survey" if not game.s.get("battle", {}).get("choice", {}).is_empty() else ""
	selected = -1
	queue_redraw()

func change(action: String, value = null):
	if busy: return
	if modal == "survey" and action != "survey_choose": return
	match action:
		"new", "workshop": new_run()
		"archive":
			screen = "archive"
			builder_cost = -1
			builder_query = ""
			builder_search.text = ""
			builder_page = 0
		"settings": modal = "settings"
		"fullscreen":
			var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED else DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode(mode)
			save_settings()
		"exit": get_tree().quit()
		"launch_deck": confirm_deck();return
		"resume": resume_run()
		"menu":
			screen = "menu"
			modal = ""
		"help": modal = "help"
		"deck": modal = "deck"
		"enemy":
			intel_stage = int(game.s.stage) if value == null else int(value)
			modal = "enemy"
		"log": modal = "log"
		"close": modal = ""
		"start": game.begin_battle()
		"select":
			swap_uid = -1
			moving_uid = -1
			gate_uid = -1
			selected = -1 if selected == value else int(value)
		"lane":
			if selected < 0: notify("先点击下方手牌，再选择部署区域。")
			else:
				var flying_card = game.s.battle.hands[0][selected].duplicate(true)
				var origin = battle_ui.hand_rect(self, selected).get_center()
				var target_index = game.s.battle.boards[0][int(value)].size() + game.queued_at(int(value))
				var error = game.queue_card(selected, int(value))
				if error != "": notify(error)
				else:
					add_fx({"type": "flight", "card": flying_card, "from": origin, "to": battle_ui.slot_center(0, int(value), target_index), "color": GOLD, "duration": 0.34})
					selected = -1
					tip = ""
		"undo":
			game.undo()
			selected = -1
		"end":
			end_turn()
			return
		"next": game.continue_result()
		"reward": game.select_reward(str(value))
		"replace": game.replace_card(int(value))
		"skip": game.skip_reward()
		"back_reward": game.s.phase = "reward"
		"builder_card":
			if draft_deck.has(value): draft_deck.erase(value)
			elif draft_deck.size() < 12: draft_deck.append(value)
			else: notify("已选满12张，请先移除一张。")
		"builder_cost": builder_cost = int(value);builder_page = 0
		"builder_page": builder_page += int(value)
		"builder_preset": modal = "presets";toast = ""
		"builder_random":
			toast = ""
			random_result = {}
			modal = "random"
		"builder_library":
			toast = ""
			library_source = (game.s.deck if screen == "game" else draft_deck).duplicate()
			library_return = "deck" if screen == "game" else ""
			deck_name.text = draft_name if screen == "builder" else ""
			modal = "library"
		"workshop_close":
			modal = library_return if modal == "library" else ""
		"library_save":
			var error = deck_library.save_slot(library_path, int(value), deck_name.text, library_source)
			if error != "": notify(error)
			else:
				deck_name.text = deck_library.slots[int(value)].name
				if screen == "builder": draft_name = deck_name.text
				notify("已保存到卡组位 %d：%s" % [int(value) + 1, deck_name.text])
		"library_load":
			if screen != "builder": return
			var ids = deck_library.load_slot(int(value))
			if ids.is_empty(): return
			adopt_deck(ids, deck_library.slots[int(value)].name)
			notify("已载入：" + draft_name)
		"random_generate":
			random_cost.apply()
			random_result = deck_library.random_deck(random_cost.value)
		"random_use":
			if random_result.is_empty(): return
			random_cost.apply()
			if not is_equal_approx(random_cost.value, random_result.requested):
				notify("目标费用已变更，请重新生成。")
				return
			adopt_deck(random_result.ids, "随机 %.2f费" % random_result.average)
			notify("随机卡组已载入，平均 %.2f费" % random_result.average)
		"preset_choose":
			adopt_deck(Rules.Data.PRESETS[int(value)].ids, Rules.Data.PRESETS[int(value)].name)
		"survey_choose":
			var start_state = game.s.duplicate(true)
			if game.choose_card(int(value)):
				modal = ""
				await animate_resolution(game, start_state)
			return
		"reboot":
			var before = game.presentation_board()
			var error = game.reboot(action_uid)
			if error != "": notify(error)
			else:
				game.last_events.clear()
				game.record_presentation("action", before, {}, game.s.battle.queue)
				play_changes(game.last_events[0], Vector2(-1, -1))
			modal = ""
		"device_move":
			moving_uid = action_uid
			gate_uid = -1
			modal = ""
		"skills":
			action_uid = int(value)
			skill_page = 0
			modal = "skills"
		"skill_page": skill_page = int(value)
		"use_skill":
			var before = game.presentation_board()
			var error = game.activate(action_uid, 0, str(value) if value != null else "")
			if error != "": notify(error)
			else:
				game.last_events.clear()
				game.record_presentation("action", before, {}, game.s.battle.queue)
				play_changes(game.last_events[0], Vector2(-1, -1))
			modal = ""
		"builder_clear": draft_deck.clear()
		"builder_cancel": screen = "menu"
		"builder_confirm":
			if has_save and game.s.get("phase", "") not in ["complete", "gameover"]: modal = "restart_deck"
			else: confirm_deck();return
		"activate":
			var found = game.locate(int(value))
			if found.is_empty(): return
			if found.side != 0 and (gate_uid < 0 or game.locate(gate_uid).card.id != "055"): return
			selected = -1
			if gate_uid >= 0:
				moving_uid = int(value)
			elif swap_uid >= 0 and found.card.uid != swap_uid:
				var before = game.presentation_board()
				var error = game.swap_units(swap_uid, found.card.uid)
				if error != "": notify(error)
				else:
					swap_uid = -1
					game.last_events.clear()
					game.record_presentation("action", before, {}, game.s.battle.queue)
					play_changes(game.last_events[0], Vector2(-1, -1))
			elif not found.card.get("inherited", {}).is_empty():
				action_uid = found.card.uid
				skill_page = 0
				modal = "skills"
			elif game.can_reboot(found.card.uid) or (found.card.id in Rules.Balance.ACTIVE and found.card.id not in Rules.Balance.SELF_MOVE and found.card.id not in ["049", "055"]):
				action_uid = found.card.uid
				modal = "device"
			elif found.card.id == "077" and game.can_activate(found.card.uid):
				swap_uid = found.card.uid
				moving_uid = -1
				gate_uid = -1
				notify("点击另一战区的己方无技能单位，交换位置。")
			elif gate_uid >= 0 and found.card.uid != gate_uid:
				moving_uid = int(value)
			elif found.card.id in ["049", "055"] and game.can_activate(found.card.uid):
				gate_uid = int(value)
				moving_uid = -1
				notify("点击要移动的单位，再点击目标战区。")
			elif found.card.id in ["016", "037", "064", "080"] and game.can_activate(found.card.uid):
				moving_uid = int(value)
				gate_uid = -1
		"move":
			var found = game.locate(moving_uid)
			if found.is_empty(): return
			var before = game.presentation_board()
			var error = game.manual_move(moving_uid, int(value), gate_uid)
			if error != "": notify(error)
			else:
				game.last_events.clear()
				game.record_presentation("action", before, {}, game.s.battle.queue)
				play_changes(game.last_events[0], Vector2(-1, -1))
				moving_uid = -1
				gate_uid = -1
		"speed":
			animation_speed = 2.0 if animation_speed == 1.0 else (0.0 if animation_speed == 2.0 else 1.0)
			notify("动画：" + ("简化" if animation_speed == 0 else "%d 倍速" % animation_speed))
			save_settings()
	if screen == "game": save_run()
	queue_redraw()

func end_turn():
	if busy or game.s.phase != "battle" or modal != "": return
	locked_energy = game.available_energy()
	busy = true
	selected = -1
	moving_uid = -1
	gate_uid = -1
	swap_uid = -1
	tip = ""
	fx.clear()
	var start_state = game.s.duplicate(true)
	var completed_game = game
	completed_game.resolve_turn(true, true)
	await animate_resolution(completed_game, start_state)

func animate_resolution(completed_game, start_state: Dictionary):
	busy = true
	var events = completed_game.last_events
	game = Rules.new()
	game.s = start_state
	resolution_label = "双方部署锁定"
	queue_redraw()
	await animation_wait(0.16)
	for event in events:
		if event.kind == "reveal":
			var source = event.source
			resolution_label = ("你方" if source.side == 0 else "敌方") + "揭示 · " + Rules.CARDS[source.card.id].name
			reveal_fx = {"source": source, "age": 0.0, "flipped": false, "duration": scaled_duration(0.6)}
			queue_redraw()
			await animation_wait(0.22)
			game.s = event.state.duplicate(true)
			reveal_fx.flipped = true
			reveal_fx.source = event.result_source
			var center = battle_ui.slot_center(event.result_source.side, event.result_source.lane, event.result_source.index)
			add_fx({"type": "pulse", "to": center, "color": MINT if source.side == 0 else RED, "duration": 0.48})
			play_changes(event, center)
			if source.effect in ["005", "014", "035", "048", "009", "030"]:
				add_fx({"type": "float", "to": center + Vector2(0, -45), "text": "能源储备" if source.effect == "048" else "技能结算", "color": GOLD, "duration": 0.65})
			await animation_wait(0.46)
			reveal_fx.clear()
		else:
			game.s = event.state.duplicate(true)
			resolution_label = "新回合 · 战区更新" if event.kind == "round_start" else "回合结束 · 战力结算"
			if event.kind == "terrain": resolution_label = "回合结束 · 场地结算"
			play_changes(event, Vector2(-1, -1))
			if not event.changes.is_empty() or not event.added.is_empty() or not event.removed.is_empty() or not event.moved.is_empty() or not event.get("recalled", []).is_empty() or not event.get("terrains", []).is_empty(): await animation_wait(0.55)
	game = completed_game
	resolution_label = ""
	result_age = 0.0
	if game.s.phase == "battle" and game.s.battle.choice.is_empty():
		add_fx({"type": "banner", "text": "第 %d 回合" % game.s.battle.round, "to": Vector2(720, 410), "color": GOLD, "duration": 0.85})
		if game.s.battle.round <= 3:
			add_fx({"type": "region", "lane": game.s.battle.round - 1, "color": GOLD, "duration": 0.8})
	modal = "survey" if not game.s.get("battle", {}).get("choice", {}).is_empty() else ""
	save_run()
	busy = false
	queue_redraw()

func scaled_duration(duration: float) -> float:
	return duration * animation_time_scale / maxf(animation_speed, 1.0)

func displayed_energy() -> int:

	return locked_energy if busy else game.available_energy()

func animation_wait(duration: float):
	if animation_speed == 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(maxf(0.001, scaled_duration(duration))).timeout

func add_fx(data: Dictionary):
	if animation_speed == 0.0: return
	data["age"] = 0.0
	data["duration"] = scaled_duration(data.get("duration", 0.6))
	fx.append(data)

func play_changes(event: Dictionary, origin: Vector2):
	for cue in event.get("terrains", []):
		var center = battle_ui.lane_center(cue.lane)
		add_fx({"type": "region", "lane": cue.lane, "color": GOLD, "duration": 0.7})
		add_fx({"type": "float", "to": center + Vector2(0, 25 if cue.side != 1 else -25), "text": cue.text, "color": GOLD, "duration": 0.8})
	for item in event.get("recalled", []):
		var center = battle_ui.slot_center(item.side, item.lane, item.index)
		add_fx({"type": "flight", "card": item.card, "side": item.side, "from": center, "to": Vector2(500, 780) if item.side == 0 else Vector2(220, 104), "color": MINT, "duration": 0.5})
		add_fx({"type": "float", "to": center, "text": "回手", "color": MINT, "duration": 0.7})
	for item in event.get("transformed", []):
		var target = battle_ui.slot_center(item.to.side, item.to.lane, item.to.index)
		add_fx({"type": "evolve", "card": item.from.card, "to": target, "color": Color("c5b2dc"), "duration": 0.9})
		add_fx({"type": "float", "to": target, "text": "进化", "color": GOLD, "duration": 1.0})
	for item in event.get("removed", []):
		var target = battle_ui.slot_center(item.side, item.lane, item.index)
		add_fx({"type": "destroy", "card": item.card, "to": target, "color": RED, "duration": 0.5})
		add_fx({"type": "pulse", "to": target, "color": RED, "duration": 0.55})
		add_fx({"type": "float", "to": target, "text": "摧毁", "color": RED, "duration": 0.7})
	for item in event.get("added", []):
		add_fx({"type": "pulse", "to": battle_ui.slot_center(item.side, item.lane, item.index), "color": GOLD, "duration": 0.6})
		add_fx({"type": "float", "to": battle_ui.slot_center(item.side, item.lane, item.index), "text": "复活" if Rules.CARDS[item.card.id].collectible else "召唤", "color": GOLD, "duration": 0.65})
	for item in event.get("shields", []):
		add_fx({"type": "float", "to": battle_ui.slot_center(item.side, item.lane, item.index), "text": "护盾" if item.shield else "抵挡", "color": MINT, "duration": 0.65})
	for move in event.get("moved", []):
		add_fx({"type": "flight", "card": move.to.card, "from": battle_ui.slot_center(move.from.side, move.from.lane, move.from.index), "to": battle_ui.slot_center(move.to.side, move.to.lane, move.to.index), "color": MINT, "duration": 0.4})
	for change_data in event.changes:
		var target = battle_ui.slot_center(change_data.side, change_data.lane, change_data.index)
		var tint = RED if change_data.delta < 0 else MINT
		if origin.x >= 0 and origin.distance_to(target) > 10:
			add_fx({"type": "beam", "from": origin, "to": target, "color": tint, "duration": 0.32})
		add_fx({"type": "float", "to": target, "text": ("+" if change_data.delta > 0 else "") + str(change_data.delta), "color": tint, "duration": 0.75})
		add_fx({"type": "pulse", "to": target, "color": tint, "duration": 0.5})

func _gui_input(event):
	if event is InputEventMouseMotion:
		pointer_position = event.position
		queue_redraw()
		var next_hover = ""
		var next_tip = ""
		for i in range(hits.size() - 1, -1, -1):
			if contains_hit(hits[i], event.position):
				next_hover = hits[i].id
				next_tip = hits[i].tip
				break
		if hovered != next_hover or tip != next_tip:
			hovered = next_hover
			tip = next_tip
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if next_hover != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			selected = -1
			moving_uid = -1
			gate_uid = -1
			swap_uid = -1
			hovered = ""
			tip = ""
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT and not busy:
			var hit_any = false
			for i in range(hits.size() - 1, -1, -1):
				if contains_hit(hits[i], event.position):
					hits[i].fn.call()
					hit_any = true
					break
			if not hit_any:
				selected = -1
				moving_uid = -1
				gate_uid = -1
				swap_uid = -1
				hovered = ""
				tip = ""
				queue_redraw()

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	if busy or modal == "survey": return
	if event.keycode == KEY_ESCAPE:
		if modal in ["presets", "library", "random"]:
			change("workshop_close")
			return
		if moving_uid >= 0 or gate_uid >= 0 or swap_uid >= 0:
			moving_uid = -1
			gate_uid = -1
			queue_redraw()
			return
		if modal != "": modal = ""
		elif selected >= 0: selected = -1
		else: modal = "help"
		queue_redraw()
	elif screen == "game" and modal == "" and game.s.phase == "battle" and not busy:
		if event.keycode == KEY_SPACE: end_turn()
		elif event.keycode == KEY_Z: change("undo")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			if index < game.s.battle.hands[0].size(): change("select", index)

func text_at(value: String, pos: Vector2, size_px: int = 18, color: Color = INK, heavy: bool = false):
	draw_string(bold if heavy else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(value: String, rect: Rect2, size_px: int = 18, color: Color = INK, heavy: bool = false):
	var f = bold if heavy else font
	var width = f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	text_at(value, Vector2(rect.position.x + (rect.size.x - width) / 2, rect.position.y + (rect.size.y - size_px) / 2 + size_px * 0.83), size_px, color, heavy)

func paragraph(value: String, pos: Vector2, width: float, size_px: int = 17, color: Color = MUTED, line_height: float = 27.0):
	SkillText.draw(self, value, pos, width, size_px, color, line_height)

func panel(rect: Rect2, color: Color = PANEL, border: Color = LINE, radius: int = 14):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(clampi(radius + 4, 10, 22))
	style.shadow_color = Color(0.04, 0.12, 0.12, 0.25)
	style.shadow_offset = Vector2(0, 3)
	style.shadow_size = 3
	style.anti_aliasing = true
	style.draw(get_canvas_item(), rect)
	var inset = clampf(radius, 8, 16)
	draw_line(rect.position + Vector2(inset, 2), rect.position + Vector2(rect.size.x - inset, 2), color.lightened(0.08), 1, true)

func get_card_texture(id: String) -> Texture2D:
	if not card_textures.has(id):
		card_textures[id] = load(Rules.CARDS[id].art)
	return card_textures[id]

func portrait(id: String, rect: Rect2, faded: bool = false):
	var texture = get_card_texture(id)
	if texture:
		draw_texture_rect(texture, rect, false, Color(1, 1, 1, 0.45) if faded else Color.WHITE)

func badge(value: String, center: Vector2, tint: Color, radius: float = 16):
	draw_circle(center + Vector2(0, 2), radius + 1, LINE)
	draw_circle(center, radius, tint)
	draw_arc(center, radius, 0, TAU, 32, LINE, 2, true)
	draw_arc(center, radius - 2, PI + 0.3, TAU - 0.3, 24, tint.lightened(0.45), 2, true)
	centered(value, Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), int(radius * 1.2), DARK if tint.get_luminance() > 0.45 else INK, true)

func star(center: Vector2, radius: float, color: Color):
	var points = PackedVector2Array()
	for i in range(10):
		var a = - PI / 2 + i * PI / 5
		points.append(center + Vector2(cos(a), sin(a)) * radius * (1.0 if i % 2 == 0 else 0.48))
	draw_colored_polygon(points, color)

func die_emblem(center: Vector2, radius: float):
	var hull = PackedVector2Array()
	for i in range(6):
		var a = - PI / 2 + i * PI / 3
		hull.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(hull, Color("215468"))
	var inner = PackedVector2Array([hull[0], hull[2], hull[4], hull[0]])
	draw_polyline(inner, GOLD, 1.5, true)
	for i in [1, 3, 5]: draw_line(hull[i], center, GOLD, 1.0, true)
	hull.append(hull[0])
	draw_polyline(hull, GOLD, 2.0, true)

func hit(rect: Rect2, id: String, fn: Callable, tooltip: String = ""):
	hits.append({"rect": rect, "id": id, "fn": fn, "tip": tooltip})

func hit_polygon(points: PackedVector2Array, id: String, fn: Callable, tooltip: String = ""):
	var rect = Rect2(points[0], Vector2.ZERO)
	for p in points: rect = rect.expand(p)
	hits.append({"rect": rect, "polygon": points, "id": id, "fn": fn, "tip": tooltip})

func preview_card(id: String) -> Dictionary:
	return {"id": id, "uid": -1, "bonus": 0, "damage": 0, "cost_delta": 0, "shield": false, "uses": {}}

func card_hint(card: Dictionary):
	if not hits.is_empty(): hits.back()["card"] = card

func contains_hit(item: Dictionary, point: Vector2) -> bool:
	if item.has("polygon"):
		return Geometry2D.is_point_in_polygon(point, item.polygon)
	return item.rect.grow(8.0).has_point(point)

func button(label: String, rect: Rect2, action: String, value = null, primary: bool = false, disabled: bool = false):
	var id = action + str(value)
	var fill = Color("e6bf80") if primary else Color("456555")
	if hovered == id and not disabled: fill = fill.lightened(0.12)
	if disabled: fill = Color("344d46")
	panel(rect, fill, LINE, 10)
	centered(label, rect, 18, Color("80958a") if disabled else (DARK if primary else INK), true)
	if not disabled: hit(rect, id, change.bind(action, value))

func symbol(center: Vector2, r: float, kind: String, tint: Color):
	draw_arc(center, r, 0, TAU, 64, Color(tint, 0.2), 1.5, true)
	draw_arc(center, r * 0.78, -0.8, 2.5, 32, Color(tint, 0.4), 1.0, true)
	var points = PackedVector2Array()
	var n = 4
	match kind:
		"先锋": n = 4
		"支援": n = 6
		"游侠": n = 3
		"干扰": n = 5
		"共鸣": n = 8
		"生长": n = 7
	for i in range(n):
		var angle = - PI / 2 + TAU * i / n
		points.append(center + Vector2(cos(angle), sin(angle)) * r * 0.59)
	draw_colored_polygon(points, Color(tint, 0.12))
	points.append(points[0])
	draw_polyline(points, tint, 2.0, true)
	draw_circle(center, 4, tint)
	for i in range(3):
		var a = i * TAU / 3
		draw_circle(center + Vector2(cos(a), sin(a)) * r, 2.6, tint)

func background():
	var w = size.x
	var h = size.y
	draw_rect(Rect2(0, 0, w, h), BG)
	var scale = maxf(w / 1440.0, h / 900.0)
	var bg_w = 1440.0 * scale
	var bg_h = 900.0 * scale
	draw_texture_rect(backdrop, Rect2((w - bg_w) / 2.0, (h - bg_h) / 2.0, bg_w, bg_h), false)
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.2, 0.2, 0.25))
	draw_rect(Rect2(0, 0, w, 63), Color("233e50"))
	start_ui.icon(self, "emblem", Rect2(24, 12, 39, 39))
	draw_texture_rect(start_ui.LOGO, Rect2(72, 16, 110, 28), false)
	text_at("星际远征", Vector2(204, 39), 13, MINT, true)
	text_at("单人远征  /  三区争夺", Vector2(w - 237, 39), 13, MUTED)
	draw_line(Vector2(0, 62), Vector2(w, 62), Color("526e80"), 1.5)

func _draw():
	builder_search.visible = screen in ["builder", "archive"] and modal == ""
	workshop.sync(self)
	hits.clear()
	if screen != "menu": background()
	if screen == "menu": draw_menu()
	elif screen == "builder": deck_builder.draw(self)
	elif screen == "archive": start_ui.archive(self)
	else:
		match game.s.phase:
			"map": draw_map()
			"battle", "result": draw_battle()
			"reward", "replace": draw_rewards()
			"complete", "gameover": draw_ending()
	if modal != "":
		hits.clear()
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.1, 0.22, 0.22, 0.96))
		draw_modal()
	if not busy: tooltip_ui.draw(self)
	if toast != "":
		var notice = Rect2((size.x - 970) / 2.0, 813, 970, 42) if modal in ["library", "random", "presets"] else Rect2((size.x - 700) / 2.0, 642, 700, 40)
		panel(notice, Color("332e22"), GOLD, 8)
		centered(toast, notice.grow(-8), 15, GOLD)

func draw_menu():
	start_ui.draw(self)

func load_settings():
	if not FileAccess.file_exists(settings_path): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if not saved is Dictionary: return
	if saved.get("speed", 1.0) in [0.0, 1.0, 2.0]: animation_speed = float(saved.speed)
	if saved.get("fullscreen", false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings():
	if test_mode: return
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"speed": animation_speed, "fullscreen": DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED}))

func top_actions():
	var right_x = size.x - 30.0
	button("主菜单", Rect2(right_x - 107, 78, 107, 40), "menu")
	button("规则", Rect2(right_x - 211, 78, 92, 40), "help")
	button("牌组 · 12", Rect2(right_x - 368, 78, 145, 40), "deck")

func draw_map():
	top_actions()
	text_at("战役地图", Vector2(64, 164), 40, INK, true)
	text_at(game.enemy_for_stage().story, Vector2(66, 205), 20, MUTED)
	text_at("剩余机会  " + "● ".repeat(int(game.s.lives)), Vector2(66, 253), 19, GOLD)
	var stage = int(game.s.stage)
	var cx = size.x / 2.0
	draw_line(Vector2(cx - 460, 464), Vector2(cx + 460, 464), LINE, 4)
	for i in range(3):
		var x = cx - 620 + i * 420
		var current = i == stage
		var done = i < stage
		var enemy = game.enemy_for_stage(i)
		panel(Rect2(x, 310, 400, 390), Color("456654") if current else PANEL, GOLD if current else LINE, 12)
		text_at(enemy.title, Vector2(x + 28, 346), 16, MINT if current else MUTED)
		portrait(enemy.portrait, Rect2(x + 130, 365, 140, 140), not current and not done)
		text_at(enemy.name, Vector2(x + 28, 546), 28, INK, true)
		text_at(enemy.archetype, Vector2(x + 28, 578), 18, GOLD, true)
		paragraph(enemy.desc, Vector2(x + 28, 610), 344, 16, MUTED, 23)
		text_at("已通过" if done else ("当前目的地" if current else "尚未抵达"), Vector2(x + 28, 679), 15, MINT if done or current else MUTED)
		button("查看敌情", Rect2(x + 250, 650, 120, 33), "enemy", i)
	button("进入战斗  →", Rect2(size.x - 360, 744, 320, 65), "start", null, true)
	paragraph("每站从全部24套牌型中独立随机抽取，可以重复遭遇；读档不重抽。\n战败消耗1次机会；战后可获取新牌替换旧卡。", Vector2(66, 755), minf(900.0, size.x - 420.0), 19, MUTED, 31)
	text_at("进度自动保存在本机", Vector2(66, 853), 15, MUTED)

func draw_battle():
	battle_ui.draw(self)

func draw_hand_card(card: Dictionary, rect: Rect2, index: int):
	var data = Rules.CARDS[card.id]
	var enabled = game.card_cost(card) <= displayed_energy()
	var accent = MINT if enabled else MUTED
	panel(rect, Color("496a7b") if index == selected else Color("304c5c"), GOLD if index == selected else (accent if hovered == "select" + str(index) else Color("688594")), 9)
	var art_size = minf(rect.size.x - 12, 76)
	portrait(card.id, Rect2(rect.position + Vector2((rect.size.x - art_size) / 2, 8), Vector2(art_size, art_size)), not enabled)
	badge(str(game.card_cost(card)), rect.position + Vector2(17, 18), Color("6f9e9a"), 14)
	badge(str(game.raw_power(card)), rect.position + Vector2(rect.size.x - 17, 18), Color("e6bd79"), 14)
	centered(data.name, Rect2(rect.position + Vector2(2, 84), Vector2(rect.size.x - 4, 24)), mini(16, int((rect.size.x - 8) / maxi(data.name.length(), 1))), INK, true)
	centered("%d · %s" % [index + 1, data.kind], Rect2(rect.position + Vector2(0, 111), Vector2(rect.size.x, 17)), 12, MUTED)
	hit(rect, "select" + str(index), change.bind("select", index), "%s · %s" % [data.name, data.text])
	card_hint(card)

func draw_result():
	hits.clear()
	var reveal_amount = 1.0 if animation_speed == 0 else clampf(result_age / maxf(scaled_duration(0.5), 0.001), 0, 1)
	for lane in range(3):
		var points = battle_ui.lane_polygon(lane, 2)
		points.append(points[0])
		draw_polyline(points, Color(MINT if game.s.result.scores[0][lane] > game.s.result.scores[1][lane] else GOLD, 1.0 - reveal_amount), 5, true)
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.08, 0.16, 0.82 * reveal_amount))
	draw_set_transform(Vector2(0, (1.0 - reveal_amount) * 22), 0, Vector2.ONE)
	var px = (size.x - 715) / 2.0
	panel(Rect2(px, 225, 715, 455), Color("304c5c"), GOLD, 14)
	var r = game.s.result
	var title = {"win": "遭遇战胜利", "loss": "冒险暂时受阻", "tie": "势均力敌"}[r.outcome]
	centered(title, Rect2(px + 30, 258, 655, 65), 40, MINT if r.outcome == "win" else GOLD, true)
	centered("获胜区域  %d : %d    /    总战力  %d : %d" % [r.wins[0], r.wins[1], roundi(r.totals[0] * reveal_amount), roundi(r.totals[1] * reveal_amount)], Rect2(px + 30, 347, 655, 35), 21, INK)
	for lane in range(3):
		var x = px + 30 + lane * 220
		centered(Rules.REGIONS[int(game.s.battle.regions[lane])].name, Rect2(x, 412, 210, 30), 18, MUTED)
		centered("%d : %d" % [roundi(r.scores[0][lane] * reveal_amount), roundi(r.scores[1][lane] * reveal_amount)], Rect2(x, 452, 210, 36), 28, INK, true)
	var description = "人物、异族与舰队都能入队。选择一张卡，补强你的队伍。"
	if r.outcome == "win" and game.s.stage == 2: description = "已击退" + game.enemy_for_stage().name + "，舰队完成了裂隙远征。"
	elif r.outcome == "loss": description = "消耗 1 次机会，剩余 %d 次。调整策略后重新挑战。" % game.s.lives
	elif r.outcome == "tie": description = "区域和总战力均持平。不消耗机会，重新挑战。"
	centered(description, Rect2(px + 20, 516, 675, 30), 17, MUTED)
	button("选择奖励  →" if r.outcome == "win" and game.s.stage < 2 else "继续  →", Rect2(px + 225, 578, 265, 58), "next", null, true, reveal_amount < 1.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func displayed_card_power(card: Dictionary) -> int:
	var found = game.locate(card.get("uid", -1)) if game.s.get("battle", {}).has("boards") else {}
	return game.raw_power(card) if found.is_empty() else game.card_power(found.side, found.lane, found.index)

func large_card(id: String, rect: Rect2, live_card: Dictionary = {}):
	var data = Rules.CARDS[id]
	panel(rect, Color("365363"), Color("ba9b63"), 12)
	portrait(id, Rect2(rect.position + Vector2((rect.size.x - 160) / 2, 12), Vector2(160, 160)))
	badge(str(data.cost if live_card.is_empty() else game.card_cost(live_card)), rect.position + Vector2(31, 35), Color("6f9e9a"), 22)
	badge(str(data.power if live_card.is_empty() else displayed_card_power(live_card)), rect.position + Vector2(rect.size.x - 31, 35), Color("e6bd79"), 22)
	centered(data.name, Rect2(rect.position + Vector2(10, 171), Vector2(rect.size.x - 20, 40)), 27, INK, true)
	centered(data.kind, Rect2(rect.position + Vector2(10, 215), Vector2(rect.size.x - 20, 24)), 15, GOLD)
	var size_px = 16
	while size_px > 13 and (tooltip_ui.lines(self, data.text, rect.size.x - 50, size_px).size() - 1) * (size_px + 8) > rect.size.y - 270: size_px -= 1
	paragraph(data.text, rect.position + Vector2(25, 254), rect.size.x - 50, size_px, MUTED, size_px + 8)

func draw_rewards():
	top_actions()
	if game.s.phase == "reward":
		text_at("招募新的队友", Vector2(90, 190), 42, INK, true)
		text_at("人物、异族与舰队自由混搭。选一张替换旧卡，牌组保持 12 张。", Vector2(93, 240), 20, MUTED)
		var cx = size.x / 2.0
		for i in range(game.s.rewards.size()):
			var x = cx - 530 + i * 370
			large_card(game.s.rewards[i], Rect2(x, 300, 320, 350))
			hit(Rect2(x, 300, 320, 350), "reward_art" + str(i), func(): pass)
			card_hint(preview_card(game.s.rewards[i]))
			button("招募异族单位" if Rules.MONSTERS.has(game.s.rewards[i]) else "获取卡牌", Rect2(x, 670, 320, 58), "reward", game.s.rewards[i], true)
		button("保留现有牌组，继续冒险", Rect2((size.x - 390) / 2.0, 786, 390, 50), "skip")
	else:
		text_at("为「%s」腾出一个位置" % Rules.CARDS[game.s.chosen].name, Vector2(90, 180), 36, INK, true)
		text_at("点击要替换的卡牌。牌组始终保持 12 张；费用曲线和配合都很重要。", Vector2(93, 226), 20, MUTED)
		var grid_x = maxf(90.0, (size.x - 4 * 321) / 2.0)
		draw_deck_grid(Vector2(grid_x, 280), true)
		button("返回奖励选择", Rect2(grid_x, 808, 250, 48), "back_reward")
		button("跳过奖励", Rect2(size.x - grid_x - 240, 808, 240, 48), "skip")

func draw_deck_grid(origin: Vector2, replacing: bool, cards: Array = []):
	var deck = game.s.deck if cards.is_empty() else cards
	for i in range(deck.size()):
		var id = deck[i]
		var data = Rules.CARDS[id]
		var rect = Rect2(origin + Vector2((i % 4) * 321, (i / 4 as int) * 177), Vector2(303, 162))
		panel(rect, Color("365363"), GOLD if hovered == "replace" + str(i) else Color("829aa7"), 10)
		portrait(id, Rect2(rect.position + Vector2(12, 10), Vector2(65, 65)))
		text_at(data.name, rect.position + Vector2(88, 34), 23, INK, true)
		text_at("%d 能量  /  %d 战力" % [data.cost, data.power], rect.position + Vector2(89, 64), 16, MINT)
		paragraph(data.text, rect.position + Vector2(15, 99), 273, 13, MUTED, 18)
		if replacing: hit(rect, "replace" + str(i), change.bind("replace", i), data.text)
		else: hit(rect, "deck_card" + id, func(): pass, data.text)
		card_hint(preview_card(id))

func draw_ending():
	var won = game.s.phase == "complete"
	var cx = size.x / 2.0
	portrait("011" if won else "001", Rect2(cx - 105, 153, 210, 210))
	star(Vector2(cx - 148, 213), 21, Color("dfaa4d"))
	star(Vector2(cx + 148, 278), 15, Color("dfaa4d"))
	centered("裂隙已封锁，舰队凯旋。" if won else "返回母港，重新组队。", Rect2(cx - 520, 420, 1040, 70), 48, INK, true)
	centered("来自不同星域的同伴，完成了这次共同的远征。" if won else "本次远征暂告一段落。用新的牌组再次挑战星际战区。", Rect2(cx - 530, 525, 1060, 40), 22, MUTED)
	centered("通过 %d / 3 站    ·    剩余机会 %d" % [3 if won else game.s.stage, game.s.lives], Rect2(cx - 520, 590, 1040, 35), 19, GOLD)
	button("开启新的远征", Rect2(cx - 260, 699, 250, 60), "new", null, true)
	button("查看最终牌组", Rect2(cx + 10, 699, 250, 60), "deck")
	button("回到主菜单", Rect2(cx - 120, 796, 240, 44), "menu")

func draw_modal():
	if modal == "settings": start_ui.settings(self)
	elif modal == "restart_deck":
		var px = (size.x - 660) / 2.0
		panel(Rect2(px, 270, 660, 350), PANEL, LINE, 22)
		text_at("准备开始新远征", Vector2(px + 45, 339), 32, INK, true)
		paragraph("新牌组已准备完成。出发将替换当前远征进度，已保存的五套卡组会保留。", Vector2(px + 45, 392), 560, 20, MUTED, 31)
		button("继续编辑", Rect2(px + 45, 521, 250, 55), "close")
		button("确认出发", Rect2(px + 325, 521, 250, 55), "launch_deck", null, true)
	elif modal == "survey":
		var choice = game.s.battle.choice
		var recall = choice.get("kind", "") == "recall"
		var inherit = choice.get("kind", "") == "inherit"
		var title = "选择1名友军，改为0费并撤回手牌" if recall else ("选择1名死灵友军，摧毁并继承" if inherit else "深层勘探 · 选择一张加入手牌")
		var hint = "保留增减益、护盾和技能次数；可以选择自身。" if recall else ("继承增减战力和剩余技能次数，不继承基础数值或护盾；必须成功摧毁。" if inherit else "其余牌放回牌库底部，随后继续本回合揭示。")
		var cx = size.x / 2.0
		centered(title, Rect2(cx - 540, 112, 1080, 52), 32, INK, true)
		centered(hint, Rect2(cx - 580, 168, 1160, 35), 18, MUTED)
		var cards = []
		if recall or inherit:
			for uid in choice.uids: cards.append(game.locate(uid).card)
		else: cards = choice.cards
		var columns = mini(6, cards.size())
		var width = minf(340, 1240.0 / columns - 16)
		var height = 350.0 if cards.size() <= 3 else 225.0
		for i in range(cards.size()):
			var card = cards[i]
			var rect = Rect2((size.x - columns * (width + 16)) / 2 + (i % columns) * (width + 16), 236 + (i / columns as int) * (height + 55), width, height)
			if cards.size() <= 3: large_card(card.id, rect, card)
			else:
				panel(rect, PANEL, LINE, 12)
				portrait(card.id, Rect2(rect.position + Vector2((width - 126) / 2, 12), Vector2(126, 126)))
				centered(Rules.CARDS[card.id].name, Rect2(rect.position + Vector2(4, 152), Vector2(width - 8, 30)), 17, INK, true)
				centered("%d费 / %d战力" % [game.card_cost(card), displayed_card_power(card)], Rect2(rect.position + Vector2(4, 187), Vector2(width - 8, 28)), 14, GOLD)
			hit(rect, "survey_art" + str(i), func(): pass)
			card_hint(card)
			button("选择这张", Rect2(rect.position + Vector2(0, height + 8), Vector2(width, 42)), "survey_choose", i, true)
	elif modal == "skills":
		var found = game.locate(action_uid)
		if found.is_empty(): return
		var ids = game.skill_ids(found.card)
		var pages = ceili(ids.size() / 5.0)
		skill_page = clampi(skill_page, 0, pages - 1)
		var px = (size.x - 1100.0) / 2.0
		panel(Rect2(px, 105, 1100, 720), PANEL, LINE, 22)
		text_at(Rules.CARDS[found.card.id].name + " · 技能", Vector2(px + 35, 150), 30, INK, true)
		text_at("同名技能不叠加。每种装置独立计次；重启补充剩余次数最少的一种。", Vector2(px + 35, 180), 17, MUTED)
		for i in range(skill_page * 5, mini(ids.size(), (skill_page + 1) * 5)):
			var id = ids[i]
			var y = 205 + (i % 5) * 105
			portrait(id, Rect2(px + 35, y, 70, 70))
			var label = Rules.CARDS[id].name + (" · 本体" if id == found.card.id else " · 已获得")
			if id in Rules.Skills.device_ids(found.card): label += " · 装置剩余%d" % game.device_remaining(found.card, id)
			text_at(label, Vector2(px + 125, y + 20), 17, INK, true)
			SkillText.draw(self, Rules.Skills.text(found.card, id), Vector2(px + 125, y + 48), 735, 16, INK, 24)
			if found.side == 0 and id in game.active_ids(found.card):
				var move = id in Rules.Balance.SELF_MOVE
				button("移动" if move else "发动", Rect2(px + 950, y + 15, 110, 48), "device_move" if move else "use_skill", id, true, not game.can_activate(action_uid, id))
		button("上一页", Rect2(px + 35, 755, 160, 46), "skill_page", skill_page - 1, false, skill_page == 0)
		centered("%d / %d" % [skill_page + 1, pages], Rect2(px + 210, 755, 150, 46), 18, MUTED)
		button("下一页", Rect2(px + 375, 755, 160, 46), "skill_page", skill_page + 1, false, skill_page + 1 == pages)
		button("返回战场", Rect2(px + 870, 755, 190, 46), "close")
	elif modal == "device":
		var found = game.locate(action_uid)
		if found.is_empty(): return
		var px = (size.x - 830.0) / 2.0
		large_card(found.card.id, Rect2(px, 220, 360, 420), found.card)
		text_at("技能控制", Vector2(px + 430, 285), 34, INK, true)
		paragraph(game.state_line(found.card), Vector2(px + 430, 335), 420, 18, MUTED, 28)
		button("发动主动技能", Rect2(px + 430, 420, 400, 54), "use_skill", null, true, not game.can_activate(action_uid))
		button("搏命2 · 重启2", Rect2(px + 430, 494, 400, 54), "reboot", null, true, not game.can_reboot(action_uid))
		button("返回战场", Rect2(px + 430, 581, 400, 48), "close")
	elif modal == "presets": workshop.draw_presets(self)
	elif modal == "library": workshop.draw_library(self)
	elif modal == "random": workshop.draw_random(self)
	elif modal == "restart":
		var px = (size.x - 630.0) / 2.0
		panel(Rect2(px, 290, 630, 320), PANEL, LINE, 20)
		text_at("重新启程？", Vector2(px + 45, 355), 35, INK, true)
		paragraph("当前远征进度会被新远征替换。", Vector2(px + 45, 415), 540, 21, MUTED)
		button("继续当前远征", Rect2(px + 45, 500, 240, 60), "close")
		panel(Rect2(px + 310, 500, 270, 60), Color("f7bc42"), LINE, 10)
		centered("开始新的远征", Rect2(px + 310, 500, 270, 60), 18, DARK, true)
		hit(Rect2(px + 310, 500, 270, 60), "confirm_restart", new_run)
	elif modal == "enemy":
		var enemy = game.enemy_for_stage(intel_stage)
		var start_x = maxf(90.0, (size.x - 1254.0) / 2.0)
		text_at(enemy.name + " · " + enemy.archetype, Vector2(start_x, 130), 34, INK, true)
		text_at("敌方初始牌组 · 12张 · 不显示当前手牌与抽牌顺序", Vector2(start_x + 3, 172), 18, MUTED)
		paragraph("应对建议：" + enemy.tip, Vector2(start_x + 3, 212), 1254, 17, MINT, 24)
		var core_names = []
		for id in enemy.core: core_names.append(Rules.CARDS[id].name)
		text_at("核心卡：" + " / ".join(core_names), Vector2(start_x + 3, 250), 16, GOLD)
		draw_deck_grid(Vector2(start_x, 278), false, enemy.deck)
		button("返回", Rect2(size.x - 260, 815, 240, 42), "close", null, true)
	elif modal == "deck":
		text_at("你的牌组", Vector2(90, 135), 38, INK, true)
		text_at("12 张队伍卡  ·  人物、异族与舰队可自由混搭", Vector2(93, 183), 20, MUTED)
		draw_deck_grid(Vector2(90, 240), false)
		button("保存到卡组库", Rect2(810, 802, 270, 52), "builder_library")
		button("返回", Rect2(1110, 802, 240, 52), "close", null, true)
	elif modal == "help":
		text_at("六回合，赢下一场冒险。", Vector2(135, 160), 40, INK, true)
		var lines = [
			["01 / 自由组牌", "开始远征时，从121张卡牌中选择12张，每张限1张，可跨族群混编。支持10套预设、五个卡组存档位和按均费随机组牌。衍生物不占初始卡池。"], 
			["02 / 六边战区", "17种地形，第1～3回合依次揭晓。悬停区域标题查看完整规则与剩余次数。每区双方各4格，六回合后比获胜区域，同分比总战力。点击手牌再点战区部署。"], 
			["03 / 能量与揭示", "每回合基础能量等于回合数，未使用能量不结转。采能环主动提供2点当回合能量。0费外神以提交部署后的剩余能量获得战力。单数回合你先揭示，双数敌先。"], 
			["04 / 护盾与复活", "护盾抵消一次普通减力或摧毁。减力至0即摧毁，仍受摧毁免疫保护；地形减力也会致死。天然0战力未受减力时保留。复活不恢复装置次数。"], 
			["05 / 种族机制", "点击亮点单位发动主动技能，每回合限1次。装置X为总次数；重启X补充次数，每名单位每局仅1次。搏命不受护盾抵挡。进化保留增减益并额外-1战力。"], 
			["06 / 结算与远征", "回合结束依次结算卡牌、场地、自然进化，再计分。场地按左、中、右处理，双方次数独立。固有确保首回合上手，手牌上限8张。通过三站完成远征，战后选牌替换旧卡。"]
		]
		for i in range(lines.size()):
			var y = 223 + i * 91
			text_at(lines[i][0], Vector2(138, y), 20, MINT, true)
			paragraph(lines[i][1], Vector2(380, y), 900, 17, INK, 26)
		button("明白了，继续", Rect2(1040, 795, 265, 56), "close", null, true)
		text_at("悬停卡牌可查看能力  ·  右键取消选牌  ·  Esc 关闭弹窗", Vector2(138, 830), 17, MUTED)
	elif modal == "log":
		text_at("最近的战斗记录", Vector2(145, 146), 38, INK, true)
		text_at("按实际揭示顺序记录。这里只显示最近 18 条。", Vector2(148, 191), 18, MUTED)
		var logs = game.s.battle.logs
		var start = maxi(0, logs.size() - 18)
		for i in range(start, logs.size()):
			text_at(logs[i], Vector2(150, 244 + (i - start) * 29), 18, MINT if logs[i].begins_with("第") else INK)
		button("返回战斗", Rect2(1040, 805, 265, 52), "close", null, true)
