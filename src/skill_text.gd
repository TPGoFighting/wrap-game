extends RefCounted

const TIMINGS = ["揭示", "持续", "被动", "主动", "回合结束"]
const WORDS = ["固有", "装置", "进化", "重启", "搏命", "复活", "护盾", "摧毁", "移动", "减力", "免疫"]
const BLUE = Color("87c8f5")
const RED = Color("f0a29a")
const PAPER_BLUE = Color("246dac")
const PAPER_RED = Color("b34b48")

static func categories(value: String) -> Array:
	var result = []
	result.resize(value.length())
	result.fill(0)
	for word in WORDS + TIMINGS:
		var start = value.find(word)
		while start >= 0:
			var end = start + word.length()
			while end < value.length() and value[end].is_valid_int(): end += 1
			for i in range(start, end): result[i] = 2 if word in TIMINGS else 1
			start = value.find(word, end)
	return result

static func draw(v, value: String, pos: Vector2, width: float, size: int, color: Color, spacing: float, paper: bool = false):
	var kinds = categories(value)
	var x = pos.x
	var y = pos.y
	for i in range(value.length()):
		var ch = value[i]
		var advance = v.font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if ch == "\n" or (x + advance > pos.x + width and ch not in "，。！？：；、）】》”"):
			x = pos.x
			y += spacing
		if ch == "\n": continue
		var tint = color
		if kinds[i] == 1: tint = PAPER_BLUE if paper else BLUE
		elif kinds[i] == 2: tint = PAPER_RED if paper else RED
		v.text_at(ch, Vector2(x, y), size, tint)
		x += advance
