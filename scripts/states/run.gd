extends PlayerStateBase

func start():
	# 🆕 Usar AnimationController si está disponible
	if anim_controller:
		anim_controller.play("run")
	else:
		# Fallback al método antiguo
		var weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
		if weapon_system and weapon_system.get_current_weapon() and weapon_system.get_current_weapon().weapon_id == "scythe":
			if player.sprite.sprite_frames.has_animation("run_scythe"):
				player.sprite.play("run_scythe")
			else:
				player.sprite.play("run")  # Fallback
		else:
			player.sprite.play("run")

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
	
	if input_dir == 0 and abs(player.velocity.x) < 10:
		state_machine.change_to("idle")
		return
	
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		state_machine.change_to("jump")
		return
	
	if not player.is_on_floor():
		state_machine.change_to("fall")
		return
	
	player.move_and_slide()
