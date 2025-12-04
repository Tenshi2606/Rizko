extends Area2D
class_name Projectile

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 10.0
var piercing: bool = false

var has_dot: bool = false
var dot_damage: float = 0.0
var dot_duration: float = 0.0

var lifetime: float = 5.0  # Destruir después de 5s
var enemies_hit: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Timer para destruir
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	
	# Rotar sprite según dirección
	if has_node("Sprite2D"):
		$Sprite2D.rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# Ignorar player
	if body is Player:
		return
	
	# 🔥 PRIORIDAD 1: VERIFICAR SI ES PARED/OBSTÁCULO
	if _is_wall(body):
		print("💥 Proyectil impactó pared: ", body.name)
		_wall_impact_effect()
		queue_free()
		return
	
	# 🎯 PRIORIDAD 2: GOLPEAR ENEMIGOS
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		# Evitar golpear mismo enemigo múltiples veces
		if body in enemies_hit:
			return
		
		enemies_hit.append(body)
		
		# Aplicar daño
		body.take_damage(damage, direction * 100)
		
		# DOT (quemadura)
		if has_dot:
			var dot_component = body.get_node_or_null("DOTComponent") as DOTComponent
			
			if dot_component:
				# Usar DOTComponent si existe
				dot_component.apply_dot(DOTComponent.DOTType.BURN, dot_damage, dot_duration)
			elif body.has_method("apply_dot"):
				# Fallback
				body.apply_dot(dot_damage, dot_duration)
		
		# Destruir si no es piercing
		if not piercing:
			queue_free()
			return

# ============================================
# 🆕 VERIFICAR SI ES PARED U OBSTÁCULO
# ============================================

func _is_wall(body: Node2D) -> bool:
	# 1. TileMap (paredes del nivel)
	if body is TileMap:
		return true
	
	# 2. StaticBody2D (plataformas, obstáculos estáticos)
	if body is StaticBody2D:
		return true
	
	# 3. CharacterBody2D que NO sea enemigo ni player
	if body is CharacterBody2D:
		if not body.is_in_group("enemies") and not body is Player:
			return true
	
	# 4. Grupos específicos
	if body.is_in_group("walls"):
		return true
	
	if body.is_in_group("obstacles"):
		return true
	
	if body.is_in_group("terrain"):
		return true
	
	return false

# ============================================
# 🆕 EFECTO VISUAL AL IMPACTAR PARED
# ============================================

func _wall_impact_effect() -> void:
	# TODO: Instanciar partículas de impacto
	# var impact_particles = preload("res://effects/bullet_impact.tscn").instantiate()
	# impact_particles.global_position = global_position
	# get_tree().current_scene.add_child(impact_particles)
	
	# TODO: Reproducir sonido de impacto
	# AudioManager.play_sound("bullet_impact")
	
	pass  # Por ahora solo se destruye
