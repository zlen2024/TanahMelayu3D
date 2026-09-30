extends Node2D

# Deterministic decorative landmarks. All clients build the same silhouettes.
# The parent participates in the world's Y sorting, including its children.
var kind := -1

func _ready():
	if kind != -1: return
	y_sort_enabled = true
	for pos in [Vector2(-480, 200), Vector2(460, 120), Vector2(-540, -410), Vector2(620, -480)]:
		_place(1, pos)
	for pos in [Vector2(-420, 65), Vector2(-540, 300), Vector2(420, 310), Vector2(620, 70), Vector2(-210, 420), Vector2(240, -410), Vector2(-430, -440), Vector2(-680, -200), Vector2(720, 330), Vector2(-780, 440), Vector2(340, 650), Vector2(-300, -670)]:
		_place(0, pos)
	for pos in [Vector2(-95, 105), Vector2(115, -100), Vector2(-95, -350), Vector2(120, 370)]:
		_place(2, pos)

func _place(type: int, pos: Vector2):
	var prop := Node2D.new()
	prop.set_script(get_script())
	prop.kind = type
	prop.position = pos
	add_child(prop)
	# Block the footprint, leaving the roof and fronds free for Y-sort overlap.
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	prop.add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(112, 40) if type == 1 else Vector2(10, 10)
	shape.position.y = -14 if type == 1 else 0
	shape.shape = rect
	body.add_child(shape)

func _draw():
	if kind < 0: return
	if kind == 0: _palm()
	elif kind == 1: _house()
	else: _lantern()

func _poly(points: Array, col: String):
	draw_colored_polygon(PackedVector2Array(points), Color(col))

func _palm():
	draw_set_transform(Vector2(8, 5), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 36, Color(0.01, 0.025, 0.015, 0.24))
	draw_set_transform(Vector2.ZERO)
	_poly([Vector2(-7, 2), Vector2(5, 2), Vector2(16, -73), Vector2(8, -78)], "68533a")
	draw_line(Vector2(-2, 0), Vector2(12, -76), Color("ab9061"), 3)
	for y in range(9):
		draw_line(Vector2(y * 1.2 - 4, -y * 8), Vector2(y * 1.2 + 6, -y * 8 - 2), Color("463d2b"), 2)
	var crown := Vector2(12, -77)
	for i in range(9):
		var angle := float(i) * TAU / 9.0
		var tip := crown + Vector2(cos(angle) * 65, sin(angle) * 29 + 10)
		var middle := crown.lerp(tip, 0.55)
		var normal := (tip - crown).normalized().orthogonal() * 9
		_poly([crown, middle + normal, tip, middle - normal], "204e37" if i % 2 == 0 else "2b6140")
		draw_line(crown, middle, Color("64804a"), 1)
		draw_line(middle, tip, Color("64804a"), 1)
	for x in range(3): draw_circle(crown + Vector2(x * 5 - 4, 5), 4, Color("90734a"))

func _house():
	draw_rect(Rect2(-69, -8, 149, 28), Color(0.01, 0.02, 0.01, 0.3))
	for x in [-52, -16, 20, 54]:
		draw_rect(Rect2(x, -43, 7, 52), Color("493a28"))
		draw_line(Vector2(x + 1, -40), Vector2(x + 1, 9), Color("977147"), 2)
	draw_rect(Rect2(-62, -77, 128, 57), Color("64472e"))
	for x in range(-59, 65, 8): draw_line(Vector2(x, -77), Vector2(x, -20), Color("926a43"), 1)
	draw_rect(Rect2(-17, -60, 25, 41), Color("231f19"))
	for x in [-46, 30]:
		draw_rect(Rect2(x - 3, -62, 25, 27), Color("362a1c"))
		draw_rect(Rect2(x, -59, 19, 21), Color("d5a154"))
		draw_line(Vector2(x + 9, -60), Vector2(x + 9, -37), Color("71502a"), 3)
	_poly([Vector2(-79, -72), Vector2(0, -137), Vector2(82, -72)], "463b29")
	_poly([Vector2(-76, -76), Vector2(0, -132), Vector2(76, -76)], "8d7650")
	for y in range(7):
		var width := 10.0 + y * 10
		draw_line(Vector2(-width, -125 + y * 7), Vector2(width, -125 + y * 7), Color("665338"), 3)
	draw_polyline(PackedVector2Array([Vector2(-80, -74), Vector2(0, -137), Vector2(82, -74)]), Color("c3a16b"), 3)
	draw_rect(Rect2(-68, -25, 141, 8), Color("ad8754"))
	for x in range(-63, 70, 12): draw_line(Vector2(x, -39), Vector2(x, -20), Color("b08a59"), 3)
	draw_line(Vector2(-68, -40), Vector2(72, -40), Color("c19b64"), 3)
	for step in range(4): draw_rect(Rect2(-15, -15 + step * 6, 26, 4), Color("b18d5d"))

func _lantern():
	for radius in [30, 22, 14]: draw_circle(Vector2(0, -29), radius, Color(1.0, 0.65, 0.22, 0.035))
	draw_line(Vector2.ZERO, Vector2(0, -36), Color("6e5134"), 4)
	draw_rect(Rect2(-7, -39, 14, 17), Color("60482e"))
	draw_rect(Rect2(-5, -37, 10, 13), Color("ecc174"))
	draw_line(Vector2(0, -37), Vector2(0, -24), Color("9e6933"), 2)
	_poly([Vector2(-10, -40), Vector2(0, -47), Vector2(10, -40)], "68543a")
