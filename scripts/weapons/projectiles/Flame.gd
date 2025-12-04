extends Projectile
class_name Flame

# ============================================
# PROYECTIL DE LLAMA (LANZALLAMAS)
# ============================================

# Las llamas son lentas, grandes y queman con el tiempo (DOT)

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	super._ready()
	
	# Configuración específica de llamas
	lifetime = 1.5  # Las llamas desaparecen rápido (1.5s)
	
	# Efectos visuales
	_flame_effects()

func _flame_effects() -> void:
	if not sprite:
		return
	
	# Color naranja/rojo pulsante
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0), 0.2)
	tween.tween_property(sprite, "modulate", Color(1, 0.8, 0), 0.2)
	
	# Escala pulsante (simula fuego vivo)
	var tween2 = create_tween()
	tween2.set_loops()
	tween2.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.15)
	tween2.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Fade out gradual
	await get_tree().create_timer(lifetime - 0.5).timeout
	if is_instance_valid(self) and sprite:
		var fade = create_tween()
		fade.tween_property(sprite, "modulate:a", 0.0, 0.5)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Las llamas se ralentizan con el tiempo (simula dispersión)
	speed = max(speed - (200 * delta), 50)

func _on_body_entered(body: Node2D) -> void:
	# Ignorar player
	if body is Player:
		return
	
	# Golpear enemigos
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		# Las llamas NO evitan golpear múltiples veces (pueden golpear varias veces)
		# Esto permite que un stream de fuego haga daño continuo
		
		# Aplicar daño directo
		body.take_damage(damage, direction * 50)  # Knockback débil
		
		# 🔥 APLICAR DOT (QUEMADURA) - USANDO DOTComponent
		if has_dot:
			var dot_component = body.get_node_or_null("DOTComponent") as DOTComponent
			
			if dot_component:
				# Aplicar quemadura usando el componente
				dot_component.apply_dot(DOTComponent.DOTType.BURN, dot_damage, dot_duration)
				print("🔥 DOTComponent detectado - Quemadura aplicada")
			else:
				# Fallback: método antiguo (por compatibilidad)
				if body.has_method("apply_dot"):
					body.apply_dot(dot_damage, dot_duration)
					print("🔥 Método apply_dot() usado (fallback)")
		
		# 🔥 EFECTO VISUAL EN ENEMIGO
		_ignite_enemy(body)
		
		# Las llamas NO se destruyen al impactar (pueden atravesar)
		# Pero se destruyen al tocar paredes
	
	# Colisión con paredes/obstáculos
	if body is TileMap or body is StaticBody2D:
		_wall_impact_effect()
		queue_free()

func _ignite_enemy(enemy: Node2D) -> void:
	# Efecto visual de enemigo en llamas
	var enemy_sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if not enemy_sprite:
		return
	
	# Flash naranja
	enemy_sprite.modulate = Color(1, 0.5, 0)
	
	# Restaurar color después de un momento
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(enemy) and enemy_sprite:
		enemy_sprite.modulate = Color(1, 1, 1)

func _wall_impact_effect() -> void:
	# Efecto de llama impactando pared
	print("🔥 Llama impactó pared")
	
	# TODO: Instanciar partículas de fuego dispersándose
	# var fire_splash = preload("res://effects/fire_splash.tscn").instantiate()
	# fire_splash.global_position = global_position
	# get_tree().current_scene.add_child(fire_splash)
