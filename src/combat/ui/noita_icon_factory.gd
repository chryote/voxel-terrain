class_name NoitaIconFactory
extends RefCounted

## Procedural pixel-art icon generator for weapons and technique cards.
## Recreates the authentic 16-bit pixel aesthetic seen in Noita.

static var _icon_cache: Dictionary = {}

static func get_weapon_icon(weapon_id: String) -> Texture2D:
	var key = "weapon_" + weapon_id
	if _icon_cache.has(key):
		return _icon_cache[key]

	var tex = _generate_weapon_icon(weapon_id)
	_icon_cache[key] = tex
	return tex

static func get_card_icon(card_id: String, card_type: String = "") -> Texture2D:
	var key = "card_" + card_id
	if _icon_cache.has(key):
		return _icon_cache[key]

	var tex = _generate_card_icon(card_id, card_type)
	_icon_cache[key] = tex
	return tex

static func _generate_weapon_icon(weapon_id: String) -> Texture2D:
	var w = 28
	var h = 28
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match weapon_id:
		"apprentice_blade":
			# Stylized broadsword with cyan glow and brass hilt
			# Pommel
			_draw_pixel(img, 5, 23, Color(0.9, 0.75, 0.25))
			_draw_pixel(img, 6, 24, Color(0.7, 0.55, 0.15))
			# Grip
			for i in range(3):
				_draw_pixel(img, 6 + i, 22 - i, Color(0.35, 0.22, 0.12))
				_draw_pixel(img, 7 + i, 23 - i, Color(0.25, 0.15, 0.08))
			# Guard
			for g in range(-2, 3):
				var gx = 9 + g
				var gy = 19 + g
				_draw_pixel(img, gx - 1, gy + 1, Color(0.85, 0.7, 0.2))
				_draw_pixel(img, gx, gy, Color(1.0, 0.85, 0.35))
			# Blade
			for b in range(12):
				var bx = 11 + b
				var by = 17 - b
				# Edges
				_draw_pixel(img, bx, by + 1, Color(0.65, 0.85, 0.95))
				_draw_pixel(img, bx + 1, by, Color(0.95, 0.98, 1.0))
				# Center cyan fuller glow
				_draw_pixel(img, bx, by, Color(0.2, 0.8, 1.0))
			# Sharp Tip
			_draw_pixel(img, 23, 5, Color(1.0, 1.0, 1.0))
			_draw_pixel(img, 24, 4, Color(0.7, 0.9, 1.0))
			_draw_pixel(img, 23, 4, Color(1.0, 1.0, 1.0))

		"flurry_rapier":
			# Slender crimson rapier with curved basket guard
			# Pommel
			_draw_pixel(img, 4, 24, Color(0.8, 0.8, 0.85))
			# Grip
			_draw_pixel(img, 5, 23, Color(0.2, 0.2, 0.2))
			_draw_pixel(img, 6, 22, Color(0.15, 0.15, 0.15))
			_draw_pixel(img, 7, 21, Color(0.2, 0.2, 0.2))
			# Curved Basket Guard
			_draw_pixel(img, 6, 20, Color(0.9, 0.75, 0.3))
			_draw_pixel(img, 7, 19, Color(1.0, 0.85, 0.4))
			_draw_pixel(img, 8, 19, Color(1.0, 0.85, 0.4))
			_draw_pixel(img, 9, 20, Color(0.85, 0.7, 0.25))
			_draw_pixel(img, 9, 21, Color(0.7, 0.55, 0.2))
			_draw_pixel(img, 8, 22, Color(0.6, 0.45, 0.15))
			# Needle Blade (Crimson / Silver)
			for b in range(14):
				var bx = 9 + b
				var by = 19 - b
				_draw_pixel(img, bx, by, Color(1.0, 0.35, 0.45))
				if b % 2 == 0:
					_draw_pixel(img, bx + 1, by, Color(1.0, 0.85, 0.9))
			# Needle Point
			_draw_pixel(img, 23, 5, Color(1.0, 0.9, 0.95))
			_draw_pixel(img, 24, 4, Color(1.0, 1.0, 1.0))

		_:
			# Generic Greatsword fallback
			for i in range(16):
				var px = 6 + i
				var py = 22 - i
				_draw_pixel(img, px, py, Color(0.75, 0.75, 0.8))
				_draw_pixel(img, px + 1, py, Color(0.9, 0.9, 0.95))
				_draw_pixel(img, px, py + 1, Color(0.5, 0.5, 0.55))

	return ImageTexture.create_from_image(img)

static func _generate_card_icon(card_id: String, card_type: String) -> Texture2D:
	var w = 24
	var h = 24
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match card_id:
		"motion_horizontal_sweep":
			# Cyan sweeping crescent arc from left to right
			for t in range(18):
				var frac = float(t) / 17.0
				var ang = lerpf(-PI * 0.75, PI * 0.15, frac)
				var cx = 11.0 + cos(ang) * 9.0
				var cy = 11.0 + sin(ang) * 9.0
				_draw_pixel_f(img, cx, cy, Color(1.0, 1.0, 1.0))
				_draw_pixel_f(img, cx - 1.0, cy, Color(0.2, 0.8, 1.0, 0.9))
				_draw_pixel_f(img, cx + 1.0, cy, Color(0.1, 0.5, 0.9, 0.8))
				_draw_pixel_f(img, cx, cy + 1.0, Color(0.05, 0.3, 0.7, 0.6))

		"motion_upswing":
			# Upward rising cyan crescent
			for t in range(18):
				var frac = float(t) / 17.0
				var ang = lerpf(PI * 0.45, -PI * 0.45, frac)
				var cx = 13.0 + cos(ang) * 9.0
				var cy = 12.0 + sin(ang) * 9.0
				_draw_pixel_f(img, cx, cy, Color(1.0, 1.0, 1.0))
				_draw_pixel_f(img, cx - 1.0, cy, Color(0.3, 0.85, 1.0, 0.9))
				_draw_pixel_f(img, cx, cy + 1.0, Color(0.1, 0.5, 0.9, 0.7))
			# Upward arrow sparkle
			_draw_pixel(img, 13, 3, Color(1.0, 1.0, 1.0))
			_draw_pixel(img, 12, 4, Color(0.6, 0.9, 1.0))
			_draw_pixel(img, 14, 4, Color(0.6, 0.9, 1.0))

		"motion_downcleave":
			# Overhead downward cleave with ground impact burst
			for y in range(4, 18):
				_draw_pixel(img, 12, y, Color(1.0, 1.0, 1.0))
				_draw_pixel(img, 11, y, Color(0.3, 0.75, 1.0, 0.8))
				_draw_pixel(img, 13, y, Color(0.3, 0.75, 1.0, 0.8))
			# Ground impact spark
			for dx in range(-4, 5):
				_draw_pixel(img, 12 + dx, 18, Color(1.0, 0.9, 0.5))
			_draw_pixel(img, 12, 19, Color(1.0, 0.6, 0.2))

		"motion_piercing_thrust":
			# Horizontal laser thrust with sharp diamond point
			for x in range(3, 19):
				_draw_pixel(img, x, 12, Color(1.0, 1.0, 1.0))
				_draw_pixel(img, x, 11, Color(0.2, 0.7, 1.0, 0.7))
				_draw_pixel(img, x, 13, Color(0.2, 0.7, 1.0, 0.7))
			# Diamond piercing point
			_draw_pixel(img, 19, 12, Color(1.0, 1.0, 1.0))
			_draw_pixel(img, 18, 11, Color(0.8, 0.95, 1.0))
			_draw_pixel(img, 18, 13, Color(0.8, 0.95, 1.0))
			_draw_pixel(img, 20, 12, Color(1.0, 1.0, 1.0))

		"mod_swift_edge":
			# Green dual speed chevrons >>
			for k in [5, 12]:
				for y in range(-4, 5):
					var ox = k + (4 - abs(y))
					var oy = 12 + y
					_draw_pixel(img, ox, oy, Color(0.4, 1.0, 0.6))
					_draw_pixel(img, ox - 1, oy, Color(0.15, 0.7, 0.3, 0.7))

		"mod_flame_edge":
			# Orange/red flickering flame tongues
			var flame_coords = [
				Vector2i(12, 5), Vector2i(11, 7), Vector2i(13, 8),
				Vector2i(9, 11), Vector2i(12, 11), Vector2i(14, 12),
				Vector2i(8, 14), Vector2i(11, 14), Vector2i(15, 15),
				Vector2i(9, 17), Vector2i(12, 17), Vector2i(14, 17)
			]
			for pt in flame_coords:
				_draw_pixel(img, pt.x, pt.y, Color(1.0, 0.85, 0.2))
				_draw_pixel(img, pt.x, pt.y + 1, Color(1.0, 0.45, 0.1))
				_draw_pixel(img, pt.x - 1, pt.y + 1, Color(0.85, 0.2, 0.1))

		"mod_heavy_impact":
			# Golden/amber impact shockwave ring
			for ang_i in range(16):
				var ang = float(ang_i) * (TAU / 16.0)
				var rx = int(round(12.0 + cos(ang) * 7.0))
				var ry = int(round(12.0 + sin(ang) * 7.0))
				_draw_pixel(img, rx, ry, Color(1.0, 0.85, 0.3))
			# Center heavy core
			for cx in range(10, 15):
				for cy in range(10, 15):
					if abs(cx - 12) + abs(cy - 12) <= 2:
						_draw_pixel(img, cx, cy, Color(1.0, 0.95, 0.6))

		"multi_double_slash":
			# Dual parallel golden slash arcs
			for offset_y in [-3, 3]:
				for t in range(14):
					var frac = float(t) / 13.0
					var ang = lerpf(-PI * 0.6, PI * 0.2, frac)
					var cx = 11.0 + cos(ang) * 7.0
					var cy = (12.0 + offset_y) + sin(ang) * 6.0
					_draw_pixel_f(img, cx, cy, Color(1.0, 0.9, 0.4))
					_draw_pixel_f(img, cx - 1.0, cy, Color(0.8, 0.6, 0.1, 0.8))

		"trigger_on_hit":
			# Magenta spark trigger star with payload center orb
			# 4 spikes
			for d in range(1, 8):
				_draw_pixel(img, 12, 12 - d, Color(1.0, 0.5, 1.0, 1.0 - float(d) * 0.12))
				_draw_pixel(img, 12, 12 + d, Color(1.0, 0.5, 1.0, 1.0 - float(d) * 0.12))
				_draw_pixel(img, 12 - d, 12, Color(1.0, 0.5, 1.0, 1.0 - float(d) * 0.12))
				_draw_pixel(img, 12 + d, 12, Color(1.0, 0.5, 1.0, 1.0 - float(d) * 0.12))
			# Center orb
			for ox in range(10, 15):
				for oy in range(10, 15):
					if (ox - 12) * (ox - 12) + (oy - 12) * (oy - 12) <= 4:
						_draw_pixel(img, ox, oy, Color(1.0, 0.95, 1.0))

		_:
			# Fallback based on card type
			if "motion" in card_id or card_type == "MotionCard":
				for t in range(12):
					_draw_pixel(img, 6 + t, 18 - t, Color(0.3, 0.8, 1.0))
			elif "mod" in card_id or card_type == "ModifierCard":
				for x in range(8, 17):
					for y in range(8, 17):
						if abs(x - 12) + abs(y - 12) <= 4:
							_draw_pixel(img, x, y, Color(0.3, 0.9, 0.5))
			elif "multi" in card_id or card_type == "MulticastCard":
				for x in [8, 12, 16]:
					for y in range(7, 18):
						_draw_pixel(img, x, y, Color(1.0, 0.8, 0.2))
			elif "trigger" in card_id or card_type == "TriggerCard":
				for i in range(5):
					_draw_pixel(img, 10 + i, 10 + i, Color(0.9, 0.4, 0.9))
					_draw_pixel(img, 14 - i, 10 + i, Color(0.9, 0.4, 0.9))
			else:
				# Generic diamond
				for x in range(7, 18):
					for y in range(7, 18):
						if abs(x - 12) + abs(y - 12) == 4:
							_draw_pixel(img, x, y, Color(0.8, 0.8, 0.8))

	return ImageTexture.create_from_image(img)

static func _draw_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if color.a < 1.0:
			var prev = img.get_pixel(x, y)
			img.set_pixel(x, y, prev.blend(color))
		else:
			img.set_pixel(x, y, color)

static func _draw_pixel_f(img: Image, x: float, y: float, color: Color) -> void:
	_draw_pixel(img, int(round(x)), int(round(y)), color)

