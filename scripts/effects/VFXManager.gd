# res://scripts/effects/VFXManager.gd
extends Node2D
class_name VFXManager

## ============================================
## SISTEMA MODULAR DE EFECTOS VISUALES
## ============================================

var player: Player

# Referencias a efectos
var healing_aura: Node2D = null
var landing_dust: CPUParticles2D = null
var dash_trail: CPUParticles2D = null
var attack_impact: CPUParticles2D = null

# Estados activos
var is_healing_active: bool = false
var was_airborne: bool = false

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("VFXManager debe ser hijo del Player")
		return
	
	_setup_effects()
	print("✨ VFXManager inicializado")

# ============================================
# SETUP INICIAL
# ============================================

func _setup_effects() -> void:
	# 🔥 AURA DE FUEGO NEGRA (CURACIÓN)
	healing_aura = _create_dark_fire_aura()
	healing_aura.visible = false
	add_child(healing_aura)
	
	# Polvo al aterrizar
	landing_dust = _create_landing_dust()
	landing_dust.emitting = false
	add_child(landing_dust)
	
	# Estela de dash
	dash_trail = _create_dash_trail()
	dash_trail.emitting = false
	add_child(dash_trail)
	
	# Impacto de ataque
	attack_impact = _create_attack_impact()
	attack_impact.emitting = false
	add_child(attack_impact)
	
	print("  ✅ Efectos creados: aura negra, polvo, estela, impacto")

# ============================================
# 🔥 CREAR AURA DE FUEGO NEGRA
# ============================================

func _create_dark_fire_aura() -> Node2D:
	var aura = Node2D.new()
	aura.name = "DarkFireAura"
	
	# ==================================
	# CAPA 1: ANILLO EXTERIOR (FUEGO)
	# ==================================
	var outer_ring = Sprite2D.new()
	outer_ring.name = "OuterRing"
	outer_ring.modulate = Color(0.8, 0.3, 0.1, 0.6)  # Naranja oscuro
	outer_ring.scale = Vector2(2.0, 2.0)
	outer_ring.z_index = -1
	# TODO: outer_ring.texture = load("res://assets/sprites/effects/fire_ring.png")
	aura.add_child(outer_ring)
	
	# ==================================
	# CAPA 2: ANILLO INTERIOR (NEGRO)
	# ==================================
	var inner_ring = Sprite2D.new()
	inner_ring.name = "InnerRing"
	inner_ring.modulate = Color(0.1, 0.0, 0.1, 0.8)  # Negro-púrpura
	inner_ring.scale = Vector2(1.5, 1.5)
	inner_ring.z_index = 0
	# TODO: inner_ring.texture = load("res://assets/sprites/effects/dark_ring.png")
	aura.add_child(inner_ring)
	
	# ==================================
	# PARTÍCULAS 1: LLAMAS NEGRAS
	# ==================================
	var dark_flames = CPUParticles2D.new()
	dark_flames.name = "DarkFlames"
	dark_flames.amount = 20
	dark_flames.lifetime = 1.0
	dark_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dark_flames.emission_sphere_radius = 25.0
	dark_flames.direction = Vector2(0, -1)
	dark_flames.spread = 30.0
	dark_flames.gravity = Vector2(0, -80)
	dark_flames.initial_velocity_min = 30.0
	dark_flames.initial_velocity_max = 60.0
	dark_flames.scale_amount_min = 0.8
	dark_flames.scale_amount_max = 1.5
	
	# 🔥 GRADIENTE DE COLOR (NEGRO → NARANJA → TRANSPARENTE)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.1, 0.0, 0.1, 1.0))    # Negro al inicio
	gradient.add_point(0.5, Color(0.8, 0.3, 0.1, 0.8))    # Naranja en el medio
	gradient.add_point(1.0, Color(0.2, 0.1, 0.0, 0.0))    # Transparente al final
	dark_flames.color_ramp = gradient
	
	dark_flames.emitting = false
	aura.add_child(dark_flames)
	
	# ==================================
	# PARTÍCULAS 2: CHISPAS NARANJAS
	# ==================================
	var sparks = CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.amount = 10
	sparks.lifetime = 0.8
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 30.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 60.0
	sparks.gravity = Vector2(0, 50)
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 100.0
	sparks.scale_amount_min = 0.3
	sparks.scale_amount_max = 0.8
	sparks.color = Color(1.0, 0.6, 0.2, 1.0)  # Naranja brillante
	sparks.emitting = false
	aura.add_child(sparks)
	
	# ==================================
	# PARTÍCULAS 3: HUMO NEGRO
	# ==================================
	var smoke = CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.amount = 15
	smoke.lifetime = 2.0
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 20.0
	smoke.direction = Vector2(0, -1)
	smoke.spread = 20.0
	smoke.gravity = Vector2(0, -40)
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 40.0
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.0
	
	# Humo negro que se desvanece
	var smoke_gradient = Gradient.new()
	smoke_gradient.add_point(0.0, Color(0.1, 0.0, 0.1, 0.6))
	smoke_gradient.add_point(1.0, Color(0.05, 0.0, 0.05, 0.0))
	smoke.color_ramp = smoke_gradient
	
	smoke.emitting = false
	aura.add_child(smoke)
	
	return aura

# ============================================
# OTROS EFECTOS (POLVO, DASH, IMPACTO)
# ============================================

func _create_landing_dust() -> CPUParticles2D:
	var dust = CPUParticles2D.new()
	dust.name = "LandingDust"
	dust.amount = 20  # Más partículas
	dust.lifetime = 1.5  # Duran mucho más (antes 0.8)
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 20.0  # Radio más grande
	dust.direction = Vector2(0, -1)
	dust.spread = 90.0  # Más dispersión
	dust.gravity = Vector2(0, 100)  # Menos gravedad para que floten más
	dust.initial_velocity_min = 60.0  # Velocidad inicial moderada
	dust.initial_velocity_max = 120.0
	dust.scale_amount_min = 2.0  # Partículas más grandes
	dust.scale_amount_max = 4.0
	
	# 🆕 DAMPING (fricción) para que se frenen gradualmente
	dust.damping_min = 1.0
	dust.damping_max = 2.0
	
	# 🆕 GRADIENTE DE COLOR SUAVE (desvanecimiento gradual)
	var dust_gradient = Gradient.new()
	dust_gradient.add_point(0.0, Color(0.95, 0.95, 0.85, 1.0))   # Blanco-amarillento brillante
	dust_gradient.add_point(0.3, Color(0.8, 0.8, 0.7, 0.8))      # Gris claro
	dust_gradient.add_point(0.6, Color(0.6, 0.6, 0.5, 0.5))      # Gris medio
	dust_gradient.add_point(1.0, Color(0.4, 0.4, 0.3, 0.0))      # Transparente suave
	dust.color_ramp = dust_gradient
	
	# 🆕 GRADIENTE DE ESCALA (se hacen más pequeñas al desvanecerse)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))   # Tamaño normal al inicio
	scale_curve.add_point(Vector2(0.5, 0.8))   # Se reducen un poco
	scale_curve.add_point(Vector2(1.0, 0.3))   # Muy pequeñas al final
	dust.scale_amount_curve = scale_curve
	
	dust.position = Vector2(0, 12)
	return dust

func _create_dash_trail() -> CPUParticles2D:
	var trail = CPUParticles2D.new()
	trail.name = "DashTrail"
	trail.amount = 20
	trail.lifetime = 0.3
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	trail.direction = Vector2(-1, 0)
	trail.spread = 15.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 50.0
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.5
	trail.color = Color(0.7, 0.7, 1.0, 0.7)
	return trail

func _create_attack_impact() -> CPUParticles2D:
	var impact = CPUParticles2D.new()
	impact.name = "AttackImpact"
	impact.amount = 6
	impact.lifetime = 0.3
	impact.one_shot = true
	impact.explosiveness = 1.0
	impact.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	impact.emission_sphere_radius = 5.0
	impact.direction = Vector2(1, 0)
	impact.spread = 45.0
	impact.gravity = Vector2.ZERO
	impact.initial_velocity_min = 100.0
	impact.initial_velocity_max = 200.0
	impact.scale_amount_min = 1.0
	impact.scale_amount_max = 2.0
	impact.color = Color(1.0, 0.9, 0.5, 0.9)
	return impact

# ============================================
# ACTUALIZACIÓN CONTINUA
# ============================================

func _process(delta: float) -> void:
	if not player:
		return
	
	# Detectar aterrizaje
	_check_landing()
	
	# 🔥 ANIMAR AURA DE FUEGO NEGRA
	if is_healing_active and healing_aura:
		_animate_dark_fire_aura(delta)

func _check_landing() -> void:
	# Detectar aterrizaje
	if was_airborne and player.is_on_floor():
		if abs(player.velocity.y) > 50:  # Umbral más bajo
			play_landing_dust()
	
	# 🆕 DETECTAR SALTO (cuando deja el suelo)
	if not was_airborne and not player.is_on_floor():
		if player.velocity.y < -100:  # Solo si está saltando (no cayendo)
			play_jump_dust()
	
	was_airborne = not player.is_on_floor()

# ============================================
# 🔥 ACTIVAR/DESACTIVAR AURA DE FUEGO NEGRA
# ============================================

func activate_healing_aura() -> void:
	if is_healing_active:
		return
	
	is_healing_active = true
	
	if healing_aura:
		healing_aura.visible = true
		
		# Activar todas las partículas
		var dark_flames = healing_aura.get_node_or_null("DarkFlames") as CPUParticles2D
		var sparks = healing_aura.get_node_or_null("Sparks") as CPUParticles2D
		var smoke = healing_aura.get_node_or_null("Smoke") as CPUParticles2D
		
		if dark_flames:
			dark_flames.emitting = true
		if sparks:
			sparks.emitting = true
		if smoke:
			smoke.emitting = true
		
		# Animar los anillos
		var outer_ring = healing_aura.get_node_or_null("OuterRing") as Sprite2D
		var inner_ring = healing_aura.get_node_or_null("InnerRing") as Sprite2D
		
		if outer_ring:
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(outer_ring, "scale", Vector2(2.2, 2.2), 0.5)
			tween.tween_property(outer_ring, "scale", Vector2(2.0, 2.0), 0.5)
		
		if inner_ring:
			var tween2 = create_tween()
			tween2.set_loops()
			tween2.tween_property(inner_ring, "scale", Vector2(1.4, 1.4), 0.4)
			tween2.tween_property(inner_ring, "scale", Vector2(1.6, 1.6), 0.4)
	
	# 🔥 MODULAR PLAYER CON TONO OSCURO-NARANJA
	if player.sprite:
		# Guardar referencia al tween para poder matarlo después
		var color_tween = create_tween()
		color_tween.set_loops()
		color_tween.tween_property(player.sprite, "modulate", Color(1.0, 0.7, 0.5), 0.3)
		color_tween.tween_property(player.sprite, "modulate", Color(0.9, 0.6, 0.4), 0.3)
		# Guardar referencia para poder matarlo
		healing_aura.set_meta("color_tween", color_tween)
	
	print("🔥 Aura de fuego negra activada")

func deactivate_healing_aura() -> void:
	if not is_healing_active:
		return
	
	is_healing_active = false
	
	if healing_aura:
		healing_aura.visible = false
		
		# Desactivar partículas
		var dark_flames = healing_aura.get_node_or_null("DarkFlames") as CPUParticles2D
		var sparks = healing_aura.get_node_or_null("Sparks") as CPUParticles2D
		var smoke = healing_aura.get_node_or_null("Smoke") as CPUParticles2D
		
		if dark_flames:
			dark_flames.emitting = false
		if sparks:
			sparks.emitting = false
		if smoke:
			smoke.emitting = false
		
		# 🆕 MATAR EL TWEEN DE COLOR
		if healing_aura.has_meta("color_tween"):
			var color_tween = healing_aura.get_meta("color_tween")
			if color_tween:
				color_tween.kill()
			healing_aura.remove_meta("color_tween")
	
	# Restaurar color del player con tween suave
	if player.sprite:
		var restore_tween = create_tween()
		restore_tween.tween_property(player.sprite, "modulate", Color(1, 1, 1), 0.3)
	
	print("❌ Aura de fuego negra desactivada")

# 🔥 ANIMAR AURA (ROTACIÓN + ONDULACIÓN)
func _animate_dark_fire_aura(delta: float) -> void:
	if not healing_aura:
		return
	
	# Rotar anillo exterior (sentido horario)
	var outer_ring = healing_aura.get_node_or_null("OuterRing") as Sprite2D
	if outer_ring:
		outer_ring.rotation += delta * 1.0
	
	# Rotar anillo interior (sentido antihorario)
	var inner_ring = healing_aura.get_node_or_null("InnerRing") as Sprite2D
	if inner_ring:
		inner_ring.rotation -= delta * 1.5

# ============================================
# OTROS EFECTOS
# ============================================

func play_landing_dust() -> void:
	if landing_dust:
		landing_dust.restart()
		print("💨 Polvo de aterrizaje")

# 🆕 POLVO AL SALTAR
func play_jump_dust() -> void:
	if landing_dust:
		# Reutilizar el mismo sistema de partículas
		landing_dust.amount = 8  # Menos partículas al saltar
		landing_dust.initial_velocity_min = 40.0
		landing_dust.initial_velocity_max = 80.0
		landing_dust.restart()
		
		# Restaurar valores para aterrizaje
		await get_tree().create_timer(0.1).timeout
		if landing_dust:
			landing_dust.amount = 15
			landing_dust.initial_velocity_min = 80.0
			landing_dust.initial_velocity_max = 150.0
		
		print("💨 Polvo de salto")

func activate_dash_trail() -> void:
	if dash_trail:
		var direction = Vector2(-1, 0) if not player.sprite.flip_h else Vector2(1, 0)
		dash_trail.direction = direction
		dash_trail.emitting = true
		print("💨 Estela de dash activada")

func deactivate_dash_trail() -> void:
	if dash_trail:
		dash_trail.emitting = false

func play_attack_impact(position_offset: Vector2, direction: Vector2) -> void:
	if attack_impact:
		attack_impact.position = position_offset
		attack_impact.direction = direction
		attack_impact.restart()
		print("💥 Impacto de ataque")

func stop_all_effects() -> void:
	deactivate_healing_aura()
	deactivate_dash_trail()
	
	if landing_dust:
		landing_dust.emitting = false
	if attack_impact:
		attack_impact.emitting = false
