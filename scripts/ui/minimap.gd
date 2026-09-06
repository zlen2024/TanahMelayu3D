extends Control

# Top-right minimap.
#
# The terrain is drawn from a one-pixel-per-tile Image that world.gd builds once
# after generation (build_terrain_image). Drawing it as a scaled texture means
# panning and zooming are source-rect maths rather than thousands of per-cell
# draw calls every refresh.
#
# Entities are still drawn as dots in _draw(), through the same world -> widget
# transform as the terrain, so they stay aligned at every zoom level.

const VIEW_SIZE: float = 150.0     # drawn size in pixels

const COL_BG := Color(0.055, 0.065, 0.09, 0.85)
const COL_BORDER := Color(0.38, 0.32, 0.19, 1.0)
const COL_OBSTACLE := Color(0.45, 0.45, 0.5, 0.9)
const COL_MONSTER := Color(0.9, 0.3, 0.25, 1.0)
const COL_BOSS := Color(1.0, 0.84, 0.0, 1.0)
const COL_LOOT := Color(0.35, 0.9, 1.0, 0.9)
const COL_PEER := Color(0.9, 0.92, 0.95, 1.0)
const COL_SELF := Color(0.25, 0.85, 1.0, 1.0)

# 1.0 shows the whole arena; higher values zoom in around the local player.
const ZOOM_STEPS: Array[float] = [1.0, 2.0, 4.0]

const REFRESH_INTERVAL: float = 1.0 / 15.0

var zoom_index: int = 0

var _refresh_accum: float = 0.0
var _world: Node = null
var _players: Node = null
var _monsters: Node = null
var _obstacles: Node = null

var _terrain_tex: ImageTexture = null
var _half_tiles: int = 38
var _tile_px: int = 32

# Recomputed each redraw: world units covered, and the world point at the centre.
var _view_extent: float = 1216.0
var _view_centre: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(VIEW_SIZE, VIEW_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Scroll to zoom - click to cycle"
	_rebind()


func _process(delta: float) -> void:
	_refresh_accum -= delta
	if _refresh_accum > 0.0:
		return
	_refresh_accum = REFRESH_INTERVAL
	if not is_instance_valid(_world) or _terrain_tex == null:
		_rebind()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(zoom_index + 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(zoom_index - 1)
			MOUSE_BUTTON_LEFT:
				# Cycle, so the map is usable without a scroll wheel.
				_set_zoom((zoom_index + 1) % ZOOM_STEPS.size())


func _set_zoom(idx: int) -> void:
	var clamped: int = clampi(idx, 0, ZOOM_STEPS.size() - 1)
	if clamped == zoom_index:
		return
	zoom_index = clamped
	queue_redraw()


# World is built after the HUD and freed on disconnect, so bind lazily.
func _rebind() -> void:
	_world = get_tree().root.find_child("World", true, false)
	if not _world:
		return
	_players = _world.find_child("Players", true, false)
	_monsters = _world.find_child("Monsters", true, false)
	_obstacles = _world.find_child("Obstacles", true, false)

	if _terrain_tex == null and _world.has_method("build_terrain_image"):
		_half_tiles = _world.map_half_tiles()
		_tile_px = _world.tile_px()
		_terrain_tex = ImageTexture.create_from_image(_world.build_terrain_image())


func _local_player() -> Node2D:
	if not is_instance_valid(_players):
		return null
	for p in _players.get_children():
		if p is Node2D and p.get("is_local") == true:
			return p
	return null


func _to_map(world_pos: Vector2) -> Vector2:
	var scale := VIEW_SIZE / (_view_extent * 2.0)
	return Vector2(VIEW_SIZE, VIEW_SIZE) * 0.5 + (world_pos - _view_centre) * scale


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, Vector2(VIEW_SIZE, VIEW_SIZE))
	draw_rect(box, COL_BG)

	var map_extent := float(_half_tiles * _tile_px)
	var zoom: float = ZOOM_STEPS[zoom_index]
	_view_extent = map_extent / zoom

	# Zoomed in, follow the player but never scroll past the map edge.
	var hero := _local_player()
	if zoom > 1.0 and hero:
		var limit := map_extent - _view_extent
		_view_centre = hero.global_position.clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	else:
		_view_centre = Vector2.ZERO

	if _terrain_tex:
		# World-space view window -> source rect in the one-px-per-tile image.
		var img_size := float(_half_tiles * 2 + 1)
		var px_per_world := 1.0 / float(_tile_px)
		var src_size := (_view_extent * 2.0) * px_per_world
		var src_origin := (_view_centre - Vector2(_view_extent, _view_extent)) * px_per_world \
			+ Vector2(img_size, img_size) * 0.5
		draw_texture_rect_region(_terrain_tex, box, Rect2(src_origin, Vector2(src_size, src_size)))

	if is_instance_valid(_obstacles):
		for pillar in _obstacles.get_children():
			if pillar is Node2D:
				var p := _to_map(pillar.global_position)
				if box.has_point(p):
					draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), COL_OBSTACLE)

	if is_instance_valid(_monsters):
		for mob in _monsters.get_children():
			if not (mob is Node2D) or mob.get("is_dead") == true:
				continue
			var p := _to_map(mob.global_position)
			if not box.has_point(p):
				continue
			# Loot drops are parented to the Monsters container too.
			if mob.is_in_group("loot"):
				draw_circle(p, 1.5 * zoom, COL_LOOT)
			elif mob.is_in_group("monsters"):
				var boss: bool = mob.get("is_king_slime") == true
				draw_circle(p, (3.0 if boss else 2.0) * sqrt(zoom), COL_BOSS if boss else COL_MONSTER)

	if is_instance_valid(_players):
		for p in _players.get_children():
			if not (p is Node2D):
				continue
			var pos := _to_map(p.global_position)
			if not box.has_point(pos):
				continue
			if p.get("is_local") == true:
				draw_circle(pos, 4.0, COL_SELF)
				draw_arc(pos, 6.0, 0, TAU, 16, COL_SELF, 1.0)
			else:
				draw_circle(pos, 2.5, COL_PEER)

	draw_rect(box, COL_BORDER, false, 1.0)

	# Zoom readout, so the level is discoverable without a legend.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(5, VIEW_SIZE - 5), "x%d" % int(ZOOM_STEPS[zoom_index]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.88, 0.92, 0.85))
