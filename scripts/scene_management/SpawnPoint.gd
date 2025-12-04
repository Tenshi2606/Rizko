extends Marker2D
class_name SpawnPoint

@export var spawn_id: String = "default"
@export var spawn_direction: Vector2 = Vector2.RIGHT  # Dirección en la que mira el jugador

func _ready() -> void:
	add_to_group("spawn_points")
	
	# Visual en el editor (no se ve en el juego)
	if Engine.is_editor_hint():
		return
	
	print("📍 Spawn point registrado: ", spawn_id)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Dibujar indicador en el editor
	draw_circle(Vector2.ZERO, 16, Color(0, 1, 0, 0.3))
	draw_circle(Vector2.ZERO, 16, Color(0, 1, 0), false, 2.0)
	
	# Flecha de dirección
	var arrow_end = spawn_direction.normalized() * 32
	draw_line(Vector2.ZERO, arrow_end, Color(1, 0, 0), 3.0)
	draw_circle(arrow_end, 4, Color(1, 0, 0))
