extends Node2D

## Lightweight, deterministic combat VFX. Drawn in canvas space so it stays
## crisp with the pixel-art characters and costs no texture allocations.
var bursts: Array[Dictionary] = []

func burst(at: Vector2 = Vector2.ZERO, color: Color = Color.WHITE, radius: float = 18.0, critical: bool = false) -> void:
	bursts.append({"at": at, "color": color, "radius": radius, "life": 0.22 if not critical else 0.34, "max": 0.22 if not critical else 0.34, "critical": critical})
	queue_redraw()

func _process(delta: float) -> void:
	for fx in bursts:
		fx.life -= delta
	for i in range(bursts.size() - 1, -1, -1):
		if bursts[i].life <= 0.0:
			bursts.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for fx in bursts:
		var progress: float = 1.0 - fx.life / fx.max
		var fade: float = clampf(fx.life / fx.max, 0.0, 1.0)
		var col: Color = fx.color
		col.a = fade
		var center: Vector2 = fx.at
		var radius: float = lerpf(3.0, fx.radius, progress)
		draw_circle(center, radius * 0.22, Color(col, fade * 0.55))
		draw_arc(center, radius, 0.0, TAU, 20, col, 2.0)
		for ray in range(8 if not fx.critical else 12):
			var angle := TAU * float(ray) / float(8 if not fx.critical else 12)
			var inner := center + Vector2.from_angle(angle) * radius * 0.45
			var outer := center + Vector2.from_angle(angle) * radius * 1.35
			draw_line(inner, outer, col, 2.0 if not fx.critical else 3.0)
