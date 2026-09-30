extends Node2D

# World Controller
# Manages arena boundaries, monster spawning, and player spawn points.

var monster_scene = preload("res://scenes/monster.tscn")

@onready var monsters_container = $Monsters
@onready var players_container = $Players
@onready var loot_container = $Loot
@onready var ground_layer: TileMapLayer = $Map/Ground
@onready var detail_layer: TileMapLayer = $Map/Detail

# --- terrain painting -------------------------------------------------------
# Atlas layout is defined in tools/generate_sprites.py :: create_terrain_atlas().
# The 3x3 blocks are nine-slices laid out NW N NE / W C E / SW S SE, so an
# offset is picked from which neighbours share the terrain.
const TILE_PX := 32
const MAP_HALF_TILES := 38            # covers the +/-1200 arena with a margin
const SRC := 0                        # atlas source id in terrain.tres

const GRASS_VARIANTS := 4
const DIRT_ORIGIN := Vector2i(0, 1)
const WATER_ORIGIN := Vector2i(4, 1)
const STONE_ORIGIN := Vector2i(8, 1)

const PROP_ROCK := Vector2i(0, 4)
const PROP_BUSH := Vector2i(1, 4)
const PROP_FLOWERS := Vector2i(2, 4)
const PROP_STUMP := Vector2i(3, 4)
const PROP_TALLGRASS := Vector2i(4, 4)

# Fixed seed: every client paints an identical map without needing to sync it.
const MAP_SEED := 20260906

enum Terrain { GRASS, DIRT, WATER, STONE, CLIFF }

# Monster identity. World-spawned monsters take 1..N in spawn order, which is
# deterministic (_spawn_initial_monsters walks a fixed list), so every client
# derives the same IDs without syncing them.
#
# IDs at or above RUNTIME_ID_BASE are reserved for monsters spawned mid-match
# -- summons, wave spawns -- which cannot be derived and must be allocated by
# the host and carried in the spawn message. Nothing does that yet.
const RUNTIME_ID_BASE := 10000

const PROP_CLIFF := Vector2i(5, 4)

# Wading: each tile of depth away from dry land costs another slice of speed.
const WATER_SLOW_PER_DEPTH := 0.16
const WATER_SLOW_FLOOR := 0.35

var _terrain: Dictionary = {}          # Vector2i -> Terrain
var _next_monster_id: int = 1
var _monsters_by_id: Dictionary = {}   # int -> Monster
var _water_depth: Dictionary = {}      # Vector2i -> int, 1 = shoreline


func _ready():
	NetworkManager.match_started.connect(_on_match_started)

	_build_map()

	# If running as host or dedicated server, spawn initial mobs
	if multiplayer.is_server():
		_spawn_initial_monsters()


# --- map generation ---------------------------------------------------------

func _build_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED

	_lay_out_terrain(rng)
	_compute_water_depth()
	_paint_ground()
	_scatter_props(rng)
	_build_cliff_collision()


# Decide the terrain type of every cell. Kept separate from painting so the
# layout can be reasoned about (and tested) without touching a TileMapLayer.
func _lay_out_terrain(rng: RandomNumberGenerator) -> void:
	_terrain.clear()
	var h := MAP_HALF_TILES

	for y in range(-h, h + 1):
		for x in range(-h, h + 1):
			_terrain[Vector2i(x, y)] = Terrain.GRASS

	# Crossroads through the middle of the arena, with a wobble so they do not
	# read as ruled lines.
	for x in range(-h, h + 1):
		var wob := int(round(sin(x * 0.18) * 1.6))
		for w in range(-2, 3):
			_terrain[Vector2i(x, wob + w)] = Terrain.DIRT
	for y in range(-h, h + 1):
		var wob2 := int(round(cos(y * 0.16) * 1.8))
		for w in range(-2, 3):
			_terrain[Vector2i(wob2 + w, y)] = Terrain.DIRT

	# Pond in the south-east.
	_stamp_blob(Vector2i(17, 14), 7.5, Terrain.WATER, rng)
	_stamp_blob(Vector2i(23, 18), 4.5, Terrain.WATER, rng)

	# Stone clearing around the boss spawn at world (0, -450).
	_stamp_blob(Vector2i(0, -14), 8.0, Terrain.STONE, rng)

	# A couple of smaller dirt clearings so the map is not just crossroads.
	_stamp_blob(Vector2i(-20, 12), 6.0, Terrain.DIRT, rng)
	_stamp_blob(Vector2i(19, -17), 5.0, Terrain.DIRT, rng)

	# Impassable high ground in the far corners. Kept well outside the monster
	# spawn ring (all within ~14 tiles of the origin) so nothing spawns inside
	# a cliff, and cleared off the roads below so the map never seals shut.
	_stamp_blob(Vector2i(-28, -26), 8.0, Terrain.CLIFF, rng)
	_stamp_blob(Vector2i(29, 27), 7.0, Terrain.CLIFF, rng)
	_stamp_blob(Vector2i(-30, 24), 6.0, Terrain.CLIFF, rng)
	_stamp_blob(Vector2i(27, -29), 6.5, Terrain.CLIFF, rng)

	# Roads and water always win over cliffs: a cliff dropped across the
	# crossroads would cut the arena in half.
	for c in _terrain.keys():
		if _terrain[c] == Terrain.CLIFF and _is_on_road(c):
			_terrain[c] = Terrain.GRASS


# Rough circle with a jittered radius, so regions have organic outlines.
func _stamp_blob(centre: Vector2i, radius: float, kind: Terrain, rng: RandomNumberGenerator) -> void:
	var r := int(ceil(radius)) + 2
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dy).length()
			if d <= radius + rng.randf_range(-1.2, 1.2):
				var c := centre + Vector2i(dx, dy)
				if _terrain.has(c):
					_terrain[c] = kind


# A cell counts as road if it is within a tile of the wobbling crossroads.
func _is_on_road(c: Vector2i) -> bool:
	var wob := int(round(sin(c.x * 0.18) * 1.6))
	if absi(c.y - wob) <= 3:
		return true
	var wob2 := int(round(cos(c.y * 0.16) * 1.8))
	return absi(c.x - wob2) <= 3


# Breadth-first from every dry cell, so depth 1 is the shoreline and it grows
# toward the middle of a pond. Precomputed once: the player queries it per frame.
func _compute_water_depth() -> void:
	_water_depth.clear()
	var frontier: Array[Vector2i] = []
	for c in _terrain:
		if _terrain[c] == Terrain.WATER:
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _terrain_at(c + n) != Terrain.WATER:
					_water_depth[c] = 1
					frontier.append(c)
					break

	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			var d: int = _water_depth[c]
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + n
				if _terrain_at(q) == Terrain.WATER and not _water_depth.has(q):
					_water_depth[q] = d + 1
					next.append(q)
		frontier = next


func _terrain_at(c: Vector2i) -> int:
	return _terrain.get(c, Terrain.GRASS)


# Nine-slice offset from which orthogonal neighbours share this terrain.
func _slice_offset(c: Vector2i, kind: int) -> Vector2i:
	var col := 1
	var row := 1
	if _terrain_at(c + Vector2i(-1, 0)) != kind:
		col = 0
	elif _terrain_at(c + Vector2i(1, 0)) != kind:
		col = 2
	if _terrain_at(c + Vector2i(0, -1)) != kind:
		row = 0
	elif _terrain_at(c + Vector2i(0, 1)) != kind:
		row = 2
	return Vector2i(col, row)


func _paint_ground() -> void:
	# Deterministic per-cell grass variant: a hash rather than the RNG, so the
	# result does not depend on iteration order.
	for c in _terrain:
		var kind: int = _terrain[c]
		match kind:
			Terrain.GRASS:
				var v: int = abs(c.x * 73856093 ^ c.y * 19349663) % GRASS_VARIANTS
				ground_layer.set_cell(c, SRC, Vector2i(v, 0))
			Terrain.DIRT:
				ground_layer.set_cell(c, SRC, DIRT_ORIGIN + _slice_offset(c, kind))
			Terrain.WATER:
				ground_layer.set_cell(c, SRC, WATER_ORIGIN + _slice_offset(c, kind))
			Terrain.STONE:
				ground_layer.set_cell(c, SRC, STONE_ORIGIN + _slice_offset(c, kind))
			Terrain.CLIFF:
				ground_layer.set_cell(c, SRC, PROP_CLIFF)


func _scatter_props(rng: RandomNumberGenerator) -> void:
	var h := MAP_HALF_TILES
	for y in range(-h, h + 1):
		for x in range(-h, h + 1):
			var c := Vector2i(x, y)
			# Props only on open grass, and never on a path or in water.
			if _terrain_at(c) != Terrain.GRASS:
				continue
			var roll := rng.randf()
			if roll < 0.055:
				detail_layer.set_cell(c, SRC, PROP_TALLGRASS)
			elif roll < 0.075:
				detail_layer.set_cell(c, SRC, PROP_FLOWERS)
			elif roll < 0.088:
				detail_layer.set_cell(c, SRC, PROP_BUSH)
			elif roll < 0.096:
				detail_layer.set_cell(c, SRC, PROP_ROCK)
			elif roll < 0.100:
				detail_layer.set_cell(c, SRC, PROP_STUMP)


# Cliffs are solid. Rather than one body per cell (hundreds of nodes), adjacent
# cliff cells are merged into horizontal runs and each run becomes a single
# rectangle, which cuts the shape count by roughly an order of magnitude.
func _build_cliff_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Cliffs"
	body.collision_layer = 4
	body.collision_mask = 7
	body.add_to_group("obstacles")
	$Map.add_child(body)

	var rows: Dictionary = {}
	for c in _terrain:
		if _terrain[c] == Terrain.CLIFF:
			if not rows.has(c.y):
				rows[c.y] = []
			rows[c.y].append(c.x)

	var shapes := 0
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var run_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size() + 1):
			var at_end: bool = i == xs.size()
			if at_end or xs[i] != prev + 1:
				_add_cliff_run(body, run_start, prev, y)
				shapes += 1
				if not at_end:
					run_start = xs[i]
			if not at_end:
				prev = xs[i]

	print("[World] Cliff collision: %d rows -> %d shapes" % [rows.size(), shapes])


func _add_cliff_run(body: StaticBody2D, x0: int, x1: int, y: int) -> void:
	var width := float(x1 - x0 + 1) * TILE_PX
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, TILE_PX)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	# TileMapLayer cells are top-left anchored; collision shapes are centred.
	cs.position = Vector2((x0 * TILE_PX) + width * 0.5, (y * TILE_PX) + TILE_PX * 0.5)
	body.add_child(cs)


# --- public terrain queries -------------------------------------------------

func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE_PX), floori(pos.y / TILE_PX))


func terrain_at_world(pos: Vector2) -> int:
	return _terrain_at(world_to_cell(pos))


func water_depth_at_world(pos: Vector2) -> int:
	return _water_depth.get(world_to_cell(pos), 0)


# Movement multiplier for wading. 1.0 on dry land; deeper water is slower,
# down to WATER_SLOW_FLOOR.
func speed_multiplier_at_world(pos: Vector2) -> float:
	var d := water_depth_at_world(pos)
	if d <= 0:
		return 1.0
	return clampf(1.0 - float(d) * WATER_SLOW_PER_DEPTH, WATER_SLOW_FLOOR, 1.0)


# One pixel per tile, for the minimap. Built once after generation; the minimap
# turns it into an ImageTexture and scales it, so panning and zooming are just
# source-rect maths rather than a redraw of thousands of cells.
const MINIMAP_COLORS := {
	Terrain.GRASS: Color(0.29, 0.55, 0.27),
	Terrain.DIRT: Color(0.53, 0.40, 0.26),
	Terrain.WATER: Color(0.19, 0.42, 0.64),
	Terrain.STONE: Color(0.47, 0.47, 0.50),
	Terrain.CLIFF: Color(0.28, 0.26, 0.24),
}

func build_terrain_image() -> Image:
	var size := MAP_HALF_TILES * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var cell := Vector2i(x - MAP_HALF_TILES, y - MAP_HALF_TILES)
			var kind: int = _terrain_at(cell)
			var col: Color = MINIMAP_COLORS.get(kind, Color(0.29, 0.55, 0.27))
			# Shade deeper water darker so ponds read as having a bottom.
			if kind == Terrain.WATER:
				var d: int = _water_depth.get(cell, 1)
				col = col.darkened(clampf(float(d) * 0.06, 0.0, 0.35))
			img.set_pixel(x, y, col)
	return img


# Tiles from the map centre to either edge -- the minimap needs this to map
# world coordinates onto the image.
func map_half_tiles() -> int:
	return MAP_HALF_TILES


func tile_px() -> int:
	return TILE_PX

func _on_match_started():
	if multiplayer.is_server() and monsters_container.get_child_count() == 0:
		_spawn_initial_monsters()

func _spawn_initial_monsters():
	_next_monster_id = 1
	_monsters_by_id.clear()
	# Regular slimes
	var spawn_points = [
		Vector2(-200, -150),
		Vector2(220, -180),
		Vector2(-250, 180),
		Vector2(200, 220),
		Vector2(0, -280),
		Vector2(0, 300),
		Vector2(-350, 0),
		Vector2(350, 0)
	]
	
	for pos in spawn_points:
		_create_monster(pos, false)
		
	# Boss King Slime in the north clearing
	_create_monster(Vector2(0, -450), true)

func _create_monster(pos: Vector2, is_king: bool) -> Node:
	var m = monster_scene.instantiate()
	m.global_position = pos
	m.is_king_slime = is_king
	m.monster_id = _next_monster_id
	_next_monster_id += 1
	monsters_container.add_child(m)
	_monsters_by_id[m.monster_id] = m
	return m


# Resolve a monster by its stable id. Returns null if the id is unknown, which
# callers must handle: a sync packet can name a monster this client has not
# spawned.
func find_monster(id: int) -> Node:
	var m = _monsters_by_id.get(id)
	if m != null and is_instance_valid(m) and not m.is_queued_for_deletion():
		return m
	if m != null:
		_monsters_by_id.erase(id)
	return null


# Register a monster spawned outside _create_monster (a host-allocated runtime
# spawn). Kept separate so the id can be supplied rather than derived.
func register_monster(m: Node, id: int) -> void:
	m.monster_id = id
	_monsters_by_id[id] = m
