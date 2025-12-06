extends PlayerStateBase

func start():
	# AnimationController maneja automáticamente las animaciones con arma
	if anim_controller:
		anim_controller.play("idle")

func on_physics_process(delta: float) -> void:
	# Si presiona ataque, verificar si ya está atacando
	if not player.is_in_healing_mode and Input.is_action_just_pressed("attack"):
		# Si ya está en estado de ataque, NO cambiar de estado
		if state_machine.current_state.name == "Attack":
			return
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
