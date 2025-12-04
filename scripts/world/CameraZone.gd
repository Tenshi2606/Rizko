extends Area2D
class_name CameraZone

@export_group("Identificación")
@export var zone_name: String = "Zona 1"

@export_group("Límites de Cámara")
@export var limit_left: int = -1000
@export var limit_top: int = -1000
@export var limit_right: int = 1000
@export var limit_bottom: int = 1000

@export_group("Configuración")
@export var follow_vertical: bool = true
@export var vertical_offset: float = 0.0

@export_group("Visual (Solo Editor)")
@export var debug_color: Color = Color(0.3, 0.7, 1.0, 0.2)
@export var show_limits: bool = true

var player_checked: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	add_to_group("camera_zones")
	
	if not has_node("CollisionShape2D"):
		push_warning("⚠️ CameraZone '", zone_name, "' necesita un CollisionShape2D")
	
	print("📷 CameraZone configurada: ", zone_name)

func _physics_process(_delta: float) -> void:
	# 🆕 VERIFICAR PLAYER CADA FRAME HASTA ENCONTRARLO
	if not player_checked:
		_check_for_player_inside()

func _check_for_player_inside() -> void:
	var bodies = get_overlapping_bodies()
	
	for body in bodies:
		if body is Player:
			print("📷 ", zone_name, " - Player encontrado dentro al iniciar")
			player_checked = true
			_activate_zone_for_player(body as Player)
			return

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("📷 Player entró a zona: ", zone_name)
		player_checked = true
		_activate_zone_for_player(body as Player)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		print("📷 Player salió de zona: ", zone_name)
		var camera = body.get_node_or_null("Camera2D") as CameraController
		if camera:
			camera.exit_camera_zone(self)

func _activate_zone_for_player(player: Player) -> void:
	var camera = player.get_node_or_null("Camera2D") as CameraController
	if not camera:
		push_warning("⚠️ Player sin CameraController en zona: ", zone_name)
		return
	
	camera.enter_camera_zone(self)

# ============================================
# VISUALIZACIÓN EN EL EDITOR
# ============================================

func _draw() -> void:
	if not Engine.is_editor_hint() or not show_limits:
		return
	
	var rect_pos = Vector2(limit_left, limit_top) - global_position
	var rect_size = Vector2(limit_right - limit_left, limit_bottom - limit_top)
	
	draw_rect(Rect2(rect_pos, rect_size), debug_color)
	draw_rect(Rect2(rect_pos, rect_size), Color(debug_color.r, debug_color.g, debug_color.b, 1.0), false, 3.0)
	
	# Límite superior
	draw_line(
		Vector2(limit_left - global_position.x, limit_top - global_position.y),
		Vector2(limit_right - global_position.x, limit_top - global_position.y),
		Color.RED, 2.0
	)
	
	# Límite inferior
	draw_line(
		Vector2(limit_left - global_position.x, limit_bottom - global_position.y),
		Vector2(limit_right - global_position.x, limit_bottom - global_position.y),
		Color.GREEN, 2.0
	)
	
	# Límite izquierdo
	draw_line(
		Vector2(limit_left - global_position.x, limit_top - global_position.y),
		Vector2(limit_left - global_position.x, limit_bottom - global_position.y),
		Color.BLUE, 2.0
	)
	
	# Límite derecho
	draw_line(
		Vector2(limit_right - global_position.x, limit_top - global_position.y),
		Vector2(limit_right - global_position.x, limit_bottom - global_position.y),
		Color.YELLOW, 2.0
	)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
