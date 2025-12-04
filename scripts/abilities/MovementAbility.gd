extends Ability
class_name MovementAbility

func activate(player: Player) -> void:
	match id:
		"double_jump":
			player.max_jumps = int(value)
			player.jumps_remaining = int(value)
			print("  🦘 Doble salto activado")
		"wall_jump":
			player.can_wall_jump = true
			print("  🧗 Wall jump activado")
