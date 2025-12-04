extends Node
class_name HealthComponent

var player: Player
var health_bar: ProgressBar  # 🆕 Crear HealthBar programáticamente
var invul_timer: Timer
var movement_component: MovementComponent  # 🆕 Referencia al MovementComponent

func _ready() -> void:
	await get_tree().process_frame
	
	player = get_parent() as Player
	
	if not player:
		push_error("HealthComponent debe ser hijo de un Player")
		return
	
	player.health = player.max_health
	
	# 🆕 CREAR HEALTHBAR PROGRAMÁTICAMENTE
	_create_health_bar()
	
	# Timer de invulnerabilidad
	invul_timer = Timer.new()
	invul_timer.name = "InvulTimer"
	invul_timer.one_shot = true
	invul_timer.wait_time = player.invul_time
	add_child(invul_timer)
	invul_timer.connect("timeout", _on_invul_timeout)
	
	# 🆕 Obtener referencia al MovementComponent
	movement_component = player.get_node_or_null("MovementComponent") as MovementComponent
	if not movement_component:
		push_warning("⚠️ MovementComponent no encontrado en Player")
	
	print("✅ HealthComponent inicializado con HealthBar")

# ============================================
# 🆕 CREAR HEALTHBAR (YA NO DEPENDE DE ESCENA)
# ============================================

func _create_health_bar() -> void:
	# Crear CanvasLayer para que esté siempre visible
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "HealthBarLayer"
	canvas_layer.layer = 10
	player.add_child(canvas_layer)
	
	# Crear MarginContainer
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = Vector2(20, 20)
	canvas_layer.add_child(margin)
	
	# Crear ProgressBar
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(200, 30)
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	health_bar.show_percentage = false
	margin.add_child(health_bar)
	
	# Estilo visual
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0.5, 0.5, 0.5)
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.2, 0.2)  # Rojo
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	print("  ❤️ HealthBar creado programáticamente")

# ============================================
# TOMAR DAÑO
# ============================================

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, source_pos: Vector2 = Vector2.ZERO) -> void:
	if not player or player.invulnerable:
		return
	
	print("💥 HealthComponent.take_damage() - Daño: ", amount)
	
	var state_machine = player.get_node_or_null("StateMachine")
	
	# Cancelar curación
	if player.active_healing_fragment:
		print("💔 Curación cancelada por daño!")
		player.active_healing_fragment = null
		if state_machine and state_machine.current_state is HealState:
			player.previous_state_name = "idle"
	
	player.health = max(0, player.health - amount)
	_update_health_bar()
	
	player.invulnerable = true
	invul_timer.start(player.invul_time)
	
	if player.sprite:
		player.sprite.modulate = Color(1, 0.6, 0.6)
	
	# 🆕 Aplicar knockback	
	# 🆕 APLICAR KNOCKBACK VÍA MOVEMENTCOMPONENT
	if knockback != Vector2.ZERO and movement_component:
		movement_component.apply_knockback(knockback, source_pos)
	
	# Aplicar freeze y shake DESPUÉS del knockback
	_apply_damage_freeze()
	_apply_camera_shake()
	
	if player.health == 0:
		die()





# ============================================
# CURAR
# ============================================

func heal(amount: int) -> void:
	if not player:
		return
	
	var old_health = player.health
	player.health = min(player.max_health, player.health + amount)
	_update_health_bar()
	
	var healed = player.health - old_health
	if healed > 0:
		print("💚 Curado: +", healed, " HP (", player.health, "/", player.max_health, ")")
		
		# Feedback visual
		if player.sprite:
			player.sprite.modulate = Color(0.3, 1, 0.3)
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(player) and player.sprite:
				player.sprite.modulate = Color(1, 1, 1)

# ============================================
# 🆕 RESTAURAR VIDA COMPLETA (CHECKPOINT)
# ============================================

func restore_full_health() -> void:
	if not player:
		return
	
	var old_health = player.health
	player.health = player.max_health
	_update_health_bar()
	
	var healed = player.health - old_health
	if healed > 0:
		print("✨ Vida restaurada completamente: +", healed, " HP (", player.health, "/", player.max_health, ")")
		
		# Feedback visual más intenso
		if player.sprite:
			# Destello verde brillante
			player.sprite.modulate = Color(0.5, 1.5, 0.5)
			
			# Crear tween para animación suave
			var tween = create_tween()
			tween.tween_property(player.sprite, "modulate", Color(1, 1, 1), 0.5)

# ============================================
# ACTUALIZAR BARRA
# ============================================

func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = player.health
		print("❤️ Vida actualizada: ", player.health, "/", player.max_health)
		
		# Cambiar color según vida
		var style_fill = StyleBoxFlat.new()
		
		var health_percent = float(player.health) / float(player.max_health)
		
		if health_percent > 0.6:
			style_fill.bg_color = Color(0.3, 0.8, 0.3)  # Verde
		elif health_percent > 0.3:
			style_fill.bg_color = Color(0.9, 0.7, 0.2)  # Amarillo
		else:
			style_fill.bg_color = Color(0.9, 0.2, 0.2)  # Rojo
		
		health_bar.add_theme_stylebox_override("fill", style_fill)

# ============================================
# CALLBACKS
# ============================================

func _on_invul_timeout() -> void:
	if not player:
		return
	
	player.invulnerable = false
	if player.sprite:
		player.sprite.modulate = Color(1, 1, 1)
	
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine:
		state_machine.change_to(player.previous_state_name)

func die() -> void:
	print("💀 Player murió")
	
	# 🆕 Mostrar pantalla de muerte vía GameManager
	if GameManager:
		GameManager.show_death_screen("default")
	
	# TODO: Animación de muerte antes de destruir
	# await get_tree().create_timer(1.0).timeout
	# player.queue_free()

# ============================================
# 🆕 HIT FREEZE AL RECIBIR DAÑO
# ============================================

func _apply_damage_freeze() -> void:
	# 🆕 Usar FreezeManager centralizado
	FreezeManager.apply_damage_freeze()



# ============================================
# 🆕 CAMERA SHAKE AL RECIBIR DAÑO
# ============================================

func _apply_camera_shake() -> void:
	# Buscar la cámara del player (por tipo, no por nombre)
	var camera: CameraController = null
	
	# Buscar en los hijos del player
	for child in player.get_children():
		if child is CameraController:
			camera = child as CameraController
			break
	
	if camera and camera.has_method("shake_camera"):
		# Shake muy sutil al recibir daño
		camera.shake_camera(3.0, 0.15)
		print("📷 Camera shake activado: intensidad=5, duración=0.15s")
	else:
		print("⚠️ No se pudo activar camera shake - cámara no encontrada")
		print("  Hijos del player: ", player.get_children())
