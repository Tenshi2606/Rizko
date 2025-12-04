extends Node
class_name DOTComponent

# ============================================
# DAMAGE OVER TIME COMPONENT
# ============================================
# Añade esto como componente a los enemigos para soportar quemadura/veneno

signal dot_applied(dot_type: String, damage: float, duration: float)
signal dot_tick(dot_type: String, damage: float)
signal dot_ended(dot_type: String)

enum DOTType { BURN, POISON, BLEED, FROST }

var enemy: Node2D

# Estados de DOT activos
var active_dots: Dictionary = {}  # {dot_type: {damage, duration, tick_rate, timer}}

func _ready() -> void:
	await get_tree().process_frame
	enemy = get_parent()
	
	if not enemy:
		push_error("DOTComponent debe ser hijo de un enemigo")
		return
	
	print("🔥 DOTComponent inicializado para: ", enemy.name)

func _process(delta: float) -> void:
	# Procesar todos los DOTs activos
	for dot_type in active_dots.keys():
		var dot_data = active_dots[dot_type]
		
		dot_data["timer"] -= delta
		dot_data["tick_timer"] -= delta
		
		# Aplicar daño por tick
		if dot_data["tick_timer"] <= 0:
			_apply_dot_tick(dot_type, dot_data)
		
		# Terminar DOT si el tiempo se acabó
		if dot_data["timer"] <= 0:
			_end_dot(dot_type)

# ============================================
# APLICAR DOT
# ============================================

func apply_dot(dot_type: DOTType, damage_per_second: float, duration: float) -> void:
	"""
	Aplica daño continuo al enemigo
	dot_type: Tipo de DOT (BURN, POISON, etc.)
	damage_per_second: Daño por segundo
	duration: Duración total en segundos
	"""
	var dot_name = DOTType.keys()[dot_type]
	
	# Si ya tiene este DOT, renovar duración
	if active_dots.has(dot_name):
		active_dots[dot_name]["timer"] = duration
		active_dots[dot_name]["damage"] = damage_per_second
		print("🔄 ", enemy.name, " - ", dot_name, " renovado")
		return
	
	# Crear nuevo DOT
	active_dots[dot_name] = {
		"damage": damage_per_second,
		"duration": duration,
		"timer": duration,
		"tick_rate": 1.0,  # Aplicar cada 1 segundo
		"tick_timer": 0.0  # Primera aplicación inmediata
	}
	
	print("🔥 ", enemy.name, " - ", dot_name, " aplicado (", damage_per_second, " daño/s por ", duration, "s)")
	dot_applied.emit(dot_name, damage_per_second, duration)
	
	# Efecto visual
	_show_dot_effect(dot_name)

# ============================================
# PROCESAMIENTO INTERNO
# ============================================

func _apply_dot_tick(dot_type: String, dot_data: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	
	if not enemy.has_method("take_damage"):
		return
	
	# Calcular daño del tick
	var tick_damage = int(dot_data["damage"] * dot_data["tick_rate"])
	
	# Aplicar daño
	enemy.take_damage(tick_damage, Vector2.ZERO)
	
	print("🔥 ", enemy.name, " recibe ", tick_damage, " de ", dot_type)
	dot_tick.emit(dot_type, tick_damage)
	
	# Resetear timer del siguiente tick
	dot_data["tick_timer"] = dot_data["tick_rate"]
	
	# Feedback visual
	_show_dot_tick_effect(dot_type)

func _end_dot(dot_type: String) -> void:
	if not active_dots.has(dot_type):
		return
	
	active_dots.erase(dot_type)
	print("✅ ", enemy.name, " - ", dot_type, " terminado")
	dot_ended.emit(dot_type)

# ============================================
# EFECTOS VISUALES
# ============================================

func _show_dot_effect(dot_type: String) -> void:
	if not is_instance_valid(enemy):
		return
	
	var sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
	
	# Color según tipo de DOT
	var color = _get_dot_color(dot_type)
	
	# Flash de color
	sprite.modulate = color
	await get_tree().create_timer(0.2).timeout
	
	if is_instance_valid(enemy) and sprite:
		sprite.modulate = Color(1, 1, 1)

func _show_dot_tick_effect(dot_type: String) -> void:
	if not is_instance_valid(enemy):
		return
	
	var sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
	
	var color = _get_dot_color(dot_type)
	
	# Pulso de color
	sprite.modulate = color
	await get_tree().create_timer(0.1).timeout
	
	if is_instance_valid(enemy) and sprite:
		sprite.modulate = Color(1, 1, 1)

func _get_dot_color(dot_type: String) -> Color:
	match dot_type:
		"BURN":
			return Color(1, 0.5, 0)  # Naranja
		"POISON":
			return Color(0.5, 1, 0)  # Verde
		"BLEED":
			return Color(1, 0, 0)    # Rojo
		"FROST":
			return Color(0.5, 0.7, 1)  # Azul claro
		_:
			return Color(1, 1, 1)

# ============================================
# UTILIDADES
# ============================================

func has_dot(dot_type: DOTType) -> bool:
	var dot_name = DOTType.keys()[dot_type]
	return active_dots.has(dot_name)

func clear_all_dots() -> void:
	active_dots.clear()

func get_active_dots() -> Array:
	return active_dots.keys()
