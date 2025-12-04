# res://scripts/player/CameraController.gd
extends Camera2D
class_name CameraController

## ============================================
## CONTROLADOR DE CÁMARA CON LÍMITES DINÁMICOS
## ============================================

## Suavizado de movimiento
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 5.0

## Offset vertical (para ver más arriba/abajo)
@export var vertical_offset: float = 0.0

## Seguir al jugador en Y (desactivar para cámara fija verticalmente)
@export var follow_vertical: bool = true

## Modo de cámara libre (sin límites) cuando no está en zona
@export var free_camera_when_outside_zone: bool = true

var player: Player
var current_zone: CameraZone = null
var is_in_zone: bool = false

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("CameraController debe ser hijo del Player")
		return
	
	# Configurar cámara
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed
	
	# Iniciar con cámara libre (sin límites)
	_set_free_camera()
	
	print("📷 CameraController inicializado (modo libre)")

func _process(_delta: float) -> void:
	# Aplicar offset vertical
	offset.y = vertical_offset
	
	# 🆕 Camera Shake (funciona durante freeze porque usa _process)
	if shake_timer > 0:
		shake_timer -= _delta
		
		# Calcular shake con decay (se reduce con el tiempo)
		var shake_strength = shake_amount * (shake_timer / shake_duration)
		
		# Aplicar shake random
		offset.x = original_offset.x + randf_range(-shake_strength, shake_strength)
		offset.y = vertical_offset + randf_range(-shake_strength, shake_strength)
		
		# Cuando termina el shake, restaurar offset original
		if shake_timer <= 0:
			offset.x = original_offset.x
			offset.y = vertical_offset
			shake_timer = 0.0
			shake_amount = 0.0

# ============================================
# SISTEMA DE ZONAS DE CÁMARA
# ============================================

func enter_camera_zone(zone: CameraZone) -> void:
	if current_zone == zone:
		return
	
	current_zone = zone
	is_in_zone = true
	
	print("📷 Entrando a zona: ", zone.zone_name)
	print("  Límites: L:", zone.limit_left, " T:", zone.limit_top, " R:", zone.limit_right, " B:", zone.limit_bottom)
	
	# Aplicar límites de la zona
	_apply_limits(zone.limit_left, zone.limit_top, zone.limit_right, zone.limit_bottom)
	
	# Aplicar configuraciones específicas de la zona
	follow_vertical = zone.follow_vertical
	vertical_offset = zone.vertical_offset

func exit_camera_zone(zone: CameraZone) -> void:
	if current_zone != zone:
		return
	
	print("📷 Saliendo de zona: ", zone.zone_name)
	current_zone = null
	is_in_zone = false
	
	# Volver a cámara libre (sin límites)
	if free_camera_when_outside_zone:
		_set_free_camera()
		print("  → Cámara en modo libre")

func _apply_limits(left: int, top: int, right: int, bottom: int) -> void:
	limit_left = left
	limit_top = top
	limit_right = right
	limit_bottom = bottom
	
	print("  ✅ Límites aplicados: L:", left, " T:", top, " R:", right, " B:", bottom)

func _set_free_camera() -> void:
	# Establecer límites extremadamente grandes para cámara libre
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
	
	print("  ✅ Cámara libre activada (sin límites)")

# ============================================
# FORZAR APLICACIÓN DE LÍMITES AL CARGAR ESCENA
# ============================================

func force_apply_camera_zones() -> void:
	if not player:
		print("⚠️ No hay player para verificar zonas")
		return
	
	print("\n📷 ═══ FORZANDO APLICACIÓN DE CAMERA ZONES ═══")
	
	var player_pos = player.global_position
	print("  Player Position: (", "%.1f" % player_pos.x, ", ", "%.1f" % player_pos.y, ")")
	
	var camera_zones = get_tree().get_nodes_in_group("camera_zones")
	print("  CameraZones encontradas: ", camera_zones.size())
	
	var zone_found = false
	
	for zone in camera_zones:
		if not zone is CameraZone:
			continue
		
		# USAR get_overlapping_bodies() EN LUGAR DE CALCULAR MANUALMENTE
		var bodies = zone.get_overlapping_bodies()
		var player_inside = false
		
		for body in bodies:
			if body == player:
				player_inside = true
				break
		
		print("  Verificando zona: ", zone.zone_name if zone.has_method("get") else zone.name)
		print("    Player dentro: ", player_inside)
		
		if player_inside:
			print("  ✅ PLAYER DENTRO DE ZONA: ", zone.zone_name if zone.has_method("get") else zone.name)
			
			# Aplicar límites inmediatamente
			current_zone = zone
			_apply_limits(zone.limit_left, zone.limit_top, zone.limit_right, zone.limit_bottom)
			follow_vertical = zone.follow_vertical
			vertical_offset = zone.vertical_offset
			is_in_zone = true
			
			zone_found = true
			break
	
	if not zone_found:
		print("  ⚠️ Player NO está en ninguna CameraZone")
		_set_free_camera()
		is_in_zone = false
	
	print("📷 ═══════════════════════════════════════\n")

# ============================================
# UTILIDADES PÚBLICAS
# ============================================

func force_free_camera() -> void:
	_set_free_camera()
	current_zone = null
	is_in_zone = false

func is_inside_camera_zone() -> bool:
	return is_in_zone

func get_current_zone() -> CameraZone:
	return current_zone

# ============================================
# 🆕 CAMERA SHAKE
# ============================================

var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_offset: Vector2 = Vector2.ZERO

func shake_camera(intensity: float = 10.0, duration: float = 0.3) -> void:
	shake_amount = intensity
	shake_duration = duration
	shake_timer = duration
	original_offset = offset
