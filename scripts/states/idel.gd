extends PlayerStateBase

func start():
	# 🆕 Cambiar animación según arma equipada
	var weapon = player.get_current_weapon()
	
	if weapon and weapon.weapon_id == "scythe":
		if player.sprite.sprite_frames.has_animation("idle_scythe"):
			player.sprite.play("idle_scythe")
		else:
			player.sprite.play("idle")  # Fallback
	else:
		player.sprite.play("idle")

func on_physics_process(delta: float) -> void:
	if not player.is_in_healing_mode and Input.is_action_just_pressed("attack"):
		state_machine.change_to("Attack")
		return
	
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if input_dir != 0:
		state_machine.change_to("run")
		return
	
	if abs(player.velocity.x) > 0:
		var dec = player.friction * delta
		if abs(player.velocity.x) <= dec:
			player.velocity.x = 0
		else:
			player.velocity.x -= sign(player.velocity.x) * dec
	
	if player.jump_buffer_timer > 0 and player.can_jump():
		player.jump_buffer_timer = 0
		state_machine.change_to("jump")
		return
	
	if not player.is_on_floor():
		state_machine.change_to("fall")
		return
	
	player.move_and_slide()
