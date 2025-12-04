extends PlayerStateBase

func start():
	
	# 🆕 Cambiar animación según arma equipada
	var weapon = player.get_current_weapon()
	
	if weapon and weapon.weapon_id == "scythe":
		if player.sprite.sprite_frames.has_animation("fall_scythe"):
			player.sprite.play("fall_scythe")
			print("🍂 Animación 'fall_scythe' activada")
		else:
			player.sprite.play("fall")  # Fallback
	else:
		if player.sprite.sprite_frames.has_animation("fall"):
			player.sprite.play("fall")
			print("🍂 Animación 'fall' activada")
		else:
			player.sprite.play("jump")  # Fallback
			print("⚠️ Animación 'fall' no existe, usando 'jump'")

func on_physics_process(delta: float) -> void:
	
	if not player.is_in_healing_mode and Input.is_action_just_pressed("attack"):
		state_machine.change_to("Attack")
		return
	
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	# ✅ Usar método de la clase base para sprite flip
	update_sprite_flip(input_dir)
	
	# Aplicar movimiento horizontal
	var target_speed = input_dir * player.speed
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# 🔥 ASEGURAR QUE LA ANIMACIÓN SE MANTIENE
	var weapon = player.get_current_weapon()
	if player.sprite:
		if weapon and weapon.weapon_id == "scythe":
			if player.sprite.animation != "fall_scythe":
				if player.sprite.sprite_frames.has_animation("fall_scythe"):
					player.sprite.play("fall_scythe")
		else:
			if player.sprite.animation != "fall":
				if player.sprite.sprite_frames.has_animation("fall"):
					player.sprite.play("fall")
	
	if player.is_on_floor():
		if abs(player.velocity.x) > 10:
			state_machine.change_to("run")
		else:
			state_machine.change_to("idle")
		return
	
	player.move_and_slide()

func end():
	pass
